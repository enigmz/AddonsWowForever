local _, SF = ...

local PRICE_SORTS = {}
if Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price then
    PRICE_SORTS = {
        { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false },
    }
end

local function ThrottleReady()
    if not C_AuctionHouse or not C_AuctionHouse.IsThrottledMessageSystemReady then
        return true
    end
    return C_AuctionHouse.IsThrottledMessageSystemReady()
end

local function ReadCommodity(itemID, maxBuy)
    local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    local cheapest, available = nil, 0
    for index = 1, count do
        local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
        if result and result.unitPrice and result.unitPrice > 0 then
            local quantity = result.quantity or 0
            if result.containsOwnerItem and result.numOwnerItems then
                quantity = math.max(0, quantity - result.numOwnerItems)
            end
            if not cheapest then
                cheapest = result.unitPrice
            end
            if maxBuy and result.unitPrice <= maxBuy then
                available = available + quantity
            elseif maxBuy and result.unitPrice > maxBuy then
                break
            end
        end
    end
    return cheapest, available
end

local function ReadItem(itemKey, maxBuy, maxQty)
    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    local cheapest, available = nil, 0
    local auctionID, buyoutAmount, buyQty
    for index = 1, count do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
        if result and result.buyoutAmount and result.buyoutAmount > 0 and not result.containsOwnerItem then
            local quantity = result.quantity or 1
            if quantity < 1 then
                quantity = 1
            end
            local unit = math.floor(result.buyoutAmount / quantity)
            if not cheapest then
                cheapest = unit
            end
            if maxBuy and unit <= maxBuy then
                available = available + quantity
                if not auctionID and quantity <= maxQty then
                    auctionID = result.auctionID
                    buyoutAmount = result.buyoutAmount
                    buyQty = quantity
                end
            end
        end
    end
    return cheapest, available, auctionID, buyoutAmount, buyQty
end

local function ApplySnapshot(itemID, snap, wasDeal)
    local entry = SF.FindWatch(itemID)
    snap.isDeal = false
    if entry and snap.unitPrice and entry.maxBuy and snap.unitPrice <= entry.maxBuy then
        if snap.isCommodity then
            snap.isDeal = (snap.available or 0) > 0
        else
            snap.isDeal = snap.auctionID ~= nil
        end
    end
    snap.scannedAt = time()
    SF.results[itemID] = snap
    if snap.isDeal and not wasDeal then
        SF.newDeals = (SF.newDeals or 0) + 1
        SF.Print("Ganga: " .. SF.ItemLabel(itemID) .. " a " .. SF.FormatMoney(snap.unitPrice) .. ".")
    end
    SF.Refresh()
end

local function FinishWaiting()
    local waiting = SF.waiting
    if not waiting or waiting.done then
        return
    end
    waiting.done = true
    SF.waiting = nil
    if SF.scanning then
        C_Timer.After(0.2, SF.ScanNext)
    end
end

local function ResolveKind(waiting)
    if waiting.isCommodity ~= nil then
        return waiting.isCommodity
    end
    if waiting.itemKey and C_AuctionHouse.GetItemKeyInfo then
        local info = C_AuctionHouse.GetItemKeyInfo(waiting.itemKey)
        if info and info.isCommodity ~= nil then
            waiting.isCommodity = info.isCommodity and true or false
            return waiting.isCommodity
        end
    end
    return nil
end

local function LowestUnit(itemID, itemKey, isCommodity)
    local cheapest
    if isCommodity then
        local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
        for index = 1, count do
            local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
            if result and result.unitPrice and result.unitPrice > 0 and (not cheapest or result.unitPrice < cheapest) then
                cheapest = result.unitPrice
            end
        end
        return cheapest
    end
    if not itemKey then
        return nil
    end
    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    for index = 1, count do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
        if result and result.buyoutAmount and result.buyoutAmount > 0 then
            local quantity = result.quantity or 1
            if quantity < 1 then
                quantity = 1
            end
            local unit = math.floor(result.buyoutAmount / quantity)
            if unit > 0 and (not cheapest or unit < cheapest) then
                cheapest = unit
            end
        end
    end
    return cheapest
