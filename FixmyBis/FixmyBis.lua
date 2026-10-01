-- Ventana con la lista BiS de la clase y la facción del personaje.
-- El tooltip es el del cliente: al pasar el ratón se ven las estadísticas reales del objeto.

local PORTRAIT = "Interface\\Icons\\INV_Chest_Chain"

local SLOT_ORDER = {
	"head", "neck", "shoulder", "back", "chest", "wrist", "hands", "waist",
	"legs", "feet", "finger", "trinket", "main-hand", "off-hand", "two-hand",
	"shield", "ranged", "relic",
}

local SLOT_NAME = {
	head = "Cabeza",
	neck = "Cuello",
	shoulder = "Hombros",
	back = "Espalda",
	chest = "Pecho",
	wrist = "Muñecas",
	hands = "Manos",
	waist = "Cintura",
	legs = "Piernas",
	feet = "Pies",
	finger = "Anillos",
	trinket = "Abalorios",
	["main-hand"] = "Mano principal",
	["off-hand"] = "Mano izquierda",
	["two-hand"] = "Dos manos",
	shield = "Escudo",
	ranged = "A distancia",
	relic = "Reliquia",
}

local SPEC_NAME = {
	balance = "Equilibrio",
	feral = "Feral",
	restoration = "Restauración",
	tank = "Tanque",
	elemental = "Elemental",
	enhancement = "Mejora",
	holy = "Sagrado",
	retribution = "Reprensión",
	shockadin = "Shockadin",
	shadow = "Sombras",
	discipline = "Disciplina",
	pve = "JcE",
	pvp = "JcJ",
}

-- Orden de las pestañas de talentos en clásico. Armas y furia comparten la lista JcE.
local TALENT_SPEC = {
	shaman = { "elemental", "enhancement", "restoration" },
	druid = { "balance", "feral", "restoration" },
	paladin = { "holy", "tank", "retribution" },
	priest = { "discipline", "holy", "shadow" },
	warrior = { "pve", "pve", "tank" },
}

local state = { level = 30, spec = nil, mode = "pve", ready = false }
local openSlots = {}
local frame, tab
local scroll, content
local infoText, emptyText
local levelButtons, specButtons = {}, {}
local rows, headers = {}, {}
local usedRows, usedHeaders = 0, 0

local function ClassToken()
	local _, token = UnitClass("player")
	return token and token:lower() or nil
end

local function FactionToken()
	local token = UnitFactionGroup("player")
	if token == "Horde" then return "horde" end
	if token == "Alliance" then return "alliance" end
	return nil
end

