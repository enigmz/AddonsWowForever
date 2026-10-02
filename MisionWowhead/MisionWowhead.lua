-- Icono en cada misión del diario y del rastreador. Al pulsarlo prepara el enlace de Wowhead.

local POPUP = "MISIONWOWHEAD_URL"
local hooked = {}

local function QuestUrl(questID)
	return "https://www.wowhead.com/classic/quest=" .. questID
end

local function PopupBox(dialog)
	if dialog.editBox then return dialog.editBox end
	local name = dialog.GetName and dialog:GetName()
	if not name then return nil end
	return _G[name .. "WideEditBox"] or _G[name .. "EditBox"]
end

StaticPopupDialogs[POPUP] = {
	text = "Enlace de Wowhead. Está seleccionado: cópialo y ábrelo en el navegador.",
	button1 = "Cerrar",
	hasEditBox = 1,
	hasWideEditBox = 1,
	editBoxWidth = 350,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
	OnShow = function(dialog)
		local box = PopupBox(dialog)
		local url = dialog.data or StaticPopupDialogs[POPUP].url or ""
		if not box then return end
		box:SetMaxLetters(200)
		box:SetText(url)
		box:SetFocus()
		box:HighlightText()
	end,
	EditBoxOnEscapePressed = function(box)
		box:GetParent():Hide()
	end,
	EditBoxOnEnterPressed = function(box)
		box:GetParent():Hide()
	end,
}

local function ShowPopup(url)
	StaticPopupDialogs[POPUP].url = url
	local dialog = StaticPopup_Show(POPUP, nil, nil, url)
	if not dialog then
		print("|cffffd100MisionWowhead|r: " .. url)
	end
end

local layer = CreateFrame("Frame", "MisionWowheadLayer", UIParent)
layer:SetAllPoints()
layer:EnableMouse(false)
layer:SetFrameStrata("MEDIUM")

local live = {}

local function ShownOnScreen(anchor)
	if not anchor or not anchor.IsVisible or not anchor:IsVisible() then return false end
	if anchor.GetAlpha and anchor:GetAlpha() < 0.05 then return false end
	local module = anchor.parentModule
	if module then
		if module.collapsed or (module.IsCollapsed and module:IsCollapsed()) then return false end
		local contents = module.ContentsFrame
		if contents and contents.IsVisible and not contents:IsVisible() then return false end
	end
	if ObjectiveTrackerFrame and anchor.parentModule then
		local tracker = ObjectiveTrackerFrame
		if tracker.collapsed or (tracker.IsCollapsed and tracker:IsCollapsed()) then return false end
	end
	local header = anchor.HeaderText
	if header and header.IsVisible and not header:IsVisible() then return false end
	if anchor.parentModule and ObjectiveTrackerFrame and ObjectiveTrackerFrame.GetTop then
		local top, bottom = anchor:GetTop(), anchor:GetBottom()
		local trackerTop, trackerBottom = ObjectiveTrackerFrame:GetTop(), ObjectiveTrackerFrame:GetBottom()
		if not (top and trackerTop) then return false end
		if top < trackerBottom or bottom > trackerTop then return false end
	end
	return true
end

local function HitsFrame(anchor, frame)
	if not frame or not frame.IsVisible or not frame:IsVisible() then return false end
	local left, right, top, bottom = anchor:GetLeft(), anchor:GetRight(), anchor:GetTop(), anchor:GetBottom()
	local otherLeft, otherRight, otherTop, otherBottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
	if not (left and otherLeft) then return false end
	return left < otherRight and right > otherLeft and bottom < otherTop and top > otherBottom
end

local function CoveredByBag(anchor)
	if not anchor or not anchor.GetLeft then return false end
	for index = 1, NUM_CONTAINER_FRAMES or 13 do
		if HitsFrame(anchor, _G["ContainerFrame" .. index]) then return true end
	end
	if HitsFrame(anchor, ContainerFrameCombinedBags) or HitsFrame(anchor, BankFrame) then return true end
	return false
end

local function IconShouldShow(icon)
	local anchor = icon.anchor
	if not icon.questID or not ShownOnScreen(anchor) then return false end
	if CoveredByBag(anchor) then return false end
	return true
end

local function OpenUrl(url)
	ShowPopup(url)
end

local function QuestID(button)
	if not button or button.isHeader then return nil end
	local index = button.questLogIndex
	if (not index or index == 0) and button.GetID then
		local id = button:GetID()
		if id and id > 0 then index = id end
	end
	if index and index > 0 and GetQuestLogTitle then
		local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(index)
		if isHeader then return nil end
		if type(questID) == "number" and questID > 0 then return questID end
	end
	if type(button.questID) == "number" and button.questID > 0 then return button.questID end
end

local function Place(icon, button)
	icon:ClearAllPoints()
	local name = button.GetName and button:GetName()
	local check = button.Check or (name and _G[name .. "Check"])
	if check then
		icon:SetPoint("RIGHT", check, "LEFT", -2, 0)
	else
		icon:SetPoint("RIGHT", button, "RIGHT", -2, 0)
	end
end

