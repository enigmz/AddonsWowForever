local _, SF = ...

local ROW_HEIGHT = 48
local ROW_WIDTH = 640

local frame, helpFrame
local rows = {}
local itemBox, buyBox, sellBox, qtyBox
local statusText, pendingText
local confirmButton, cancelPendingButton
local scrollChild

local function SetMoneyBox(box, copper)
    box:SetText(copper and SF.MoneyToInput(copper) or "")
end

local function Note(message)
    SF.notice = message
    SF.Print(message)
    if statusText then
        statusText:SetText(message)
    end
end

local function AddFromForm()
    local text = itemBox:GetText() or ""
    local itemID = SF.ResolveItem(text, itemBox.linkedID)
    if not itemID then
        local shown = SF.PlainItemName(text)
        if shown == "" then
            Note("Mayús-clic en el objeto, o escribe su nombre o su ID.")
        else
            Note("No encuentro «" .. shown .. "». Mayús-clic en él o escribe el ID.")
        end
        return
    end
    local maxBuy = SF.ParseMoney(buyBox:GetText() or "")
    local sellPrice = SF.ParseMoney(sellBox:GetText() or "")
    local qty = tonumber(strtrim(qtyBox:GetText() or ""))
    if not maxBuy or maxBuy <= 0 then
        Note("Precio de compra no válido. Ejemplo: 1s50c")
        return
    end
    if not sellPrice or sellPrice <= 0 then
        Note("Precio de venta no válido. Ejemplo: 2s")
        return
    end
    if not qty or qty < 1 then
        qty = 1
    end
    qty = math.floor(qty)
    local added, addError = pcall(SF.AddWatch, itemID, maxBuy, sellPrice, qty)
    if not added then
        Note("No se ha podido añadir: " .. tostring(addError))
        return
    end
    itemBox.linkedID = nil
    itemBox:SetText("")
    itemBox:ClearFocus()
    if frame and frame.UpdatePricePreview then
        frame.UpdatePricePreview()
    end
end

local function FillForm(entry)
    if not entry then
        return
    end
    itemBox.linkedID = entry.itemID
    local _, link = C_Item.GetItemInfo(entry.itemID)
    itemBox:SetText(link or SF.ItemName(entry.itemID) or tostring(entry.itemID))
    SetMoneyBox(buyBox, entry.maxBuy)
    SetMoneyBox(sellBox, entry.sellPrice)
    qtyBox:SetText(tostring(entry.maxQty or 1))
end

local function MakeEdit(parent, width)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(width, 20)
    box:SetAutoFocus(false)
    box:SetFontObject(ChatFontNormal)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        AddFromForm()
    end)
    return box
end

local function MakeButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    return button
end