local function ListsFor(level, class)
	local out = {}
	if not FixmyBisData or not FixmyBisData.lists or not class then return out end
	for _, list in ipairs(FixmyBisData.lists) do
		if list.level == level and list.class == class then
			out[#out + 1] = list
		end
	end
	return out
end

local function IsRealSpec(spec)
	return spec and spec ~= "pve" and spec ~= "pvp"
end

local function RealSpecs(lists)
	local out, seen = {}, {}
	for _, list in ipairs(lists) do
		if IsRealSpec(list.spec) and not seen[list.spec] then
			seen[list.spec] = true
			out[#out + 1] = list.spec
		end
	end
	return out
end

local function GuessSpec(class)
	local map = TALENT_SPEC[class]
	if not map or not GetNumTalentTabs or not GetTalentTabInfo then return nil end
	local bestIndex, bestPoints = nil, 0
	for index = 1, GetNumTalentTabs() do
		local _, _, spent = GetTalentTabInfo(index)
		spent = tonumber(spent) or 0
		if spent > bestPoints then
			bestPoints = spent
			bestIndex = index
		end
	end
	if bestIndex and bestPoints > 0 then
		return map[bestIndex]
	end
end

local function HasList(lists, spec, mode)
	for _, list in ipairs(lists) do
		if list.mode == mode and ((not spec and not IsRealSpec(list.spec)) or list.spec == spec) then
			return true
		end
	end
	return false
end

local function Resolve()
	local lists = ListsFor(state.level, state.class)
	local specs = RealSpecs(lists)
	if #specs == 0 then
		state.spec = nil
	else
		local found = false
		for _, spec in ipairs(specs) do
			if spec == state.spec then found = true end
		end
		if not found then state.spec = specs[1] end
	end
	if HasList(lists, state.spec, state.mode) then return end
	if HasList(lists, state.spec, "pve") then
		state.mode = "pve"
	elseif HasList(lists, state.spec, "pvp") then
		state.mode = "pvp"
	elseif lists[1] then
		state.spec = IsRealSpec(lists[1].spec) and lists[1].spec or nil
		state.mode = lists[1].mode
	end
end

local function EnsureState()
	state.class = ClassToken()
	state.faction = FactionToken()
	if not state.ready then
		state.ready = true
		local level = UnitLevel("player") or 30
		state.level = level <= 20 and 20 or 30
		state.mode = "pve"
		state.spec = GuessSpec(state.class)
	end
	Resolve()
end

local function CurrentList()
	for _, list in ipairs(ListsFor(state.level, state.class)) do
		if list.mode == state.mode then
			if state.spec and list.spec == state.spec then return list end
			if not state.spec and not IsRealSpec(list.spec) then return list end
		end
	end
end

local function ItemVisual(itemID)
	local name, _, quality, _, _, _, _, _, _, texture
	if C_Item and C_Item.GetItemInfo then
		name, _, quality, _, _, _, _, _, _, texture = C_Item.GetItemInfo(itemID)
	end
	if not name and GetItemInfo then
		name, _, quality, _, _, _, _, _, _, texture = GetItemInfo(itemID)
	end
	if not name and C_Item and C_Item.RequestLoadItemDataByID then
		C_Item.RequestLoadItemDataByID(itemID)
	end
	return name, texture, quality
end

local function IsBest(list, slot, itemID)
	local picks = state.faction and list.best and list.best[state.faction]
	if not picks then return false end
	if picks[slot] == itemID then return true end
	local index = 2
	while picks[slot .. "-" .. index] do
		if picks[slot .. "-" .. index] == itemID then return true end
		index = index + 1
	end
	return false
end

local function ItemLink(itemID)
	local link
	if C_Item and C_Item.GetItemInfo then
		_, link = C_Item.GetItemInfo(itemID)
	end
	if not link and GetItemInfo then
		_, link = GetItemInfo(itemID)
	end
	return link or ("item:" .. itemID)
end

local function WantDress()
	if IsControlKeyDown and IsControlKeyDown() then return true end
	if IsModifiedClick and IsModifiedClick("DRESSUP") then return true end
	return false
end

local function DressItem(itemID)
	if not itemID then return end
	if C_AddOns and C_AddOns.LoadAddOn then
		C_AddOns.LoadAddOn("Blizzard_DressUpUI")
	elseif LoadAddOn then
		LoadAddOn("Blizzard_DressUpUI")
	end
	if not DressUpItemLink then
		print("|cffffd100FixmyBis|r: este cliente no abre el probador desde un addon.")
		return
	end
	local dressed = DressUpItemLink(ItemLink(itemID))
	if dressed == false then
		print("|cffffd100FixmyBis|r: este objeto no se puede probar.")
	end
end

local function ShowItemTip(owner, itemID, source, best)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	if GameTooltip.SetItemByID then
		GameTooltip:SetItemByID(itemID)
	else
		GameTooltip:SetHyperlink("item:" .. itemID)
	end
	if source and source ~= "" then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(source, 0.9, 0.85, 0.6, true)
	end
	if best then
		GameTooltip:AddLine("Primera pieza de este hueco para tu facción.", 1, 0.82, 0, true)
	end
	GameTooltip:AddLine("Ctrl-clic: verlo en el probador.", 0.6, 0.8, 1, true)
	GameTooltip:Show()
end

local function AcquireRow()
	usedRows = usedRows + 1
	local row = rows[usedRows]
	if row then return row end
	row = CreateFrame("Button", nil, content)
	row:SetHeight(40)
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(32, 32)
	row.icon:SetPoint("LEFT", 2, 0)
	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -3)
	row.name:SetPoint("RIGHT", row, "RIGHT", -40, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.source = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.source:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 3)
	row.source:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.source:SetJustifyH("LEFT")
	row.source:SetWordWrap(false)
	row.mark = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.mark:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
	row.mark:SetText("BiS")
	row:SetScript("OnEnter", function(self)
		ShowItemTip(self, self.itemID, self.sourceText, self.isBest)
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row:SetScript("OnClick", function(self)
		if WantDress() then
			DressItem(self.itemID)
		end
	end)
	rows[usedRows] = row
	return row
end

local FillList

local function PaintToggle(button, opened)
	local kind = opened and "Minus" or "Plus"
	button:SetNormalTexture("Interface\\Buttons\\UI-" .. kind .. "Button-UP")
	button:SetPushedTexture("Interface\\Buttons\\UI-" .. kind .. "Button-DOWN")
	button:SetHighlightTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Hilight")
	local highlight = button:GetHighlightTexture()
	if highlight then highlight:SetBlendMode("ADD") end
end

local function ToggleSlot(slot)
	openSlots[slot] = not openSlots[slot]
	FillList()
end

local function AcquireHeader()
	usedHeaders = usedHeaders + 1
	local header = headers[usedHeaders]
	if header then return header end
	header = CreateFrame("Button", nil, content)
	header:SetHeight(28)
	header:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	header.plus = CreateFrame("Button", nil, header)
	header.plus:SetSize(18, 18)
	header.plus:SetPoint("LEFT", 2, 0)
	header.plus:SetScript("OnClick", function(self)
		ToggleSlot(self:GetParent().slot)
	end)
	header.plus:SetScript("OnEnter", function(self)
		local parent = self:GetParent()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(openSlots[parent.slot] and "Cerrar" or "Abrir")
		GameTooltip:AddLine(parent.title and parent.title:GetText() or "", 1, 1, 1)
		GameTooltip:Show()
	end)
	header.plus:SetScript("OnLeave", GameTooltip_Hide)
	header.title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	header.title:SetPoint("LEFT", header.plus, "RIGHT", 6, 0)
	header.title:SetJustifyH("LEFT")
	header.title:SetWordWrap(false)
	header.icon = header:CreateTexture(nil, "ARTWORK")
	header.icon:SetSize(18, 18)
	header.icon:SetPoint("RIGHT", header, "RIGHT", -6, 0)
	header.bestName = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	header.bestName:SetPoint("RIGHT", header.icon, "LEFT", -6, 0)
	header.bestName:SetWidth(180)
	header.bestName:SetJustifyH("RIGHT")
	header.bestName:SetWordWrap(false)
	header.title:SetPoint("RIGHT", header.bestName, "LEFT", -8, 0)
	header:SetScript("OnClick", function(self)
		if self.itemID and WantDress() then
			DressItem(self.itemID)
			return
		end
		ToggleSlot(self.slot)
	end)
	header:SetScript("OnEnter", function(self)
		if self.itemID and not openSlots[self.slot] then
			ShowItemTip(self, self.itemID, self.sourceText, true)
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(openSlots[self.slot] and "Cerrar" or "Abrir")
			GameTooltip:AddLine(self.title:GetText() or "", 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	header:SetScript("OnLeave", GameTooltip_Hide)
	headers[usedHeaders] = header
	return header
end

local function HideUnused()
	for index = usedRows + 1, #rows do rows[index]:Hide() end
	for index = usedHeaders + 1, #headers do headers[index]:Hide() end
end

local function PaintButton(button, selected)
	if not button then return end
	if selected then
		button:SetText("|cffffd100" .. button.label .. "|r")
	else
		button:SetText(button.label)
	end
end

local function ListLabel(list)
	if list.spec == "pve" then return "JcE" end
	if list.spec == "pvp" then return "JcJ" end
	local spec = SPEC_NAME[list.spec] or list.spec
	if list.mode == "pvp" then return spec .. " JcJ" end
	return spec
end

local function PlaceFilters()
	local lists = ListsFor(state.level, state.class)
	local x = 16
	for _, button in ipairs(levelButtons) do
		PaintButton(button, button.level == state.level)
		button:ClearAllPoints()
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -92)
		x = x + button:GetWidth() + 6
	end

	local shown = 0
	for index, list in ipairs(lists) do
		local button = specButtons[index]
		if button then
			button.label = ListLabel(list)
			button.spec = list.spec
			button.mode = list.mode
			local selected = list.mode == state.mode and ((not state.spec and not IsRealSpec(list.spec)) or list.spec == state.spec)
			PaintButton(button, selected)
			local col = (index - 1) % 4
			local row = math.floor((index - 1) / 4)
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + col * 116, -118 - row * 24)
			button:Show()
			shown = index
		end
	end
	for index = shown + 1, #specButtons do
		specButtons[index]:Hide()
	end
	if shown == 0 then return 0 end
	return math.ceil(shown / 4)
end

function FillList()
	usedRows, usedHeaders = 0, 0
	local list = CurrentList()
	local width = scroll:GetWidth()
	if not width or width < 40 then width = 430 end
	content:SetWidth(width)
	if not list then
		emptyText:Show()
		emptyText:SetText("No hay lista para esta clase, nivel y especialización.")
		content:SetHeight(1)
		HideUnused()
		return
	end
	emptyText:Hide()
	local y = -4
	local faction = state.faction
	local any = false
	for _, slot in ipairs(SLOT_ORDER) do
		local items = list.slots and list.slots[slot]
		if items then
			local visible = {}
			for _, item in ipairs(items) do
				if not faction or item.faction == "both" or item.faction == faction then
					visible[#visible + 1] = item
				end
			end
			if #visible > 0 then
				any = true
				local bestItem
				for _, item in ipairs(visible) do
					if IsBest(list, slot, item.id) then
						bestItem = item
						break
					end
				end
				bestItem = bestItem or visible[1]
				local opened = openSlots[slot] and true or false
				local header = AcquireHeader()
				header.slot = slot
				header:SetWidth(width - 4)
				header:ClearAllPoints()
				header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
				header.title:SetText(SLOT_NAME[slot] or slot)
				PaintToggle(header.plus, opened)
				if opened then
					header.itemID = nil
					header.icon:Hide()
					header.bestName:Hide()
				else
					header.itemID = bestItem.id
					header.sourceText = bestItem.source or ""
					local name, texture, quality = ItemVisual(bestItem.id)
					header.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
					header.icon:Show()
					local r, g, b = 1, 1, 1
					if GetItemQualityColor then
						r, g, b = GetItemQualityColor(quality or bestItem.quality or 1)
					end
					header.bestName:SetText(name or bestItem.name)
					header.bestName:SetTextColor(r, g, b)
					header.bestName:Show()
				end
				header:Show()
				y = y - 30
				if opened then
				for _, item in ipairs(visible) do
					local row = AcquireRow()
					row:SetWidth(width - 22)
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
					row.itemID = item.id
					row.sourceText = item.source or ""
					row.isBest = IsBest(list, slot, item.id)
					row.source:SetText(row.sourceText)
					row.mark:SetShown(row.isBest)
					local name, texture, quality = ItemVisual(item.id)
					row.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark")
					local r, g, b = 1, 1, 1
					if GetItemQualityColor then
						r, g, b = GetItemQualityColor(quality or item.quality or 1)
					end
					row.name:SetText(name or item.name)
					row.name:SetTextColor(r, g, b)
					row:Show()
					y = y - 42
				end
				end
				y = y - 4
			end
		end
	end
	if not any then
		emptyText:Show()
		emptyText:SetText("Esta lista no tiene piezas para tu facción.")
	end
	content:SetHeight(math.max(8, -y))
	HideUnused()
end

local function WhoText()
	local className = UnitClass("player") or "Personaje"
	local _, factionName = UnitFactionGroup("player")
	if not factionName or factionName == "" then
		factionName = state.faction == "horde" and "Horda" or state.faction == "alliance" and "Alianza" or "Sin facción"
	end
	local spec = state.spec and (SPEC_NAME[state.spec] or state.spec) or nil
	local mode = state.mode == "pvp" and "JcJ" or "JcE"
	local bits = className .. " · " .. factionName .. " · nivel " .. state.level .. " · " .. mode
	if spec then bits = bits .. " · " .. spec end
	return bits
end

local function Refresh()
	if not frame then return end
	EnsureState()
	infoText:SetText(WhoText())
	local specRows = PlaceFilters()
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -126 - specRows * 24)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 48)
	FillList()
end

local function Choose(kind, value)
	if kind == "level" then state.level = value end
	if kind == "spec" then state.spec = value.spec state.mode = value.mode end
	if kind == "mode" then state.mode = value end
	state.ready = true
	if scroll then scroll:SetVerticalScroll(0) end
	Refresh()
end

local function MakeChoice(parent, label, width, kind, value)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 22)
	button.label = label
	button:SetText(label)
	button:SetScript("OnClick", function()
		Choose(kind, value)
	end)
	return button
