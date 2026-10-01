local addonName, SF = ...

SF.addonName = addonName
SF.results = {}
SF.ahOpen = false
SF.names = {}

local DEFAULTS = {
    watch = {},
    autoOpen = true,
    autoScan = false,
    autoSort = false,
    scale = 1,
    height = 556,
    duration = 2,
}

local function CopyDefaults(dst, src)
    for key, value in pairs(src) do
        if dst[key] == nil then
            if type(value) == "table" then
                dst[key] = {}
                CopyDefaults(dst[key], value)
            else
                dst[key] = value
            end
        end
    end
end

function SF.Print(message)
    local text = "|cffd4a85aSubastas|r " .. tostring(message)
    local count = NUM_CHAT_WINDOWS or 0
    local sent = false
    for index = 1, count do
        local chat = _G["ChatFrame" .. index]
        if chat and chat.AddMessage then
            chat:AddMessage(text)
            sent = true
        end
    end
    if not sent then
        print(text)
    end
end

function SF.RememberLink(link)
    if type(link) ~= "string" then
        return nil
    end
    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then
        return nil
    end
    SF.lastLink = link
    SF.lastLinkID = itemID
    SF.lastLinkName = SF.PlainItemName and SF.PlainItemName(link) or nil
    return itemID
end

function SF.Refresh()
    if SF.RefreshUI then
        SF.RefreshUI()
    end
end

function SF.PlainItemName(text)
    if type(text) ~= "string" then
        return ""
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|cn.-:", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|h", "")
    text = strtrim(text)
    local inner = text:match("^%[(.+)%]$")
    if inner then
        text = strtrim(inner)
    end
    return text
end

local function ItemIDFromQuery(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if instant then
        local ok, itemID = pcall(instant, value)
        if ok and type(itemID) == "number" then
            return itemID
        end
    end
    if C_Item and C_Item.GetItemInfo then
        local ok, _, link = pcall(C_Item.GetItemInfo, value)
        if ok and type(link) == "string" then
            local id = link:match("item:(%d+)")
            if id then
                return tonumber(id)
            end
        end
    end
    return nil
end

function SF.ParseItemID(text)
    if type(text) ~= "string" then
        return nil
    end
    text = strtrim(text)
    if text == "" then
        return nil
    end
    local fromLink = text:match("item:(%d+)")
    if fromLink then
        return tonumber(fromLink)
    end
    local numeric = text:match("^(%d+)$")
    if numeric then
        return tonumber(numeric)
    end
    local name = SF.PlainItemName(text)
    return ItemIDFromQuery(name) or ItemIDFromQuery(text)
end

function SF.ItemName(itemID)
    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemID)
        if name then
            return name
        end
    end
    if C_Item and C_Item.GetItemInfo then
        local name = C_Item.GetItemInfo(itemID)
        if name then
            return name
        end
    end
    return SF.names[itemID]
end

function SF.NameMatches(text, itemID)
    local plain = SF.PlainItemName(text):lower()
    if plain == "" then
        return false
    end
    if SF.lastLinkID == itemID and SF.lastLinkName and plain == SF.lastLinkName:lower() then
        return true
    end
    local name = SF.ItemName(itemID)
    if not name then
        return false
    end
    return plain == name:lower()
end

function SF.ResolveItem(text, linkedID)
    if linkedID then
        return linkedID
    end
    local parsed = SF.ParseItemID(text)
    if parsed then
        return parsed
    end
    local plain = SF.PlainItemName(text):lower()
    if plain ~= "" and SF.lastLinkID and SF.lastLinkName and plain == SF.lastLinkName:lower() then
        return SF.lastLinkID
    end
    local houseID = SF.AuctionHouseItem()
    if houseID and SF.NameMatches(text, houseID) then
        return houseID
    end
    return nil
end

function SF.AuctionHouseItem()
    local house = AuctionHouseFrame
    if not house then
        return nil
    end
    local frames = { house.CommoditiesBuyFrame, house.ItemBuyFrame, house.BuyFrame }
    for index = 1, #frames do
        local display = frames[index] and frames[index].ItemDisplay
        local itemKey = display and display.itemKey
        if itemKey and itemKey.itemID then
            return itemKey.itemID
        end
    end
    return nil