end

local function TryFinish(itemID, fromCommodityEvent)
    local waiting = SF.waiting
    if not waiting or waiting.done or waiting.itemID ~= itemID then
        return
    end

    local kind = ResolveKind(waiting)
    if kind == true and not fromCommodityEvent then
        return
    end
    if kind == false and fromCommodityEvent then
        return
    end

    local commodityCount = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    local itemCount = 0
    if waiting.itemKey then
        itemCount = C_AuctionHouse.GetNumItemSearchResults(waiting.itemKey) or 0
    end

    if kind == nil then
        if fromCommodityEvent and commodityCount > 0 then
            kind = true
        elseif not fromCommodityEvent and itemCount > 0 then
            kind = false
        elseif waiting.commodityEvent and waiting.itemEvent then
            kind = false
        else
            return
        end
        waiting.isCommodity = kind
    end

    if kind and not waiting.askedMore then
        local partial = C_AuctionHouse.HasFullCommoditySearchResults and not C_AuctionHouse.HasFullCommoditySearchResults(itemID)
        if partial then
            waiting.askedMore = true
            if pcall(C_AuctionHouse.RequestMoreCommoditySearchResults, itemID) then
                return
            end
        end
    elseif not kind and not waiting.askedMore then
        local partial = waiting.itemKey and C_AuctionHouse.HasFullItemSearchResults and not C_AuctionHouse.HasFullItemSearchResults(waiting.itemKey)
        if partial then
            waiting.askedMore = true
            if pcall(C_AuctionHouse.RequestMoreItemSearchResults, waiting.itemKey) then
                return
            end
        end
    end

    local entry = SF.FindWatch(itemID)
    local maxBuy = entry and entry.maxBuy or nil
    local maxQty = entry and entry.maxQty or 1
    local previous = SF.results[itemID]
    local wasDeal = previous and previous.isDeal
    local snap

    if kind then
        local unitPrice, available = ReadCommodity(itemID, maxBuy)
        snap = {
            isCommodity = true,
            unitPrice = unitPrice,
            available = available,
            status = unitPrice and "ok" or "empty",
        }
    else
        local unitPrice, available, auctionID, buyoutAmount, buyQty = ReadItem(waiting.itemKey, maxBuy, maxQty)
        snap = {
            isCommodity = false,
            unitPrice = unitPrice,
            available = available,
            auctionID = auctionID,
            buyoutAmount = buyoutAmount,
            buyQty = buyQty,
            status = unitPrice and "ok" or "empty",
        }
    end

    if waiting.quote then
        local lowest = LowestUnit(itemID, waiting.itemKey, kind)
        if lowest then
            snap.unitPrice = lowest
        end
        FinishWaiting()
        if SF.OnQuote then
            SF.OnQuote(itemID, snap)
        end
        return
    end

    ApplySnapshot(itemID, snap, wasDeal)
    FinishWaiting()
end