end

local function SyncTab()
	if tab then tab:SetChecked(frame and frame:IsShown() or false) end
end

local function Show()
	if not frame then return end
	Refresh()
	frame:Show()
	SyncTab()
end

local function Toggle()
	if not frame then return end
	if frame:IsShown() then
		frame:Hide()
	else
		Show()
	end
	SyncTab()
end

local function BuildFrame()
	if frame then return end
	local ok, created = pcall(CreateFrame, "Frame", "FixmyBisFrame", UIParent, "PortraitFrameTemplate")
	if ok then
		frame = created
	else
		frame = CreateFrame("Frame", "FixmyBisFrame", UIParent, "BackdropTemplate")
		frame:SetBackdrop({
			bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
			tile = true, tileSize = 256, edgeSize = 32,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})
	end
	frame:SetSize(480, 560)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:Hide()
	tinsert(UISpecialFrames, "FixmyBisFrame")
	local titled = false
	if frame.SetTitle then
		titled = pcall(frame.SetTitle, frame, "FixmyBis")
	end
	if not titled and frame.TitleText then
		frame.TitleText:SetText("FixmyBis")
		titled = true
	end
	local portraitSet = false
	if frame.SetPortraitToAsset then
		portraitSet = pcall(frame.SetPortraitToAsset, frame, PORTRAIT)
	end
	if not portraitSet then
		local portrait = frame.portrait or (frame.PortraitContainer and frame.PortraitContainer.portrait)
		if portrait and SetPortraitToTexture then
			SetPortraitToTexture(portrait, PORTRAIT)
		end
	end
	if not titled then
		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", 0, -8)
		title:SetText("FixmyBis")
	end
	if not frame.CloseButton then
		local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		closeButton:SetPoint("TOPRIGHT", -2, -2)
		closeButton:SetScript("OnClick", function() frame:Hide() end)
		frame.CloseButton = closeButton
	end
	frame.CloseButton:HookScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText("Cerrar")
		GameTooltip:AddLine("Cierra FixmyBis. También vale Escape.", 1, 1, 1)
		GameTooltip:Show()
	end)
	frame.CloseButton:HookScript("OnLeave", GameTooltip_Hide)

	local drag = CreateFrame("Frame", nil, frame)
	drag:SetPoint("TOPLEFT", 62, -1)
	drag:SetPoint("TOPRIGHT", -36, -1)
	drag:SetHeight(30)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function() frame:StartMoving() end)
	drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

	infoText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	infoText:SetPoint("TOPLEFT", 24, -68)
	infoText:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
	infoText:SetJustifyH("LEFT")
	infoText:SetWordWrap(false)

	levelButtons[1] = MakeChoice(frame, "Nivel 20", 78, "level", 20)
	levelButtons[1].level = 20
	levelButtons[2] = MakeChoice(frame, "Nivel 30", 78, "level", 30)
	levelButtons[2].level = 30
	for index = 1, 8 do
		specButtons[index] = MakeChoice(frame, "", 110, "spec", nil)
		specButtons[index]:Hide()
		specButtons[index]:SetScript("OnClick", function(self)
			Choose("spec", { spec = IsRealSpec(self.spec) and self.spec or nil, mode = self.mode })
		end)
	end

	scroll = CreateFrame("ScrollFrame", "FixmyBisScroll", frame, "UIPanelScrollFrameTemplate")
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(430, 1)
	scroll:SetScrollChild(content)
	emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	emptyText:SetPoint("TOPLEFT", 8, -8)
	emptyText:SetWidth(400)
	emptyText:SetJustifyH("LEFT")
	emptyText:Hide()

	local insetOk, listInset = pcall(CreateFrame, "Frame", nil, frame, "InsetFrameTemplate")
	if insetOk and listInset then
		listInset:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 4)
		listInset:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 26, -6)
		listInset:SetFrameLevel(math.max(frame:GetFrameLevel(), 1))
		scroll:SetFrameLevel(listInset:GetFrameLevel() + 2)
	end

	local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("BOTTOMLEFT", 24, 12)
	statusText:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(true)
	statusText:SetHeight(32)
	statusText:SetText("El + abre las alternativas. Ctrl-clic en un objeto lo pone en el probador.")

	frame:SetScript("OnShow", Refresh)
	frame:SetScript("OnHide", function()
		if GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
		SyncTab()
	end)