end

function SF.SearchAuctionHouse(itemID)
    local house = AuctionHouseFrame
    if not house or not house:IsShown() then
        SF.Print("Abre la casa de subastas para buscar.")
        return
    end
    local name = SF.ItemName(itemID)
    if not name or name == "" then
        SF.RequestItem(itemID)
        SF.Print("Todavía no tengo el nombre de ese objeto.")
        return
    end
    local bar = house.SearchBar
    if not bar or not bar.SetSearchText or not bar.StartSearch then
        SF.Print("No encuentro el buscador de la casa de subastas.")
        return
    end
    if house.SetDisplayMode and AuctionHouseFrameDisplayMode and AuctionHouseFrameDisplayMode.Buy then
        pcall(house.SetDisplayMode, house, AuctionHouseFrameDisplayMode.Buy)
    end
    bar:SetSearchText(name)
    local ok, err = pcall(bar.StartSearch, bar)
    if not ok then
        SF.Print("La búsqueda no se ha podido lanzar: " .. tostring(err))
    end
end

-- Texto libre a cobre.
-- "1s50c" o "1p50c" = 1 plata y 50 cobres. "2s" = 2 platas.
-- Un número suelto es oro: "0.15" = 15 platas, no 1 plata y 50 cobres.
function SF.ParseMoney(text)
    if type(text) ~= "string" then
        return nil
    end
    text = strtrim(text):lower():gsub(",", ".")
    text = text:gsub("%s+", "")
    if text == "" then
        return nil
    end
    text = text:gsub("plata", "s"):gsub("cobre", "c"):gsub("oro", "g")
    text = text:gsub("p", "s"):gsub("o", "g")

    -- La "s" va entre corchetes: en un patrón, %s significa espacio, no la letra s.
    local goldPart = text:match("([%d%.]+)g")
    local silverPart = text:match("([%d%.]+)[s]")
    local copperPart = text:match("([%d%.]+)c")
    if goldPart or silverPart or copperPart then
        local gold = tonumber(goldPart) or 0
        local silver = tonumber(silverPart) or 0
        local copper = tonumber(copperPart) or 0
        return math.floor(gold * 10000 + silver * 100 + copper + 0.5)
    end

    local amount = tonumber(text)
    if not amount or amount < 0 then
        return nil
    end
    return math.floor(amount * 10000 + 0.5)
end