function SF.StartQuote(itemID)
    if not SF.ahOpen or not itemID then
        return
    end
    if SF.scanning or (SF.waiting and not SF.waiting.quote) then
        if SF.sale then
            SF.sale.searching = false
        end
        SF.Print("Termina el escaneo antes de mirar el precio de venta.")
        if SF.RefreshSell then
            SF.RefreshSell()
        end
        return
    end
    if not ThrottleReady() then
        C_Timer.After(0.3, function()
            if SF.sale and SF.sale.itemID == itemID and SF.sale.searching then
                SF.StartQuote(itemID)
            end
        end)
        return
    end

    local keyOk, itemKey = pcall(C_AuctionHouse.MakeItemKey, itemID)
    if not keyOk or type(itemKey) ~= "table" then
        if SF.sale then
            SF.sale.searching = false
        end
        SF.Print("No se puede buscar " .. SF.ItemLabel(itemID) .. ".")
        if SF.RefreshSell then
            SF.RefreshSell()
        end
        return
    end

    local token = {}
    SF.waiting = {
        itemID = itemID,
        itemKey = itemKey,
        token = token,
        done = false,
        quote = true,
    }
    if not pcall(C_AuctionHouse.SendSearchQuery, itemKey, PRICE_SORTS, true) then
        SF.waiting = nil
        if SF.sale then
            SF.sale.searching = false
        end
        SF.Print("La casa ha rechazado la búsqueda de " .. SF.ItemLabel(itemID) .. ".")
        if SF.RefreshSell then
            SF.RefreshSell()
        end
        return
    end

    C_Timer.After(12, function()
        local waiting = SF.waiting
        if not waiting or waiting.token ~= token or waiting.done then
            return
        end
        if waiting.itemEvent or waiting.commodityEvent then
            waiting.askedMore = true
            waiting.itemEvent = true
            waiting.commodityEvent = true
            TryFinish(itemID, ResolveKind(waiting) ~= false)
            return
        end
        SF.waiting = nil
        if SF.sale and SF.sale.itemID == itemID then
            SF.sale.searching = false
            if SF.RefreshSell then
                SF.RefreshSell()
            end
        end
        SF.Print("Sin respuesta al buscar el precio de venta.")
    end)
end

function SF.ScanNext()
    if not SF.scanning then
        return
    end
    if not SF.ahOpen then
        SF.scanning = false
        SF.waiting = nil
        SF.Refresh()
        return
    end
    if SF.scanPos > #SF.scanQueue then
        SF.scanning = false
        SF.OnScanComplete()
        return
    end
    if not ThrottleReady() then
        return
    end

    local itemID = SF.scanQueue[SF.scanPos]
    SF.scanPos = SF.scanPos + 1

    local previous = SF.results[itemID]
    SF.results[itemID] = {
        status = "scanning",
        isDeal = previous and previous.isDeal,
        unitPrice = previous and previous.unitPrice,
        available = previous and previous.available,
        isCommodity = previous and previous.isCommodity,
        auctionID = previous and previous.auctionID,
        buyoutAmount = previous and previous.buyoutAmount,
        buyQty = previous and previous.buyQty,
    }
    SF.Refresh()

    local keyOk, itemKey = pcall(C_AuctionHouse.MakeItemKey, itemID)
    if not keyOk or type(itemKey) ~= "table" then
        SF.results[itemID] = { status = "error", isDeal = false }
        SF.Print("No se puede buscar " .. SF.ItemLabel(itemID) .. ".")
        C_Timer.After(0.2, SF.ScanNext)
        return
    end

    local token = {}
    SF.waiting = {
        itemID = itemID,
        itemKey = itemKey,
        token = token,
        done = false,
    }

    if not pcall(C_AuctionHouse.SendSearchQuery, itemKey, PRICE_SORTS, true) then
        SF.waiting = nil
        SF.results[itemID] = { status = "error", isDeal = false }
        SF.Print("La casa ha rechazado la búsqueda de " .. SF.ItemLabel(itemID) .. ".")
        C_Timer.After(0.2, SF.ScanNext)
        return
    end

    C_Timer.After(12, function()
        local waiting = SF.waiting
        if not waiting or waiting.token ~= token or waiting.done then
            return
        end
        if waiting.itemEvent or waiting.commodityEvent then
            waiting.askedMore = true
            waiting.itemEvent = true
            waiting.commodityEvent = true
            TryFinish(itemID, ResolveKind(waiting) ~= false)
            if SF.waiting and SF.waiting.token == token and not SF.waiting.done then
                FinishWaiting()
            end
            return
        end
        local prior = SF.results[itemID]
        SF.results[itemID] = {
            status = "error",
            isDeal = false,
            unitPrice = prior and prior.unitPrice,
        }
        SF.Print("Sin respuesta al buscar " .. SF.ItemLabel(itemID) .. ".")
        FinishWaiting()
        SF.Refresh()
    end)
end