end

local function PlaceTab()
	if not tab or not CharacterFrame or not CharacterFrame.ModeTabs then return end
	local last
	for _, other in ipairs(CharacterFrame.ModeTabs.Tabs or {}) do
		if other:IsShown() then last = other end
	end
	tab:ClearAllPoints()
	if last then
		tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
	else
		tab:SetPoint("TOPLEFT", CharacterFrame.ModeTabs, "TOPLEFT")
	end
	SyncTab()
end

local function OnTabClick(_, button, upInside)
	if button ~= "LeftButton" or upInside == false then return end
	Toggle()
end

local function BuildTab()
	if tab or not CharacterFrame or not CharacterFrame.ModeTabs then return end
	tab = CreateFrame("Frame", "FixmyBisCharacterTab", CharacterFrame.ModeTabs, "LargeSideTabButtonTemplate")
	tab.tooltipText = "FixmyBis"
	if tab.Icon then tab.Icon:SetTexture(PORTRAIT) end
	if tab.SetFillToInterior then tab:SetFillToInterior(true) end
	tab:SetChecked(false)
	if tab.SetCustomOnMouseUpHandler then
		tab:SetCustomOnMouseUpHandler(OnTabClick)
	else
		tab:SetScript("OnClick", function() OnTabClick(nil, "LeftButton", true) end)
	end
	PlaceTab()
	if CharacterFrame.UpdateTabLayout then
		hooksecurefunc(CharacterFrame, "UpdateTabLayout", PlaceTab)
	end
	CharacterFrame:HookScript("OnShow", PlaceTab)