local function EnsureIcon(button)
	local icon = button.misionWowhead
	if icon then return icon end
	icon = CreateFrame("Button", nil, layer)
	icon.misionWowheadIcon = true
	icon:SetSize(12, 12)
	icon:RegisterForClicks("LeftButtonUp")
	local tex = icon:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local highlight = icon:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	highlight:SetBlendMode("ADD")
	icon:SetScript("OnClick", function(self)
		if self.questID then OpenUrl(QuestUrl(self.questID)) end
	end)
	icon:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Ver esta misión en Wowhead")
		if self.questID then
			GameTooltip:AddLine(QuestUrl(self.questID), 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	icon:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	live[#live + 1] = icon
	button.misionWowhead = icon
	return icon
end

local function Paint(button)
	if not button or button.misionWowheadIcon or not button.IsShown then return end
	local icon = button.misionWowhead
	if not button:IsShown() then
		if icon then icon:Hide() end
		return
	end
	local questID = QuestID(button)
	if not questID then
		if icon then
			icon.questID = nil
			icon:Hide()
		end
		return
	end
	icon = EnsureIcon(button)
	icon.anchor = button
	icon.questID = questID
	Place(icon, button)
	icon:SetShown(IconShouldShow(icon))
end

local TRACKERS = {
	"QuestObjectiveTracker",
	"CampaignQuestObjectiveTracker",
	"WorldQuestObjectiveTracker",
	"BonusObjectiveTracker",
}

local function EachTrackerBlock(fn)
	for index = 1, #TRACKERS do
		local module = _G[TRACKERS[index]]
		local used = module and module.usedBlocks
		if type(used) == "table" then
			for _, value in pairs(used) do
				if type(value) == "table" and not value.misionWowheadIcon then
					if value.GetObjectType then
						fn(value)
					else
						for _, block in pairs(value) do
							if type(block) == "table" and block.GetObjectType and not block.misionWowheadIcon then
								fn(block)
							end
						end
					end
				end
			end
		end
	end
end

local function TrackerQuestID(block)
	local questID = block.id or block.questID
	if type(questID) == "number" and questID > 0 then return questID end
end

local function PlaceTracker(icon, block)
	icon:ClearAllPoints()
	local header = block.HeaderText
	if header and header.GetStringWidth then
		icon:SetPoint("LEFT", header, "LEFT", (header:GetStringWidth() or 0) + 4, 0)
	else
		icon:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -2)
	end
end

local function PaintTracker(block)
	if not block or block.misionWowheadIcon or not block.IsShown then return end
	local icon = block.misionWowhead
	if not block:IsShown() then
		if icon then icon:Hide() end
		return
	end
	local questID = TrackerQuestID(block)
	if not questID then
		if icon then
			icon.questID = nil
			icon:Hide()
		end
		return
	end
	icon = EnsureIcon(block)
	icon.anchor = block
	icon.questID = questID
	PlaceTracker(icon, block)
	icon:SetShown(IconShouldShow(icon))
end

local function Refresh()
	local index = 1
	while index <= 80 do
		local button = _G["QuestLogTitle" .. index]
		if not button then break end
		Paint(button)
		index = index + 1
	end
	local contents = QuestMapFrame and QuestMapFrame.QuestsFrame and QuestMapFrame.QuestsFrame.Contents
	if contents and contents.GetChildren then
		local children = { contents:GetChildren() }
		for childIndex = 1, #children do
			local button = children[childIndex]
			if button and not button.misionWowheadIcon and (button.questLogIndex or type(button.questID) == "number") then
				Paint(button)
			end
		end
	end
	EachTrackerBlock(PaintTracker)
end

local refreshing = false

local function SafeRefresh()
	if refreshing then return end
	refreshing = true
	local ok, err = pcall(Refresh)
	refreshing = false
	if not ok then
		print("|cffffd100MisionWowhead|r: " .. tostring(err))
	end
end

local function HookUpdates()
	if type(QuestLog_Update) == "function" and not hooked.QuestLog_Update then
		hooksecurefunc("QuestLog_Update", SafeRefresh)
		hooked.QuestLog_Update = true
	end
	if type(QuestLogQuests_Update) == "function" and not hooked.QuestLogQuests_Update then
		hooksecurefunc("QuestLogQuests_Update", SafeRefresh)
		hooked.QuestLogQuests_Update = true
	end
end

local function LogOpen()
	if QuestLogFrame and QuestLogFrame.IsShown and QuestLogFrame:IsShown() then return true end
	if QuestMapFrame and QuestMapFrame.IsShown and QuestMapFrame:IsShown() then return true end
	if ObjectiveTrackerFrame and ObjectiveTrackerFrame.IsShown and ObjectiveTrackerFrame:IsShown() then return true end
	return false
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("QUEST_LOG_UPDATE")
watcher:SetScript("OnEvent", function()
	HookUpdates()
	if LogOpen() then SafeRefresh() end
end)

local elapsed = 0
watcher:SetScript("OnUpdate", function(_, delta)
	elapsed = elapsed + delta
	if elapsed < 0.2 then return end
	elapsed = 0
	for index = 1, #live do
		local icon = live[index]
		local show = IconShouldShow(icon)
		if icon:IsShown() ~= show then
			icon:SetShown(show)
		end
	end
end)