function SF.StartScan(reason)
    if not SF.db then
        return
    end
    if not SF.ahOpen then
        SF.Print("Abre la casa de subastas para escanear.")
        return
    end
    if SF.pendingBuy then
        SF.Print("Termina la compra pendiente antes de escanear.")
        return
    end
    if SF.scanning then
        return
    end

    local queue = {}
    for _, entry in ipairs(SF.db.watch) do
        if entry.enabled ~= false then
            queue[#queue + 1] = entry.itemID
        end
    end
    if #queue == 0 then
        SF.Print("La lista está vacía. Mayús-clic en un objeto para vigilarlo.")
        return
    end

    SF.scanQueue = queue
    SF.scanPos = 1
    SF.scanning = true
    SF.scanReason = reason or "manual"
    SF.newDeals = 0
    SF.notice = nil
    SF.Print("Escaneando " .. #queue .. " objetos...")
    SF.ScanNext()
end

function SF.OnScanComplete()
    local deals = 0
    if SF.db then
        for _, entry in ipairs(SF.db.watch) do
            if SF.IsDeal(entry) then
                deals = deals + 1
            end
        end
    end
    SF.lastScanAt = GetTime()
    if SF.db and SF.db.autoSort and SF.SortWatch then
        SF.SortWatch()
    end
    SF.Print(string.format("Escaneo listo. %d gangas.", deals))
    if (SF.newDeals or 0) > 0 or (SF.scanReason == "manual" and deals > 0) then
        if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK_READY then
            PlaySound(SOUNDKIT.READY_CHECK_READY, "Master")
        end
    end
    SF.Refresh()
    if SF.ScheduleAutoScan then
        SF.ScheduleAutoScan()
    end
end

function SF.ScheduleAutoScan()
    if SF.autoToken or not SF.db or not SF.db.autoScan or not SF.ahOpen then
        return
    end
    local token = {}
    SF.autoToken = token
    C_Timer.After(60, function()
        if SF.autoToken ~= token then
            return
        end
        SF.autoToken = nil
        if not SF.db.autoScan or not SF.ahOpen then
            return
        end
        if SF.scanning or SF.pendingBuy then
            SF.ScheduleAutoScan()
            return
        end
        SF.StartScan("auto")
    end)
end

SF.On("AUCTION_HOUSE_SHOW", function()
    SF.ahOpen = true
    if SF.db and SF.db.autoOpen and not SF.suppressAutoOpen and SF.Show then
        SF.Show()
    end
    SF.Refresh()
    if SF.db and SF.db.autoScan then
        SF.ScheduleAutoScan()
    end
end)

SF.On("AUCTION_HOUSE_CLOSED", function()
    SF.ahOpen = false
    SF.suppressAutoOpen = false
    SF.scanning = false
    SF.waiting = nil
    SF.autoToken = nil
    SF.pendingBuy = nil
    SF.Refresh()
end)

SF.On("AUCTION_HOUSE_THROTTLED_SYSTEM_READY", function()
    if SF.scanning and not SF.waiting then
        SF.ScanNext()
    end
end)

local function OnCommodityResults(itemID)
    local waiting = SF.waiting
    if not waiting or waiting.done or waiting.itemID ~= itemID then
        return
    end
    waiting.commodityEvent = true
    TryFinish(itemID, true)
end

local function OnItemResults(itemKey)
    if type(itemKey) ~= "table" or not itemKey.itemID then
        return
    end
    local waiting = SF.waiting
    if not waiting or waiting.done or waiting.itemID ~= itemKey.itemID then
        return
    end
    waiting.itemKey = itemKey
    waiting.itemEvent = true
    TryFinish(itemKey.itemID, false)
end

SF.On("COMMODITY_SEARCH_RESULTS_UPDATED", OnCommodityResults)
SF.On("COMMODITY_SEARCH_RESULTS_ADDED", OnCommodityResults)
SF.On("ITEM_SEARCH_RESULTS_UPDATED", OnItemResults)
SF.On("ITEM_SEARCH_RESULTS_ADDED", OnItemResults)

SF.On("AUCTION_HOUSE_SHOW_ERROR", function(errorType)
    if SF.scanning or SF.pendingBuy then
        SF.Print("La casa de subastas ha devuelto un error (" .. tostring(errorType) .. ").")
    end
end)