end

local function EnsureDB()
	if type(FixmyBisDB) ~= "table" then
		FixmyBisDB = {}
	end
end

local function PlaceMinimapButton(button, angle)
	local radius = Minimap:GetWidth() / 2
	if not radius or radius < 20 then
		radius = 80
	end
	local rad = math.rad(angle)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function EnsureMinimapButton()
	if _G.FixmyBisMinimapButton or not Minimap then return end
	EnsureDB()
	local button = CreateFrame("Button", "FixmyBisMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 12)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetTexture(PORTRAIT)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("CENTER", 1, 0)

	local angle = tonumber(FixmyBisDB.minimapAngle) or 160
	PlaceMinimapButton(button, angle)

	local downX, downY
	button:SetScript("OnMouseDown", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			downX, downY = GetCursorPosition()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local cx, cy = GetCursorPosition()
			if downX and cx and ((cx - downX) ^ 2 + (cy - downY) ^ 2) < 64 then
				return
			end
			local mx, my = Minimap:GetCenter()
			local scale = Minimap:GetEffectiveScale()
			if scale and scale > 0 then
				cx, cy = cx / scale, cy / scale
			end
			if not mx or not my or not cx or not cy then return end
			local nextAngle = math.deg(math.atan2(cy - my, cx - mx))
			FixmyBisDB.minimapAngle = nextAngle
			PlaceMinimapButton(self, nextAngle)
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnClick", function()
		local cx, cy = GetCursorPosition()
		if downX and cx and ((cx - downX) ^ 2 + (cy - downY) ^ 2) >= 64 then
			return
		end
		Toggle()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("FixmyBis")
		GameTooltip:AddLine("Clic para abrir", 1, 1, 1)
		GameTooltip:AddLine("Arrastra por el borde para moverlo", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
end

SLASH_FIXMYBIS1 = "/fixmybis"
SLASH_FIXMYBIS2 = "/bis"
SlashCmdList.FIXMYBIS = Toggle

local polishPending = false
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
watcher:SetScript("OnEvent", function(_, event, arg1)
	if event == "GET_ITEM_INFO_RECEIVED" then
		if not frame or not frame:IsShown() or polishPending then return end
		polishPending = true
		C_Timer.After(0.15, function()
			polishPending = false
			if frame and frame:IsShown() then FillList() end
		end)
		return
	end
	if event == "ADDON_LOADED" and arg1 ~= "FixmyBis" then return end
	BuildFrame()
	BuildTab()
	EnsureMinimapButton()
end)
