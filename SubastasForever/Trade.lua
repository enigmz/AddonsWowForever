local _, SF = ...

local DURATION_LABEL = {
    [1] = "12 h",
    [2] = "24 h",
    [3] = "48 h",
}

function SF.DurationLabel()
    return DURATION_LABEL[SF.db and SF.db.duration or 2] or "24 h"
end

function SF.CycleDuration()
    local duration = SF.db.duration or 2
    duration = duration + 1
    if duration > 3 then
        duration = 1
    end
    SF.db.duration = duration
    SF.Print("Duración de venta: " .. SF.DurationLabel() .. ".")
    SF.Refresh()
end

local function BuyQuantity(entry, snap)
    local wanted = entry.maxQty or 1
    if snap.isCommodity then
        return math.min(wanted, snap.available or 0)
    end
    return snap.buyQty or 0
end

function SF.BuyEntry(entry)
    if not entry or not SF.ahOpen then
        SF.Print("Abre la casa de subastas para comprar.")
        return
    end
    if SF.pendingBuy then
        SF.Print("Ya hay una compra pendiente. Confírmala o cancélala.")
        return
    end
    if not SF.IsDeal(entry) then
        SF.Print("Ese objeto no está por debajo de tu precio máximo.")
        return
    end

    local snap = SF.results[entry.itemID]
    local quantity = BuyQuantity(entry, snap)
    if quantity < 1 then
        SF.Print("No hay cantidad comprable dentro de tu límite.")
        return
    end

    if snap.isCommodity then
        -- El precio puede llegar dentro de esta misma llamada. La pendiente tiene que existir antes.
        -- Confirm va en el botón Confirmar: Blizzard no deja cerrar la compra desde el evento.
        SF.pendingBuy = {
            itemID = entry.itemID,
            quantity = quantity,
            maxBuy = entry.maxBuy,
        }
        C_AuctionHouse.StartCommoditiesPurchase(entry.itemID, quantity)
        if not SF.pendingBuy or not SF.pendingBuy.quoted then
            SF.Print("Precio pedido. Cuando aparezca, pulsa Confirmar.")
        end
        SF.Refresh()
        return
    end

    C_AuctionHouse.PlaceBid(snap.auctionID, snap.buyoutAmount)
    SF.Print("Compra enviada: " .. quantity .. " x " .. SF.ItemLabel(entry.itemID) .. " por " .. SF.FormatMoney(snap.buyoutAmount) .. ".")
    snap.auctionID = nil
    snap.isDeal = false
    SF.Refresh()
end

function SF.BuyNext()
    if not SF.db then
        return
    end
    for _, entry in ipairs(SF.db.watch) do
        if SF.IsDeal(entry) then
            SF.BuyEntry(entry)
            return
        end
    end
    SF.Print("No hay gangas en el último escaneo.")
end

function SF.ConfirmPending()
    local pending = SF.pendingBuy
    if not pending then
        return
    end
    if pending.blocked then
        SF.Print("Esa oferta se ha pasado de tu máximo. Cancélala.")
        return
    end
    C_AuctionHouse.ConfirmCommoditiesPurchase(pending.itemID, pending.quantity)
end

function SF.CancelPending()
    if not SF.pendingBuy then
        return
    end
    C_AuctionHouse.CancelCommoditiesPurchase()
    SF.pendingBuy = nil
    SF.Print("Compra cancelada.")
    SF.Refresh()
end

function SF.ClearPending()
    SF.pendingBuy = nil
    pcall(C_AuctionHouse.CancelCommoditiesPurchase)
    SF.Refresh()
end

function SF.PostEntry(entry)
    if not entry or not SF.ahOpen then
        SF.Print("Abre la casa de subastas para vender.")
        return
    end
    if SF.pendingBuy then
        SF.Print("Termina la compra pendiente antes de vender.")
        return
    end

    local unit = math.floor(tonumber(entry.sellPrice) or 0)
    if unit < 1 then
        SF.Print("El precio de venta tiene que ser al menos 1 cobre.")
        return
    end

    local location, stackCount = SF.FirstBagStack(entry.itemID)
    if not location then
        SF.Print("No tienes " .. SF.ItemLabel(entry.itemID) .. " en las bolsas.")
        return
    end
    if C_Item and C_Item.IsBound and C_Item.IsBound(location) then
        SF.Print("Ese objeto está ligado y no se puede subastar.")
        return
    end

    local quantity = math.min(entry.maxQty or stackCount, stackCount)
    if quantity < 1 then
        return
    end

    local snap = SF.results[entry.itemID]
    local isCommodity = snap and snap.isCommodity or false
    if C_AuctionHouse.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus then
        local ok, status = pcall(C_AuctionHouse.GetItemCommodityStatus, location)
        if ok and status == Enum.ItemCommodityStatus.Commodity then
            isCommodity = true
        elseif ok and status == Enum.ItemCommodityStatus.Item then
            isCommodity = false
        end
    end

    local duration = SF.db.duration or 2
    local posted
    if isCommodity then
        posted = pcall(C_AuctionHouse.PostCommodity, location, duration, quantity, unit)
    else
        posted = pcall(C_AuctionHouse.PostItem, location, duration, quantity, nil, unit * quantity)
    end
    if not posted then
        SF.Print("La casa no ha aceptado la venta de " .. SF.ItemLabel(entry.itemID) .. ".")
        return
    end
    SF.Print("Publicando " .. quantity .. " x " .. SF.ItemLabel(entry.itemID) .. " a " .. SF.FormatMoney(unit) .. " (" .. SF.DurationLabel() .. ").")
end

SF.On("COMMODITY_PRICE_UPDATED", function(unitPrice, totalPrice)
    local pending = SF.pendingBuy
    if not pending or pending.quoted or type(unitPrice) ~= "number" then
        return
    end
    pending.quoted = unitPrice
    pending.totalPrice = type(totalPrice) == "number" and totalPrice or nil
    if unitPrice > pending.maxBuy then
        pending.blocked = true
        SF.Print("El precio ha subido a " .. SF.FormatMoney(unitPrice) .. ", por encima de tu máximo. Pulsa Cancelar.")
        pcall(C_AuctionHouse.CancelCommoditiesPurchase)
        SF.Refresh()
        return
    end
    pending.needsClick = true
    SF.Print("Pulsa Confirmar para comprar a " .. SF.FormatMoney(unitPrice) .. " la unidad.")
    SF.Refresh()
end)

SF.On("COMMODITY_PRICE_UNAVAILABLE", function()
    if not SF.pendingBuy then
        return
    end
    SF.pendingBuy = nil
    SF.Print("Ese precio ya no está disponible.")
    SF.Refresh()
end)

SF.On("COMMODITY_PURCHASE_SUCCEEDED", function()
    local pending = SF.pendingBuy
    SF.pendingBuy = nil
    if pending then
        local total = pending.quoted and (pending.quoted * pending.quantity) or nil
        local spent = total and (" por " .. SF.FormatMoney(total)) or ""
        SF.Print("Comprado: " .. pending.quantity .. " x " .. SF.ItemLabel(pending.itemID) .. spent .. ".")
    else
        SF.Print("Compra realizada.")
    end
    SF.Refresh()
end)

SF.On("COMMODITY_PURCHASE_FAILED", function()
    if not SF.pendingBuy then
        return
    end
    SF.pendingBuy = nil
    SF.Print("La compra no se ha completado.")
    SF.Refresh()
end)

SF.On("AUCTION_HOUSE_AUCTION_CREATED", function()
    SF.Refresh()
end)

SF.On("BAG_UPDATE_DELAYED", function()
    SF.Refresh()
end)