local function StatusLine()
    if not SF.db then
        return ""
    end
    local deals = 0
    for _, entry in ipairs(SF.db.watch) do
        if SF.IsDeal(entry) then
            deals = deals + 1
        end
    end
    local scan = "sin escanear"
    if SF.scanning then
        local total = SF.scanQueue and #SF.scanQueue or 0
        local current = math.min(SF.scanPos or 1, total)
        scan = string.format("escaneando %d/%d", current, total)
    end
    return string.format("%d en lista · %d gangas · %s · casa %s", #SF.db.watch, deals, scan, SF.ahOpen and "abierta" or "cerrada")
end

local function UpdateScanAge()
    if not frame or not frame.scanAge then
        return
    end
    local text, r, g, b
    if SF.scanning then
        local total = SF.scanQueue and #SF.scanQueue or 0
        local current = math.min(SF.scanPos or 1, total)
        if total > 0 then
            text = string.format("Escaneando %d/%d.", current, total)
        else
            text = "Escaneando."
        end
        r, g, b = 1, 0.82, 0.3
    elseif not SF.lastScanAt then
        text = "Aún no se ha escaneado."
        r, g, b = 0.7, 0.7, 0.7
    else
        local seconds = math.max(0, math.floor(GetTime() - SF.lastScanAt))
        text = "Último escaneo hace " .. seconds .. " s."
        if SF.db and SF.db.autoScan and SF.ahOpen then
            text = text .. " Con la casa abierta se repite cada minuto."
        elseif not SF.ahOpen then
            text = text .. " La casa está cerrada y no se actualiza."
        end
        r, g, b = 0.75, 0.86, 0.72
    end
    frame.scanAge:SetText(text)
    frame.scanAge:SetTextColor(r, g, b)
end

local HELP_TEXT = table.concat({
    "|cffffd100Qué hace|r",
    "Vigila los objetos de tu lista en la casa de subastas. Si el precio baja de tu máximo, puedes comprarlo. La venta guardada sirve para calcular el beneficio.",
    "",
    "|cffffd100Añadir un objeto|r",
    "Mayús-clic en el objeto, desde las bolsas o el chat, o escribe su nombre o su ID. Rellena la compra máxima, la venta y la cantidad, y pulsa Añadir.",
    "Un clic normal en una fila vuelve a cargar esos datos en el formulario, por si quieres cambiarlos y pulsar Añadir otra vez.",
    "",
    "|cffffd100Precios|r",
    "1s50c es 1 plata y 50 cobres. 50c son 50 cobres. 2s son 2 platas. También vale 1p50c. Un número suelto se lee como oro: 0.15 son 15 platas.",
    "",
    "|cffffd100La lista|r",
    "Arriba de cada fila está el precio actual de la casa. Debajo, lo que guardaste: compra máxima, venta y cantidad.",
    "Ganga significa que el precio actual está en tu máximo o por debajo, y hay unidades. Alto significa que ahora cuesta más de lo que estás dispuesto a pagar. La casilla de la izquierda pausa ese objeto. La X lo quita de la lista.",
    "Vender se enciende si ese objeto está en las bolsas, con la casa abierta. Publica hasta la cantidad de la lista, al precio de venta guardado. La duración es el botón de 12 h, 24 h o 48 h.",
    "Mayús-clic en el nombre lo escribe en el buscador de la casa y lanza la búsqueda.",
    "Las flechas de la izquierda suben o bajan el objeto. Ese orden es el de Comprar siguiente y el escaneo.",
    "Autoordenar, al terminar un escaneo, pone las gangas arriba y los precios altos abajo. Si está desmarcado, la lista se queda como la dejaste.",
    "",
    "|cffffd100Comprar|r",
    "Comprar solo se enciende con la casa abierta y si el objeto es una ganga.",
    "En materiales hacen falta dos clics: Comprar pide el precio y Confirmar, abajo, cierra la compra. El juego no deja confirmarla solo. Si el precio se ha pasado de tu máximo, pulsa Cancelar.",
    "En equipo, recetas y el resto de objetos que no son materiales, Comprar cierra la compra en un clic.",
    "Comprar siguiente toma la primera ganga de la lista.",
    "",
    "|cffffd100Escanear|r",
    "Escanear mira una vez el precio de todos los objetos activos. Reescanear, marcado una sola vez, repite esa pasada cada minuto mientras la casa sigue abierta y avisa si aparece una ganga. La casilla se guarda.",
    "Encima de la lista se ve si está escaneando, o cuántos segundos han pasado desde el último escaneo.",
    "Al abrir la casa, la primera pasada automática espera ese minuto. Si quieres el precio al momento, pulsa Escanear.",
    "Abrir aquí muestra esta ventana cada vez que abres la casa.",
    "La esquina inferior derecha alarga la ventana hacia abajo para ver más filas. El clic derecho restaura el alto.",
    "Con la casa abierta, los objetos de la mochila que se pueden subastar llevan una moneda.",
    "",
    "|cffffd100Límites del juego|r",
    "Con la casa cerrada no llegan precios nuevos. Tampoco se puede comprar ni vender.",
    "No se puede comprar solo, sin tu clic. Escanear y marcar gangas sí puede ir solo; la compra, no.",
    "",
    "|cffffd100Órdenes|r",
    "/sf o /subastas abre y cierra la ventana. /sf escanear busca precios. /sf estado resume la lista. /sf cancelar descarta una compra de materiales a medias.",
}, "\n")

local function ApplyPortrait(name, title, width, height)
    local portraitOk, created = pcall(CreateFrame, "Frame", name, UIParent, "PortraitFrameTemplate")
    local popup = portraitOk and created or CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    if not portraitOk then
        popup:SetBackdrop({
            bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true,
            tileSize = 256,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    popup:SetSize(width, height)
    popup:SetFrameStrata("HIGH")
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:Hide()
    if popup.SetTitle then
        pcall(popup.SetTitle, popup, title)
    elseif popup.TitleText then
        popup.TitleText:SetText(title)
    end
    local coin = "Interface\\Icons\\INV_Misc_Coin_01"
    local portraitSet = false
    if popup.SetPortraitToAsset then
        portraitSet = pcall(popup.SetPortraitToAsset, popup, coin)
    end
    if not portraitSet then
        local portrait = popup.portrait or (popup.PortraitContainer and popup.PortraitContainer.portrait)
        if portrait and SetPortraitToTexture then
            SetPortraitToTexture(portrait, coin)
        end
    end
    local drag = CreateFrame("Frame", nil, popup)
    drag:SetPoint("TOPLEFT", 62, -1)
    drag:SetPoint("TOPRIGHT", -36, -1)
    drag:SetHeight(30)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        popup:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        popup:StopMovingOrSizing()
    end)
    return popup
end

local function EnsureHelpFrame()
    if helpFrame then
        return helpFrame
    end
    helpFrame = ApplyPortrait("SubastasForeverHelpFrame", "Cómo funciona", 440, 520)
    helpFrame:SetPoint("CENTER")
    tinsert(UISpecialFrames, "SubastasForeverHelpFrame")

    local scroll = CreateFrame("ScrollFrame", nil, helpFrame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 22, -68)
    scroll:SetPoint("BOTTOMRIGHT", -32, 18)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(360, 400)
    scroll:SetScrollChild(child)
    local body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", 2, -2)
    body:SetWidth(350)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(3)
    body:SetText(HELP_TEXT)
    helpFrame:SetScript("OnShow", function()
        local height = body:GetStringHeight()
        if height and height > 0 then
            child:SetHeight(height + 8)
        end
    end)
    return helpFrame
end

local function ShowTip(owner, title, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 0.82, 0.45)
    for _, line in ipairs(lines) do
        GameTooltip:AddLine(line, 1, 1, 1, true)
    end
    GameTooltip:Show()
end

local function HideTip()
    GameTooltip:Hide()
end

local function CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()

    row.up = CreateFrame("Button", nil, row, "UIPanelScrollUpButtonTemplate")
    row.up:SetPoint("TOPLEFT", -2, -2)
    row.up:SetScript("OnClick", function()
        if row.entry then
            SF.MoveWatch(row.entry.itemID, -1)
        end
    end)
    row.up:SetScript("OnEnter", function(self)
        ShowTip(self, "Subir", { "Lo coloca una posición más arriba." })
    end)
    row.up:SetScript("OnLeave", HideTip)

    row.down = CreateFrame("Button", nil, row, "UIPanelScrollDownButtonTemplate")
    row.down:SetPoint("BOTTOMLEFT", -2, 2)
    row.down:SetScript("OnClick", function()
        if row.entry then
            SF.MoveWatch(row.entry.itemID, 1)
        end
    end)
    row.down:SetScript("OnEnter", function(self)
        ShowTip(self, "Bajar", { "Lo coloca una posición más abajo." })
    end)
    row.down:SetScript("OnLeave", HideTip)

    row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.check:SetSize(24, 24)
    row.check:SetPoint("LEFT", 18, 6)
    row.check:SetScript("OnClick", function(self)
        if row.entry then
            row.entry.enabled = self:GetChecked()
            SF.Refresh()
        end
    end)
    row.check:SetScript("OnEnter", function(self)
        ShowTip(self, "Vigilar", { "Marcado: entra en el escaneo y se puede comprar.", "Desmarcado: queda en pausa y se ignora." })
    end)
    row.check:SetScript("OnLeave", HideTip)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", row.check, "RIGHT", 2, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.config = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.config:SetPoint("BOTTOMLEFT", 74, 3)
    row.config:SetPoint("BOTTOMRIGHT", -4, 3)
    row.config:SetJustifyH("LEFT")
    row.config:SetWordWrap(false)
    row.config:SetTextColor(0.9, 0.82, 0.55)

    row.price = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.price:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.price:SetWidth(130)
    row.price:SetJustifyH("LEFT")
    row.price:SetWordWrap(false)

    row.state = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.state:SetPoint("LEFT", row.price, "RIGHT", 4, 0)
    row.state:SetWidth(78)
    row.state:SetJustifyH("LEFT")

    row.buy = MakeButton(row, "Comprar", 76)
    row.buy:SetPoint("LEFT", row.state, "RIGHT", 4, 0)
    row.buy:SetScript("OnClick", function()
        if row.entry then
            SF.BuyEntry(row.entry)
        end
    end)
    row.buy:SetScript("OnEnter", function(self)
        local entry = row.entry
        local snap = entry and SF.results[entry.itemID]
        if not entry or not snap or not snap.unitPrice then
            ShowTip(self, "Comprar", { "Escanea primero para ver el precio." })
            return
        end
        local qty = entry.maxQty or 1
        if snap.isCommodity then
            qty = math.min(qty, snap.available or 0)
        else
            qty = snap.buyQty or qty
        end
        local cost = snap.unitPrice * math.max(qty, 0)
        local net = math.floor(entry.sellPrice * 0.95) - snap.unitPrice
        ShowTip(self, "Comprar", {
            "Actual: " .. SF.FormatMoney(snap.unitPrice),
            "Tu máximo: " .. SF.FormatMoney(entry.maxBuy),
            "Esta compra: " .. qty .. " uds, " .. SF.FormatMoney(cost),
            "Beneficio estimado por unidad, tras el 5%: " .. SF.FormatMoney(net),
        })
    end)
    row.buy:SetScript("OnLeave", HideTip)

    row.sell = MakeButton(row, "Vender", 64)
    row.sell:SetPoint("LEFT", row.buy, "RIGHT", 4, 0)
    row.sell:SetScript("OnClick", function()
        if row.entry then
            SF.PostEntry(row.entry)
        end
    end)
    row.sell:SetScript("OnEnter", function(self)
        local entry = row.entry
        if not entry then
            return
        end
        local lines = {
            "Publica hasta " .. (entry.maxQty or 1) .. " unidades a " .. SF.FormatMoney(entry.sellPrice) .. ".",
            "En bolsas: " .. SF.CountInBags(entry.itemID) .. ".",
            "Duración: " .. SF.DurationLabel() .. ".",
        }
        local snap = SF.results[entry.itemID]
        if snap and snap.unitPrice and entry.sellPrice > snap.unitPrice then
            lines[#lines + 1] = "Tu venta está por encima del precio actual. Puede tardar en venderse."
        end
        ShowTip(self, "Vender", lines)
    end)
    row.sell:SetScript("OnLeave", HideTip)

    row.remove = MakeButton(row, "X", 24)
    row.remove:SetPoint("LEFT", row.sell, "RIGHT", 4, 0)
    row.remove:SetScript("OnClick", function()
        if row.entry then
            SF.RemoveWatch(row.entry.itemID)
        end
    end)
    row.remove:SetScript("OnEnter", function(self)
        ShowTip(self, "Quitar", { "Saca este objeto de la lista." })
    end)
    row.remove:SetScript("OnLeave", HideTip)

    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" or not row.entry then
            return
        end
        if IsShiftKeyDown() then
            SF.SearchAuctionHouse(row.entry.itemID)
            return
        end
        FillForm(row.entry)
    end)

    return row
end

local function PaintRow(row, entry, index)
    row.entry = entry
    row:Show()
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    local snap = SF.results[entry.itemID]
    local deal = SF.IsDeal(entry)
    if deal then
        row.bg:SetColorTexture(0.08, 0.28, 0.08, 0.55)
    elseif index % 2 == 0 then
        row.bg:SetColorTexture(0, 0, 0, 0.18)
    else
        row.bg:SetColorTexture(0, 0, 0, 0.32)
    end

    row.check:SetChecked(entry.enabled ~= false)

    local icon
    if C_Item.GetItemIconByID then
        local iconOk, iconValue = pcall(C_Item.GetItemIconByID, entry.itemID)
        if iconOk then
            icon = iconValue
        end
    end
    if icon then
        row.icon:SetTexture(icon)
    else
        row.icon:SetColorTexture(0.4, 0.32, 0.1, 1)
    end

    local name = SF.names[entry.itemID] or SF.ItemName(entry.itemID) or ("Objeto " .. entry.itemID)
    SF.names[entry.itemID] = name
    row.name:SetText(name)
    row.config:SetText(string.format(
        "Compra máx. %s    Venta %s    Cant. %d",
        SF.FormatMoney(entry.maxBuy),
        SF.FormatMoney(entry.sellPrice),
        entry.maxQty or 1
    ))

    if snap and snap.unitPrice then
        row.price:SetText(SF.FormatMoney(snap.unitPrice))
    else
        row.price:SetText("-")
    end

    local state, r, g, b = "Sin datos", 0.7, 0.7, 0.7
    if entry.enabled == false then
        state, r, g, b = "Pausa", 0.6, 0.6, 0.6
    elseif snap and snap.status == "scanning" then
        state, r, g, b = "Buscando", 0.9, 0.8, 0.3
    elseif snap and snap.status == "error" then
        state, r, g, b = "Error", 0.9, 0.3, 0.3
    elseif snap and snap.status == "empty" then
        state, r, g, b = "Sin stock", 0.7, 0.7, 0.7
    elseif deal then
        state, r, g, b = "Ganga", 0.2, 0.9, 0.3
    elseif snap and snap.unitPrice then
        state, r, g, b = "Alto", 0.95, 0.35, 0.3
    end
    row.state:SetText(state)
    row.state:SetTextColor(r, g, b)

    local count = SF.db and SF.db.watch and #SF.db.watch or index
    row.up:SetEnabled(index > 1)
    row.down:SetEnabled(index < count)
    row.buy:SetEnabled(deal and SF.ahOpen and not SF.pendingBuy)
    local inBags = false
    local bagOk, bagCount = pcall(SF.CountInBags, entry.itemID)
    if bagOk then
        inBags = (bagCount or 0) > 0
    end
    row.sell:SetEnabled(inBags and SF.ahOpen and not SF.pendingBuy and (entry.sellPrice or 0) >= 1)
end

function SF.RefreshUI()
    if not frame or not SF.db then
        return
    end

    local watch = SF.db.watch or {}
    SF.db.watch = watch
    local count = #watch
    scrollChild:SetHeight(math.max(ROW_HEIGHT, count * ROW_HEIGHT))
    if frame.emptyText then
        frame.emptyText:SetShown(count == 0)
    end

    for index, entry in ipairs(watch) do
        local row = rows[index]
        if not row then
            row = CreateRow(scrollChild)
            rows[index] = row
        end
        PaintRow(row, entry, index)
    end
    for index = count + 1, #rows do
        rows[index]:Hide()
        rows[index].entry = nil
    end

    if SF.notice then
        statusText:SetText(SF.notice)
    else
        statusText:SetText(StatusLine())
    end
    UpdateScanAge()

    if SF.pendingBuy then
        local pending = SF.pendingBuy
        if pending.blocked then
            pendingText:SetText("Por encima de tu máximo. Pulsa Cancelar.")
        elseif pending.quoted then
            pendingText:SetText("Pulsa Confirmar: " .. pending.quantity .. " x " .. SF.ItemLabel(pending.itemID) .. " a " .. SF.FormatMoney(pending.quoted))
        else
            pendingText:SetText("Consultando " .. pending.quantity .. " x " .. SF.ItemLabel(pending.itemID) .. "...")
        end
        confirmButton:Show()
        cancelPendingButton:Show()
        confirmButton:SetEnabled(pending.quoted ~= nil and not pending.blocked)
    else
        pendingText:SetText("")
        confirmButton:Hide()
        cancelPendingButton:Hide()
    end

    if frame.durationButton and SF.DurationLabel then
        frame.durationButton:SetText(SF.DurationLabel())
    end
end

function SF.InitUI()
    if frame then
        return
    end

    local portraitOk, created = pcall(CreateFrame, "Frame", "SubastasForeverFrame", UIParent, "PortraitFrameTemplate")
    if portraitOk then
        frame = created
    else
        frame = CreateFrame("Frame", "SubastasForeverFrame", UIParent, "BackdropTemplate")
        frame:SetBackdrop({
            bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
            tile = true,
            tileSize = 256,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    frame:SetSize(700, 556)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    local windowScale = SF.db and tonumber(SF.db.scale) or 1
    if windowScale < 0.7 or windowScale > 1.5 then
        windowScale = 1
    end
    frame:SetScale(windowScale)
    local windowHeight = SF.db and tonumber(SF.db.height) or 556
    if windowHeight and windowHeight >= 420 then
        frame:SetHeight(windowHeight)
    end
    if SF.db and SF.db.point then
        frame:SetPoint(SF.db.point, UIParent, SF.db.relPoint or "CENTER", SF.db.x or 0, SF.db.y or 0)
    else
        frame:SetPoint("CENTER")
    end
    tinsert(UISpecialFrames, "SubastasForeverFrame")

    local titled = false
    if frame.SetTitle then
        titled = pcall(frame.SetTitle, frame, "Subastas Forever")
    end
    if not titled and frame.TitleText then
        frame.TitleText:SetText("Subastas Forever")
        titled = true
    end
    local coin = "Interface\\Icons\\INV_Misc_Coin_01"
    local portraitSet = false
    if frame.SetPortraitToAsset then
        portraitSet = pcall(frame.SetPortraitToAsset, frame, coin)
    end
    if not portraitSet then
        local portrait = frame.portrait or (frame.PortraitContainer and frame.PortraitContainer.portrait)
        if portrait and SetPortraitToTexture then
            SetPortraitToTexture(portrait, coin)
        end
    end

    local drag = CreateFrame("Frame", nil, frame)
    drag:SetPoint("TOPLEFT", 62, -1)
    drag:SetPoint("TOPRIGHT", -36, -1)
    drag:SetHeight(30)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SF.EnsureDB()
        local point, _, relPoint, x, y = frame:GetPoint()
        SF.db.point, SF.db.relPoint, SF.db.x, SF.db.y = point, relPoint, x, y
    end)

    if not titled then
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -8)
        title:SetText("Subastas Forever")
    end

    local close = frame.CloseButton
    if close then
        close:HookScript("OnClick", function()
            SF.suppressAutoOpen = true
            frame:Hide()
        end)
        close:HookScript("OnEnter", function(self)
            ShowTip(self, "Cerrar", { "Cierra esta ventana. No vuelve a abrirse sola hasta que abras la casa otra vez." })
        end)
        close:HookScript("OnLeave", HideTip)
    else
        close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        close:SetScript("OnClick", function()
            SF.suppressAutoOpen = true
            frame:Hide()
        end)
        close:SetScript("OnEnter", function(self)
            ShowTip(self, "Cerrar", { "Cierra esta ventana. No vuelve a abrirse sola hasta que abras la casa otra vez." })
        end)
        close:SetScript("OnLeave", HideTip)
    end

    local helpButton = CreateFrame("Button", nil, frame)
    helpButton:SetSize(26, 26)
    helpButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -36)
    helpButton:SetFrameLevel(frame:GetFrameLevel() + 40)
    helpButton:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    helpButton:SetPushedTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    helpButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local helpPushed = helpButton:GetPushedTexture()
    if helpPushed then
        helpPushed:SetVertexColor(0.7, 0.7, 0.7)
    end
    helpButton:SetScript("OnEnter", function(self)
        ShowTip(self, "Ayuda", { "Cómo funciona el addon." })
    end)
    helpButton:SetScript("OnLeave", HideTip)
    helpButton:SetScript("OnClick", function()
        local popup = EnsureHelpFrame()
        if popup:IsShown() then
            popup:Hide()
        else
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
            popup:Show()
        end
    end)

    local help = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("TOPLEFT", 22, -68)
    help:SetPoint("TOPRIGHT", -22, -68)
    help:SetJustifyH("LEFT")
    help:SetHeight(28)
    help:SetText("Mayús-clic en la lista lo busca en la casa. Precios: 1s50c, 2s, o 0.15 (15 platas).")

    itemBox = MakeEdit(frame, 210)
    itemBox:SetPoint("TOPLEFT", 28, -124)
    local labelItem = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    labelItem:SetPoint("BOTTOMLEFT", itemBox, "TOPLEFT", -4, 4)
    labelItem:SetText("Objeto")

    buyBox = MakeEdit(frame, 110)
    buyBox:SetPoint("LEFT", itemBox, "RIGHT", 16, 0)
    local labelBuy = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    labelBuy:SetPoint("BOTTOMLEFT", buyBox, "TOPLEFT", -4, 4)
    labelBuy:SetText("Compra máx.")

    sellBox = MakeEdit(frame, 90)
    sellBox:SetPoint("LEFT", buyBox, "RIGHT", 12, 0)
    local labelSell = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    labelSell:SetPoint("BOTTOMLEFT", sellBox, "TOPLEFT", -4, 4)
    labelSell:SetText("Venta")

    qtyBox = MakeEdit(frame, 48)
    qtyBox:SetPoint("LEFT", sellBox, "RIGHT", 12, 0)
    qtyBox:SetNumeric(true)
    qtyBox:SetText("20")
    local labelQty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    labelQty:SetPoint("BOTTOMLEFT", qtyBox, "TOPLEFT", -4, 4)
    labelQty:SetText("Cant.")

    local addButton = MakeButton(frame, "Añadir", 120)
    addButton:SetPoint("TOPRIGHT", -28, -123)
    addButton:SetFrameLevel(frame:GetFrameLevel() + 30)
    addButton:SetScript("OnClick", AddFromForm)
    addButton:SetScript("OnEnter", function(self)
        ShowTip(self, "Añadir", { "Guarda el objeto con la compra máxima, la venta y la cantidad.", "Si ya estaba en la lista, actualiza esos datos." })
    end)
    addButton:SetScript("OnLeave", HideTip)

    local pricePreview = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    pricePreview:SetPoint("TOPLEFT", 24, -148)
    pricePreview:SetPoint("RIGHT", frame, "RIGHT", -150, 0)
    pricePreview:SetJustifyH("LEFT")
    pricePreview:SetWordWrap(true)
    pricePreview:SetHeight(32)
    pricePreview:SetText("")
    frame.pricePreview = pricePreview

    local function UpdatePricePreview()
        local buy = SF.ParseMoney(buyBox:GetText() or "")
        local sell = SF.ParseMoney(sellBox:GetText() or "")
        local buyText = buy and SF.MoneyWords(buy) or "—"
        local sellText = sell and SF.MoneyWords(sell) or "—"
        local extra = ""
        local itemText = itemBox:GetText() or ""
        local itemID = SF.ResolveItem(itemText, itemBox.linkedID)
        local objectLine
        if strtrim(itemText) == "" then
            objectLine = "Mayús-clic en un objeto"
        elseif itemID then
            itemBox.linkedID = itemID
            objectLine = "|cff55ff55Listo:|r " .. (SF.ItemName(itemID) or SF.PlainItemName(itemText))
        else
            objectLine = "|cffff6666Objeto no reconocido. Mayús-clic otra vez.|r"
        end
        pricePreview:SetText(objectLine .. "  ·  compra " .. buyText .. "  ·  venta " .. sellText .. extra)
    end
    buyBox:SetScript("OnTextChanged", UpdatePricePreview)
    sellBox:SetScript("OnTextChanged", UpdatePricePreview)
    frame.UpdatePricePreview = UpdatePricePreview

    local function RememberItem(self)
        local text = strtrim(self:GetText() or "")
        if text == "" then
            self.linkedID = nil
            if frame.UpdatePricePreview then
                frame.UpdatePricePreview()
            end
            return
        end
        local id = SF.ParseItemID(text)
        if id then
            self.linkedID = id
        end
        if frame.UpdatePricePreview then
            frame.UpdatePricePreview()
        end
    end
    itemBox:SetScript("OnTextChanged", RememberItem)

    local header = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    header:SetPoint("TOPLEFT", 78, -202)
    header:SetText("Objeto")
    local headerPrice = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerPrice:SetPoint("LEFT", header, "RIGHT", 150, 0)
    headerPrice:SetText("Precio actual")
    local headerState = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    headerState:SetPoint("LEFT", headerPrice, "RIGHT", 62, 0)
    headerState:SetText("Estado")

    local scanAge = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scanAge:SetPoint("BOTTOMLEFT", header, "TOPLEFT", -56, 3)
    scanAge:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    scanAge:SetJustifyH("LEFT")
    scanAge:SetWordWrap(false)
    frame.scanAge = scanAge

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -220)
    scroll:SetPoint("BOTTOMRIGHT", -32, 96)
    local insetOk, listInset = pcall(CreateFrame, "Frame", nil, frame, "InsetFrameTemplate")
    if insetOk and listInset then
        listInset:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 4)
        listInset:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 26, -6)
        listInset:SetFrameLevel(math.max(frame:GetFrameLevel(), 1))
        scroll:SetFrameLevel(listInset:GetFrameLevel() + 2)
    end
    scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(ROW_WIDTH, ROW_HEIGHT)
    scroll:SetScrollChild(scrollChild)

    local empty = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    empty:SetPoint("TOPLEFT", 8, -8)
    empty:SetText("La lista está vacía.")
    frame.emptyText = empty

    pendingText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pendingText:SetPoint("BOTTOMLEFT", 24, 64)
    pendingText:SetWidth(420)
    pendingText:SetJustifyH("LEFT")
    pendingText:SetText("")

    confirmButton = MakeButton(frame, "Confirmar", 100)
    confirmButton:SetPoint("LEFT", pendingText, "RIGHT", 8, 0)
    confirmButton:SetScript("OnClick", function()
        SF.ConfirmPending()
    end)
    confirmButton:SetScript("OnEnter", function(self)
        ShowTip(self, "Confirmar", { "Cierra la compra de materiales al precio que acaba de dar la casa.", "Solo se enciende si ese precio no pasa de tu máximo." })
    end)
    confirmButton:SetScript("OnLeave", HideTip)
    confirmButton:Hide()

    cancelPendingButton = MakeButton(frame, "Cancelar", 90)
    cancelPendingButton:SetPoint("LEFT", confirmButton, "RIGHT", 6, 0)
    cancelPendingButton:SetScript("OnClick", function()
        SF.CancelPending()
    end)
    cancelPendingButton:SetScript("OnEnter", function(self)
        ShowTip(self, "Cancelar", { "Descarta la compra de materiales que está pendiente." })
    end)
    cancelPendingButton:SetScript("OnLeave", HideTip)
    cancelPendingButton:Hide()

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", 24, 42)
    statusText:SetWidth(460)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("")

    local scanButton = MakeButton(frame, "Escanear", 100)
    scanButton:SetPoint("BOTTOMLEFT", 20, 16)
    scanButton:SetScript("OnClick", function()
        SF.StartScan("manual")
    end)
    scanButton:SetScript("OnEnter", function(self)
        ShowTip(self, "Escanear", { "Consulta ahora el precio de todos los objetos activos de la lista." })
    end)
    scanButton:SetScript("OnLeave", HideTip)

    local buyNext = MakeButton(frame, "Comprar siguiente", 140)
    buyNext:SetPoint("LEFT", scanButton, "RIGHT", 8, 0)
    buyNext:SetScript("OnClick", function()
        SF.BuyNext()
    end)
    buyNext:SetScript("OnEnter", function(self)
        ShowTip(self, "Comprar siguiente", { "Compra la primera ganga de la lista, de arriba a abajo.", "En materiales, después hay que pulsar Confirmar." })
    end)
    buyNext:SetScript("OnLeave", HideTip)

    local durationButton = MakeButton(frame, "24 h", 70)
    durationButton:SetPoint("LEFT", buyNext, "RIGHT", 8, 0)
    durationButton:SetScript("OnClick", function()
        SF.CycleDuration()
    end)
    durationButton:SetScript("OnEnter", function(self)
        ShowTip(self, "Duración", { "12 h, 24 h o 48 h. La usa el botón Vender de cada objeto." })
    end)
    durationButton:SetScript("OnLeave", HideTip)
    frame.durationButton = durationButton

    local autoOpen = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    autoOpen:SetPoint("BOTTOMRIGHT", -168, 12)
    autoOpen:SetSize(24, 24)
    autoOpen.text = autoOpen:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoOpen.text:SetPoint("LEFT", autoOpen, "RIGHT", 2, 0)
    autoOpen.text:SetText("Abrir aquí")
    autoOpen:SetScript("OnClick", function(self)
        SF.db.autoOpen = self:GetChecked()
    end)
    autoOpen:SetScript("OnEnter", function(self)
        ShowTip(self, "Abrir aquí", { "Si está marcado, esta ventana se abre sola al abrir la casa de subastas." })
    end)
    autoOpen:SetScript("OnLeave", HideTip)
    autoOpen.text:EnableMouse(true)
    autoOpen.text:SetScript("OnEnter", function()
        ShowTip(autoOpen, "Abrir aquí", { "Si está marcado, esta ventana se abre sola al abrir la casa de subastas." })
    end)
    autoOpen.text:SetScript("OnLeave", HideTip)
    frame.autoOpen = autoOpen

    local autoScan = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    autoScan:SetPoint("BOTTOMLEFT", autoOpen, "TOPLEFT", 0, 0)
    autoScan:SetSize(24, 24)
    autoScan.text = autoScan:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoScan.text:SetPoint("LEFT", autoScan, "RIGHT", 2, 0)
    autoScan.text:SetText("Reescanear")
    autoScan:SetScript("OnClick", function(self)
        SF.db.autoScan = self:GetChecked()
        if SF.db.autoScan and SF.ahOpen then
            SF.ScheduleAutoScan()
        else
            SF.autoToken = nil
        end
    end)
    autoScan:SetScript("OnEnter", function(self)
        ShowTip(self, "Reescanear", { "Cada minuto, con la casa de subastas abierta, vuelve a mirar los precios y avisa si aparece una ganga nueva." })
    end)
    autoScan:SetScript("OnLeave", HideTip)
    frame.autoScan = autoScan

    local autoSort = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    autoSort:SetPoint("BOTTOMLEFT", autoScan, "TOPLEFT", 0, 0)
    autoSort:SetSize(24, 24)
    autoSort.text = autoSort:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    autoSort.text:SetPoint("LEFT", autoSort, "RIGHT", 2, 0)
    autoSort.text:SetText("Auto ordenar")
    autoSort:SetScript("OnClick", function(self)
        SF.db.autoSort = self:GetChecked()
    end)
    autoSort:SetScript("OnEnter", function(self)
        ShowTip(self, "Auto ordenar", { "Al terminar el escaneo, las gangas pasan arriba y los precios altos, abajo. Si lo quitas, se respeta el orden de las flechas." })
    end)
    autoSort:SetScript("OnLeave", HideTip)
    frame.autoSort = autoSort

    local function AcceptLink(link)
        local id = SF.RememberLink(link)
        if not id or not frame:IsShown() then
            return
        end
        local busy = itemBox.linkedID and strtrim(itemBox:GetText() or "") ~= ""
        if busy and not itemBox:HasFocus() then
            return
        end
        itemBox.linkedID = id
        itemBox:SetText(link)
        if frame.UpdatePricePreview then
            frame.UpdatePricePreview()
        end
    end
    if hooksecurefunc then
        if ChatEdit_InsertLink then
            hooksecurefunc("ChatEdit_InsertLink", AcceptLink)
        end
        if ChatFrameUtil and ChatFrameUtil.InsertLink then
            hooksecurefunc(ChatFrameUtil, "InsertLink", AcceptLink)
        end
    end

    SF.frame = frame
    frame:SetScript("OnShow", function()
        frame.autoOpen:SetChecked(SF.db.autoOpen)
        frame.autoScan:SetChecked(SF.db.autoScan)
        frame.autoSort:SetChecked(SF.db.autoSort)
        if frame.emptyText then
            frame.emptyText:SetShown(#SF.db.watch == 0)
        end
        if frame.UpdatePricePreview then
            frame.UpdatePricePreview()
        end
        SF.RefreshUI()
    end)
    frame:SetScript("OnHide", function()
        if helpFrame then
            helpFrame:Hide()
        end
    end)
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -6, 6)
    grip:SetFrameLevel(frame:GetFrameLevel() + 50)
    grip:RegisterForDrag("LeftButton")
    if grip.SetNormalAtlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("UI-Frame-Resize") then
        grip:SetNormalAtlas("UI-Frame-Resize")
    else
        grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
        grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    end

    local function ClampWindowHeight(height)
        local minH = 420
        local scale = frame:GetScale()
        if not scale or scale < 0.1 then
            scale = 1
        end
        local maxH = math.max(minH, UIParent:GetHeight() / scale - 40)
        height = tonumber(height) or 556
        if height < minH then
            height = minH
        elseif height > maxH then
            height = maxH
        end
        return math.floor(height + 0.5)
    end

    local function ApplyWindowHeight(height, persist)
        height = ClampWindowHeight(height)
        frame:SetHeight(height)
        if persist then
            SF.EnsureDB()
            SF.db.height = height
        end
        return height
    end

    grip:SetScript("OnEnter", function(self)
        ShowTip(self, "Alto de la lista", { "Arrastra hacia abajo para ver más filas, y hacia arriba para reducir.", "Clic derecho restaura el alto." })
    end)
    grip:SetScript("OnLeave", HideTip)
    grip:SetScript("OnDragStart", function(self)
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        self.startY = select(2, GetCursorPosition())
        self.startHeight = frame:GetHeight()
        self:SetScript("OnUpdate", function(button)
            local y = select(2, GetCursorPosition())
            local scale = frame:GetEffectiveScale()
            if not scale or scale < 0.1 then
                scale = 1
            end
            local dy = (button.startY - y) / scale
            ApplyWindowHeight(button.startHeight + dy, false)
        end)
    end)
    grip:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        ApplyWindowHeight(frame:GetHeight(), true)
        SF.EnsureDB()
        local point, _, relPoint, x, y = frame:GetPoint()
        SF.db.point, SF.db.relPoint, SF.db.x, SF.db.y = point, relPoint, x, y
    end)
    grip:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ApplyWindowHeight(556, true)
        end
    end)

    local scanAgeWait = 0
    frame:SetScript("OnUpdate", function(_, elapsed)
        scanAgeWait = scanAgeWait + elapsed
        if scanAgeWait < 0.25 then
            return
        end
        scanAgeWait = 0
        UpdateScanAge()
    end)

    SF.RefreshUI()
end

local baseRefresh = SF.RefreshUI
SF.RefreshUI = function()
    baseRefresh()
    if frame and frame:IsShown() then
        frame.emptyText:SetShown(#SF.db.watch == 0)
    end
end

function SF.Show()
    if not frame then
        SF.InitUI()
    end
    SF.suppressAutoOpen = false
    frame:Show()
end

function SF.Toggle()
    if not frame then
        SF.InitUI()
    end
    if frame:IsShown() then
        SF.suppressAutoOpen = true
        frame:Hide()
    else
        SF.Show()
    end
end

function SubastasForever_OnClick()
    if SF.Toggle then
        SF.Toggle()
    end
end