function SF.MoneyToInput(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    local text = ""
    if gold > 0 then
        text = gold .. "g"
    end
    if silver > 0 then
        text = text .. silver .. "s"
    end
    if rest > 0 then
        text = text .. rest .. "c"
    end
    if text == "" then
        return "0c"
    end
    return text
end

function SF.MoneyWords(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = gold .. (gold == 1 and " oro" or " oros")
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. (silver == 1 and " plata" or " platas")
    end
    if rest > 0 then
        parts[#parts + 1] = rest .. (rest == 1 and " cobre" or " cobres")
    end
    if #parts == 0 then
        return "0 cobres"
    end
    return table.concat(parts, " y ")
end

function SF.FormatMoney(copper)
    copper = tonumber(copper)
    if not copper then
        return "-"
    end
    if GetMoneyString then
        local ok, text = pcall(GetMoneyString, copper)
        if ok and type(text) == "string" and text ~= "" then
            return text
        end
    end
    return SF.MoneyWords(copper)
end

function SF.ItemLabel(itemID)
    if C_Item and C_Item.GetItemInfo then
        local _, link = C_Item.GetItemInfo(itemID)
        if link then
            return link
        end
    end
    return SF.names[itemID] or ("Objeto " .. tostring(itemID))
end

function SF.RequestItem(itemID)
    if SF.names[itemID] then
        return
    end
    local name
    if C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(itemID)
    end
    if not name and C_Item.GetItemInfo then
        name = C_Item.GetItemInfo(itemID)
    end
    if name then
        SF.names[itemID] = name
        return
    end
    if C_Item.RequestLoadItemDataByID then
        C_Item.RequestLoadItemDataByID(itemID)
    end
end

function SF.FindWatch(itemID)
    local watch = SF.db and SF.db.watch
    if not watch then
        return nil
    end
    for index, entry in ipairs(watch) do
        if entry.itemID == itemID then
            return entry, index
        end
    end
    return nil
end

function SF.AddWatch(itemID, maxBuy, sellPrice, maxQty)
    SF.EnsureDB()
    local entry = SF.FindWatch(itemID)
    if entry then
        entry.maxBuy = maxBuy
        entry.sellPrice = sellPrice
        entry.maxQty = maxQty
        entry.enabled = true
    else
        SF.db.watch[#SF.db.watch + 1] = {
            itemID = itemID,
            maxBuy = maxBuy,
            sellPrice = sellPrice,
            maxQty = maxQty,
            enabled = true,
        }
    end
    pcall(SF.RequestItem, itemID)
    SF.notice = "En la lista: " .. (SF.ItemName(itemID) or ("objeto " .. itemID)) .. ". Compra " .. SF.MoneyWords(maxBuy) .. ". Venta " .. SF.MoneyWords(sellPrice) .. "."
    local net = math.floor((tonumber(sellPrice) or 0) * 0.95) - (tonumber(maxBuy) or 0)
    if net <= 0 then
        SF.Print(SF.notice .. " Con esos precios no queda beneficio tras el 5% de la casa.")
    else
        SF.Print(SF.notice .. " Beneficio estimado: " .. SF.MoneyWords(net) .. " por unidad.")
    end
    local refreshed, refreshError = pcall(SF.Refresh)
    if not refreshed then
        SF.Print("El objeto está guardado, pero la lista no se ha podido dibujar: " .. tostring(refreshError))
    end
end

function SF.MoveWatch(itemID, direction)
    local _, index = SF.FindWatch(itemID)
    local watch = SF.db and SF.db.watch
    if not index or not watch then
        return
    end
    local target = index + direction
    if target < 1 or target > #watch then
        return
    end
    watch[index], watch[target] = watch[target], watch[index]
    SF.Refresh()
end

local function WatchRank(entry)
    if SF.IsDeal(entry) then
        return 1
    end
    local snap = SF.results[entry.itemID]
    if entry.enabled ~= false and snap and snap.unitPrice and entry.maxBuy and snap.unitPrice > entry.maxBuy then
        return 3
    end
    return 2
end

function SF.SortWatch()
    local watch = SF.db and SF.db.watch
    if not watch or #watch < 2 then
        return
    end
    local rows = {}
    for index, entry in ipairs(watch) do
        rows[index] = { entry = entry, index = index, rank = WatchRank(entry) }
    end
    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.index < b.index
    end)
    for index, row in ipairs(rows) do
        watch[index] = row.entry
    end
end

function SF.RemoveWatch(itemID)
    local _, index = SF.FindWatch(itemID)
    if not index then
        return
    end
    table.remove(SF.db.watch, index)
    SF.results[itemID] = nil
    SF.Refresh()
end

function SF.IsDeal(entry)
    if not entry or entry.enabled == false then
        return false
    end
    local snap = SF.results[entry.itemID]
    if not snap or not snap.unitPrice or not entry.maxBuy then
        return false
    end
    if snap.unitPrice > entry.maxBuy then
        return false
    end
    if snap.isCommodity then
        return (snap.available or 0) > 0
    end
    return snap.auctionID ~= nil
end

function SF.BagList()
    local bags = {}
    if Enum and Enum.BagIndex then
        bags[#bags + 1] = Enum.BagIndex.Backpack or 0
        local bagSlots = (Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots) or 4
        for index = 1, bagSlots do
            local bag = Enum.BagIndex["Bag_" .. index]
            if bag then
                bags[#bags + 1] = bag
            end
        end
        if Enum.BagIndex.ReagentBag then
            bags[#bags + 1] = Enum.BagIndex.ReagentBag
        end
    else
        bags = { 0, 1, 2, 3, 4 }
    end
    return bags
end

function SF.CountInBags(itemID)
    local total = 0
    if not C_Container or not C_Container.GetContainerNumSlots then
        return 0
    end
    for _, bag in ipairs(SF.BagList()) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID then
                total = total + (info.stackCount or 1)
            end
        end
    end
    return total
end

function SF.FirstBagStack(itemID)
    if not C_Container or not ItemLocation then
        return nil
    end
    for _, bag in ipairs(SF.BagList()) do
        local slots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == itemID and not info.isLocked then
                local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
                return location, info.stackCount or 1
            end
        end
    end
    return nil
end

function SF.EnsureDB()
    if type(SubastasForeverDB) ~= "table" then
        SubastasForeverDB = {}
    end
    CopyDefaults(SubastasForeverDB, DEFAULTS)
    SF.db = SubastasForeverDB
    local duration = tonumber(SF.db.duration) or 2
    if duration < 1 or duration > 3 then
        duration = 2
    end
    SF.db.duration = duration

    if SF.dbReady then
        if type(SF.db.watch) ~= "table" then
            SF.db.watch = {}
        end
        return SF.db
    end

    local clean = {}
    if type(SF.db.watch) == "table" then
        for _, entry in ipairs(SF.db.watch) do
            if type(entry) == "table" and type(entry.itemID) == "number" then
                entry.maxBuy = tonumber(entry.maxBuy) or 0
                entry.sellPrice = tonumber(entry.sellPrice) or 0
                entry.maxQty = math.max(1, math.floor(tonumber(entry.maxQty) or 1))
                if entry.enabled == nil then
                    entry.enabled = true
                end
                clean[#clean + 1] = entry
                SF.RequestItem(entry.itemID)
            end
        end
    end
    SF.db.watch = clean
    SF.dbReady = true
    return SF.db
end

SF.handlers = {}

function SF.On(event, handler)
    SF.handlers[event] = SF.handlers[event] or {}
    SF.handlers[event][#SF.handlers[event] + 1] = handler
    SF.eventFrame:RegisterEvent(event)
end

SF.eventFrame = CreateFrame("Frame")
SF.eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = SF.handlers[event]
    if not list then
        return
    end
    for index = 1, #list do
        list[index](...)
    end
end)

SF.On("ADDON_LOADED", function(loaded)
    if loaded ~= addonName and loaded ~= "SubastasForever" then
        return
    end
    SF.EnsureDB()
    if SF.InitUI then
        SF.InitUI()
    end
    SF.Print("cargado. Escribe /sf o abre la casa de subastas.")
end)

SF.On("PLAYER_LOGIN", function()
    SF.EnsureDB()
    if SF.InitUI then
        SF.InitUI()
    end
end)

SF.On("ITEM_DATA_LOAD_RESULT", function(itemID, success)
    if not success then
        return
    end
    local name = C_Item.GetItemInfo(itemID)
    if name then
        SF.names[itemID] = name
    end
    if SF.FindWatch(itemID) then
        SF.Refresh()
    end
end)

SLASH_SUBASTASFOREVER1 = "/sf"
SLASH_SUBASTASFOREVER2 = "/subastas"
SlashCmdList.SUBASTASFOREVER = function(message)
    message = strtrim(message or ""):lower()
    if message == "cancelar" then
        if SF.pendingBuy and SF.ClearPending then
            SF.ClearPending()
            SF.Print("Compra pendiente descartada.")
        else
            SF.Print("No hay ninguna compra pendiente.")
        end
    elseif message == "scan" or message == "escanear" then
        if SF.Show then
            SF.Show()
        end
        if SF.StartScan then
            SF.StartScan("manual")
        end
    elseif message == "estado" then
        local deals = 0
        if SF.db then
            for _, entry in ipairs(SF.db.watch) do
                if SF.IsDeal(entry) then
                    deals = deals + 1
                end
            end
            SF.Print(string.format("%d objetos en la lista, %d gangas. Casa de subastas %s.", #SF.db.watch, deals, SF.ahOpen and "abierta" or "cerrada"))
        end
    else
        if SF.Toggle then
            SF.Toggle()
        end
    end
end
