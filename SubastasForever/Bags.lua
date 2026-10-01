local _, SF = ...

local marks = {}

local function ButtonBagSlot(button)
    if button.GetBagID then
        local bag = button:GetBagID()
        local slot = button:GetID()
        if type(bag) == "number" and type(slot) == "number" and slot > 0 then
            return bag, slot
        end
    end
    local parent = button:GetParent()
    if parent and parent.GetID and button.GetID then
        local bag = parent:GetID()
        local slot = button:GetID()
        if type(bag) == "number" and type(slot) == "number" and slot > 0 then
            return bag, slot
        end
    end
    return nil
end

local function CanAuction(bag, slot)
    if not C_Container or not ItemLocation or not C_Container.GetContainerItemInfo then
        return false
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.itemID or info.isLocked then
        return false
    end
    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not location or not location.IsValid or not location:IsValid() then
        return false
    end
    if C_AuctionHouse and C_AuctionHouse.IsSellItemValid then
        local ok, valid = pcall(C_AuctionHouse.IsSellItemValid, location)
        if ok then
            return valid and true or false
        end
    end
    if C_Item and C_Item.IsBound then
        local ok, bound = pcall(C_Item.IsBound, location)
        if ok and bound then
            return false
        end
    end
    return true
end

local function EnsureMark(button)
    local mark = button.sfMark
    if mark then
        return mark
    end
    mark = CreateFrame("Frame", nil, button)
    mark:SetSize(16, 16)
    mark:SetPoint("TOPLEFT", 1, -1)
    local icon = mark:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    mark:EnableMouse(true)
    mark:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Se puede subastar", 1, 0.82, 0.45)
        GameTooltip:Show()
    end)
    mark:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button.sfMark = mark
    marks[#marks + 1] = mark
    return mark
end

local function VisitContainer(container, visitor)
    if not container then
        return
    end
    local buttons = container.Items or container.itemButtons
    if type(buttons) == "table" then
        for _, button in ipairs(buttons) do
            if button then
                visitor(button)
            end
        end
        return
    end
    local name = container.GetName and container:GetName()
    if not name then
        return
    end
    for slot = 1, 40 do
        local button = _G[name .. "Item" .. slot]
        if not button then
            break
        end
        visitor(button)
    end
end

local function EachBagButton(visitor)
    if ContainerFrameCombinedBags then
        VisitContainer(ContainerFrameCombinedBags, visitor)
    end
    local count = NUM_CONTAINER_FRAMES or 13
    for index = 1, count do
        VisitContainer(_G["ContainerFrame" .. index], visitor)
    end
end

function SF.RefreshBagMarks()
    if not SF.ahOpen then
        for index = 1, #marks do
            marks[index]:Hide()
        end
        return
    end
    EachBagButton(function(button)
        local mark = EnsureMark(button)
        mark:SetFrameLevel((button:GetFrameLevel() or 1) + 20)
        local bag, slot = ButtonBagSlot(button)
        if bag and slot and button:IsShown() and CanAuction(bag, slot) then
            mark:Show()
        else
            mark:Hide()
        end
    end)
end

SF.On("AUCTION_HOUSE_SHOW", function()
    C_Timer.After(0.2, SF.RefreshBagMarks)
end)

SF.On("AUCTION_HOUSE_CLOSED", function()
    SF.RefreshBagMarks()
end)

SF.On("BAG_UPDATE_DELAYED", function()
    SF.RefreshBagMarks()
end)

if hooksecurefunc and type(ContainerFrame_Update) == "function" then
    hooksecurefunc("ContainerFrame_Update", function()
        if SF.RefreshBagMarks then
            SF.RefreshBagMarks()
        end
    end)
end
