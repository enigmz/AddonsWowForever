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

local CLASS_ICON = "Interface\\TargetingFrame\\UI-Classes-Circles"
local CLASS_COORDS = {
	warrior = { 0, 0.25, 0, 0.25 },
	mage = { 0.25, 0.49609375, 0, 0.25 },
	rogue = { 0.49609375, 0.7421875, 0, 0.25 },
	druid = { 0.7421875, 0.98828125, 0, 0.25 },
	hunter = { 0, 0.25, 0.25, 0.5 },
	shaman = { 0.25, 0.49609375, 0.25, 0.5 },
	priest = { 0.49609375, 0.7421875, 0.25, 0.5 },
	warlock = { 0.7421875, 0.98828125, 0.25, 0.5 },
	paladin = { 0, 0.25, 0.5, 0.75 },
}

local CLASS_ORDER = {
	"warrior", "paladin", "hunter", "rogue", "priest",
	"shaman", "mage", "warlock", "druid",
}

local CLASS_NAME = {
	warrior = "Guerrero",
	paladin = "Paladín",
	hunter = "Cazador",
	rogue = "Pícaro",
	priest = "Sacerdote",
	shaman = "Chamán",
	mage = "Mago",
	warlock = "Brujo",
	druid = "Druida",
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
local levelDrop
local specButtons = {}
local classButtons = {}
local rows, headers, notes = {}, {}, {}
local usedRows, usedHeaders, usedNotes = 0, 0, 0

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
	state.faction = FactionToken()
	if not state.ready then
		state.ready = true
		state.class = ClassToken()
		local level = UnitLevel("player") or 30
		state.level = level <= 20 and 20 or 30
		state.mode = "pve"
		state.spec = GuessSpec(state.class)
	end
	if not state.class then
		state.class = ClassToken()
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

local function ChatBox()
	if ChatEdit_GetActiveWindow then
		local box = ChatEdit_GetActiveWindow()
		if box and box.IsShown and box:IsShown() then return box end
	end
	if ChatFrameUtil and ChatFrameUtil.GetActiveWindow then
		local box = ChatFrameUtil.GetActiveWindow()
		if box and box.IsShown and box:IsShown() then return box end
	end
	if ChatFrame1EditBox and ChatFrame1EditBox.IsShown and ChatFrame1EditBox:IsShown() then
		return ChatFrame1EditBox
	end
end

local function PasteItem(itemID)
	if not itemID then return false end
	local shift = (IsModifiedClick and IsModifiedClick("CHATLINK")) or (IsShiftKeyDown and IsShiftKeyDown())
	if not shift then return false end
	local box = ChatBox()
	if not box then return false end
	local link = ItemLink(itemID)
	if link and not link:find("|H", 1, true) then
		local name
		if C_Item and C_Item.GetItemInfo then
			name = C_Item.GetItemInfo(itemID)
		elseif GetItemInfo then
			name = GetItemInfo(itemID)
		end
		link = "|cffffffff|Hitem:" .. itemID .. "::::::::|h[" .. (name or "objeto") .. "]|h|r"
	end
	if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return true end
	if ChatFrameUtil and ChatFrameUtil.InsertLink and ChatFrameUtil.InsertLink(link) then return true end
	if box.Insert then
		box:Insert(link)
		return true
	end
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

local function ShowItemTip(owner, itemID, source, best, extra)
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
	elseif extra then
		GameTooltip:AddLine("Alternativa de mazmorra o misión. Va detrás de la lista principal.", 0.75, 0.75, 0.75, true)
	end
	GameTooltip:AddLine("Ctrl-clic: verlo en el probador. Mayús-clic con el chat abierto: enlazarlo.", 0.6, 0.8, 1, true)
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
		ShowItemTip(self, self.itemID, self.sourceText, self.isBest, self.isExtra)
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row:SetScript("OnClick", function(self)
		if PasteItem(self.itemID) then return end
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
		if self.itemID and PasteItem(self.itemID) then return end
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

local function AcquireNote()
	usedNotes = usedNotes + 1
	local note = notes[usedNotes]
	if note then return note end
	note = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	note:SetJustifyH("LEFT")
	notes[usedNotes] = note
	return note
end

local function HideUnused()
	for index = usedRows + 1, #rows do rows[index]:Hide() end
	for index = usedHeaders + 1, #headers do headers[index]:Hide() end
	for index = usedNotes + 1, #notes do notes[index]:Hide() end
end

local function PaintClassButton(button, selected)
	if not button then return end
	if selected then
		button.icon:SetVertexColor(1, 1, 1)
		button.ring:Show()
	else
		button.icon:SetVertexColor(0.45, 0.45, 0.45)
		button.ring:Hide()
	end
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

local function FlipRegion(region)
	if not region or not region.GetTexCoord or not region.SetTexCoord then return end
	if not region.fixmyBisBase then
		local coords = { region:GetTexCoord() }
		if #coords < 4 then return end
		region.fixmyBisBase = coords
	end
	local coords = region.fixmyBisBase
	if #coords >= 8 then
		region:SetTexCoord(coords[3], coords[4], coords[1], coords[2], coords[7], coords[8], coords[5], coords[6])
	else
		region:SetTexCoord(coords[1], coords[2], coords[4], coords[3])
	end
end

local function FlipTab(button)
	if not button or not button.GetName then return end
	local name = button:GetName()
	for _, part in ipairs({
		"Left", "Middle", "Right",
		"LeftDisabled", "MiddleDisabled", "RightDisabled",
		"LeftActive", "MiddleActive", "RightActive",
	}) do
		FlipRegion(button[part])
		if name then FlipRegion(_G[name .. part]) end
	end
	if button.GetHighlightTexture then
		FlipRegion(button:GetHighlightTexture())
	end
	if button.GetRegions then
		for _, region in ipairs({ button:GetRegions() }) do
			if region.GetObjectType and region:GetObjectType() == "Texture" then
				FlipRegion(region)
			end
		end
	end
end

local function PlaceTabText(button, width)
	local fontString = button.GetFontString and button:GetFontString()
	if not fontString then return end
	fontString:SetWordWrap(false)
	fontString:SetJustifyH("CENTER")
	fontString:SetJustifyV("MIDDLE")
	fontString:ClearAllPoints()
	fontString:SetPoint("CENTER", button, "CENTER", 0, -6)
	fontString:SetWidth(math.max(20, (width or button:GetWidth()) - 28))
end

local function SizeSpecTab(button, width)
	button:SetWidth(width)
	if PanelTemplates_TabResize then
		pcall(PanelTemplates_TabResize, button, 0, width)
	end
	FlipTab(button)
	PlaceTabText(button, width)
end

local function PlaceFilters()
	for _, button in ipairs(classButtons) do
		PaintClassButton(button, button.classToken == state.class)
	end
	if levelDrop and levelDrop.kind == "menu" and UIDropDownMenu_SetText then
		pcall(UIDropDownMenu_SetText, levelDrop, "Nivel " .. state.level)
	elseif levelDrop then
		levelDrop:SetText("Nivel " .. state.level)
	end
	local lists = ListsFor(state.level, state.class)
	local shown = math.min(#lists, #specButtons)
	local gap = -14
	local widths, span = {}, 0
	for index = 1, shown do
		local button = specButtons[index]
		local label = ListLabel(lists[index])
		button:SetText(label)
		local textWidth = (button.GetTextWidth and button:GetTextWidth()) or 0
		if textWidth < 8 then
			local chars = strlenutf8 and strlenutf8(label) or #label
			textWidth = chars * 7
		end
		widths[index] = math.max(78, textWidth + 36)
		span = span + widths[index]
	end
	if shown > 1 then
		span = span + gap * (shown - 1)
	end
	local available = frame:GetWidth() - 32
	if span > available and span > 0 then
		local scale = available / span
		span = 0
		for index = 1, shown do
			widths[index] = math.max(64, widths[index] * scale)
			span = span + widths[index]
		end
		if shown > 1 then
			span = span + gap * (shown - 1)
		end
		if span > available and shown > 1 then
			gap = gap - ((span - available) / (shown - 1))
		end
	end
	for index = 1, shown do
		local list = lists[index]
		local button = specButtons[index]
		button.label = ListLabel(list)
		button.spec = list.spec
		button.mode = list.mode
		SizeSpecTab(button, widths[index])
		local selected = list.mode == state.mode and ((not state.spec and not IsRealSpec(list.spec)) or list.spec == state.spec)
		if selected and PanelTemplates_SelectTab then
			pcall(PanelTemplates_SelectTab, button)
		elseif PanelTemplates_DeselectTab then
			pcall(PanelTemplates_DeselectTab, button)
		else
			PaintButton(button, selected)
		end
		FlipTab(button)
		PlaceTabText(button, widths[index])
		button:SetFrameLevel(frame:GetFrameLevel() + (selected and 6 or 3))
		button:ClearAllPoints()
		if index == 1 then
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -170)
		else
			button:SetPoint("LEFT", specButtons[index - 1], "RIGHT", gap, 0)
		end
		button:Show()
	end
	for index = shown + 1, #specButtons do
		specButtons[index]:Hide()
	end
end

function FillList()
	usedRows, usedHeaders, usedNotes = 0, 0, 0
	local list = CurrentList()
	local width = scroll:GetWidth()
	if not width or width < 40 then width = 760 end
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
				local noted = false
				for _, item in ipairs(visible) do
					if item.extra and not noted then
						local note = AcquireNote()
						note:ClearAllPoints()
						note:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
						note:SetWidth(width - 22)
						note:SetText("Otras piezas de mazmorra y misión")
						note:Show()
						y = y - 16
						noted = true
					end
					local row = AcquireRow()
					row:SetWidth(width - 22)
					row:ClearAllPoints()
					row:SetPoint("TOPLEFT", content, "TOPLEFT", 18, y)
					row.itemID = item.id
					row.sourceText = item.source or ""
					row.isBest = IsBest(list, slot, item.id)
					row.isExtra = item.extra and true or false
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
	local className = CLASS_NAME[state.class] or UnitClass("player") or "Personaje"
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
	PlaceFilters()
	FillList()
end

local function Choose(kind, value)
	if kind == "level" then state.level = value end
	if kind == "class" and state.class ~= value then
		state.class = value
		state.spec = value == ClassToken() and GuessSpec(value) or nil
		state.mode = "pve"
	end
	if kind == "spec" then state.spec = value.spec state.mode = value.mode end
	if kind == "mode" then state.mode = value end
	state.ready = true
	if scroll then scroll:SetVerticalScroll(0) end
	Refresh()
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
	frame:SetSize(840, 680)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:SetResizable(true)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(560, 480, 1800, 1400)
	else
		frame:SetMinResize(560, 480)
		frame:SetMaxResize(1800, 1400)
	end
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
	infoText:SetPoint("TOPLEFT", 24, -140)
	infoText:SetPoint("RIGHT", frame, "RIGHT", -190, 0)
	infoText:SetJustifyH("LEFT")
	infoText:SetWordWrap(false)

	local dropOk, drop = pcall(CreateFrame, "Frame", "FixmyBisLevelDrop", frame, "UIDropDownMenuTemplate")
	local menuReady = false
	if dropOk and drop and UIDropDownMenu_Initialize and UIDropDownMenu_CreateInfo then
		levelDrop = drop
		levelDrop.kind = "menu"
		menuReady = pcall(function()
			UIDropDownMenu_SetWidth(levelDrop, 100)
			UIDropDownMenu_Initialize(levelDrop, function()
				local levels, seen = {}, {}
				if FixmyBisData and FixmyBisData.lists then
					for _, list in ipairs(FixmyBisData.lists) do
						if list.class == state.class and not seen[list.level] then
							seen[list.level] = true
							levels[#levels + 1] = list.level
						end
					end
				end
				if #levels == 0 then
					levels[1], levels[2] = 20, 30
				end
				table.sort(levels)
				for _, value in ipairs(levels) do
					local info = UIDropDownMenu_CreateInfo()
					info.text = "Nivel " .. value
					info.arg1 = value
					info.checked = state.level == value
					info.func = function(_, picked)
						Choose("level", picked)
					end
					UIDropDownMenu_AddButton(info)
				end
			end)
			UIDropDownMenu_SetText(levelDrop, "Nivel " .. (state.level or 30))
			levelDrop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -130)
		end)
	end
	if not menuReady then
		if drop and drop.Hide then drop:Hide() end
		levelDrop = CreateFrame("Button", "FixmyBisLevelButton", frame, "UIPanelButtonTemplate")
		levelDrop.kind = "button"
		levelDrop:SetSize(110, 22)
		levelDrop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -136)
		levelDrop:SetText("Nivel " .. (state.level or 30))
		levelDrop:SetScript("OnClick", function()
			local levels, seen = {}, {}
			if FixmyBisData and FixmyBisData.lists then
				for _, list in ipairs(FixmyBisData.lists) do
					if list.class == state.class and not seen[list.level] then
						seen[list.level] = true
						levels[#levels + 1] = list.level
					end
				end
			end
			if #levels == 0 then
				levels[1], levels[2] = 20, 30
			end
			table.sort(levels)
			local nextLevel = levels[1]
			for index, value in ipairs(levels) do
				if value == state.level then
					nextLevel = levels[index + 1] or levels[1]
				end
			end
			Choose("level", nextLevel)
		end)
	end
	local classGap = 6
	local classSize = 28
	for index, token in ipairs(CLASS_ORDER) do
		local button = CreateFrame("Button", nil, frame)
		button:SetSize(classSize, classSize)
		button.classToken = token
		button.label = CLASS_NAME[token] or token
		local coords = CLASS_COORDS[token]
		button.icon = button:CreateTexture(nil, "ARTWORK")
		button.icon:SetAllPoints()
		button.icon:SetTexture(CLASS_ICON)
		if coords then
			button.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
		end
		button.ring = button:CreateTexture(nil, "OVERLAY")
		button.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
		button.ring:SetBlendMode("ADD")
		button.ring:SetSize(50, 50)
		button.ring:SetPoint("CENTER", button.icon, "CENTER", 0, 0)
		button.ring:Hide()
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 20 + (index - 1) * (classSize + classGap), -82)
		button:SetScript("OnClick", function(self)
			Choose("class", self.classToken)
		end)
		button:SetScript("OnEnter", function(self)
			self.icon:SetVertexColor(1, 1, 1)
			self.ring:Show()
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(self.label)
			if self.classToken == ClassToken() then
				GameTooltip:AddLine("Tu clase.", 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		button:SetScript("OnLeave", function(self)
			PaintClassButton(self, self.classToken == state.class)
			GameTooltip:Hide()
		end)
		classButtons[index] = button
	end

	for index = 1, 8 do
		local tabOk, specTab = pcall(CreateFrame, "Button", "FixmyBisSpecTab" .. index, frame, "PanelTabButtonTemplate")
		if not tabOk or not specTab then
			specTab = CreateFrame("Button", "FixmyBisSpecTab" .. index, frame, "UIPanelButtonTemplate")
		end
		specButtons[index] = specTab
		specButtons[index]:Hide()
		specButtons[index]:SetScript("OnClick", function(self)
			Choose("spec", { spec = IsRealSpec(self.spec) and self.spec or nil, mode = self.mode })
		end)
	end

	scroll = CreateFrame("ScrollFrame", "FixmyBisScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -206)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 48)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(760, 1)
	scroll:SetScrollChild(content)
	emptyText = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	emptyText:SetPoint("TOPLEFT", 8, -8)
	emptyText:SetWidth(740)
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
	statusText:SetPoint("RIGHT", frame, "RIGHT", -28, 0)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(true)
	statusText:SetHeight(32)
	statusText:SetText("El + abre las alternativas. Ctrl-clic lo pone en el probador. Mayús-clic con el chat abierto lo enlaza.")

	local grip = CreateFrame("Button", nil, frame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -6, 6)
	grip:SetFrameLevel(frame:GetFrameLevel() + 8)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:RegisterForDrag("LeftButton")
	grip:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Arrastra para ampliar")
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", GameTooltip_Hide)
	grip:SetScript("OnDragStart", function()
		local left, top = frame:GetLeft(), frame:GetTop()
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
		frame:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		if type(FixmyBisDB) ~= "table" then FixmyBisDB = {} end
		FixmyBisDB.width = frame:GetWidth()
		FixmyBisDB.height = frame:GetHeight()
		PlaceFilters()
		FillList()
	end)

	frame:SetScript("OnSizeChanged", function(self)
		if not self:IsShown() or not scroll then return end
		PlaceFilters()
		FillList()
	end)
	if type(FixmyBisDB) == "table" then
		local width = tonumber(FixmyBisDB.width)
		local height = tonumber(FixmyBisDB.height)
		if width and height then
			frame:SetSize(math.max(560, width), math.max(480, height))
		end
	end

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

local function ItemIDFromLink(link)
	if type(link) ~= "string" then return nil end
	return tonumber(link:match("item:(%d+)"))
end

local function AlreadyWearing(itemID)
	if not GetInventoryItemID then return false end
	for slot = 0, 19 do
		if GetInventoryItemID("player", slot) == itemID then
			return true
		end
	end
	return false
end

local function RankOf(itemID)
	EnsureState()
	local list = CurrentList()
	if not list or not list.slots then return nil end
	local faction = state.faction
	local bestRank, bestSlot, bestExtra
	for _, slot in ipairs(SLOT_ORDER) do
		local items = list.slots[slot]
		if items then
			local rank = 0
			for _, item in ipairs(items) do
				if not faction or item.faction == "both" or item.faction == faction then
					rank = rank + 1
					if item.id == itemID and (not bestRank or rank < bestRank) then
						bestRank, bestSlot, bestExtra = rank, slot, item.extra and true or false
					end
				end
			end
		end
	end
	return bestRank, bestSlot, bestExtra
end

local alertQueue = {}
local alertFrame
local alertBusy = false
local recentAlert = {}

local function EnsureAlert()
	if alertFrame then return alertFrame end
	local ok, created = pcall(CreateFrame, "Frame", "FixmyBisAlert", UIParent, "BackdropTemplate")
	alertFrame = (ok and created) or CreateFrame("Frame", "FixmyBisAlert", UIParent)
	alertFrame:SetSize(440, 64)
	alertFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 180)
	alertFrame:SetFrameStrata("HIGH")
	alertFrame:Hide()
	if alertFrame.SetBackdrop then
		pcall(alertFrame.SetBackdrop, alertFrame, {
			bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
			tile = true, tileSize = 256, edgeSize = 24,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
	end
	alertFrame.icon = alertFrame:CreateTexture(nil, "ARTWORK")
	alertFrame.icon:SetSize(40, 40)
	alertFrame.icon:SetPoint("LEFT", 12, 0)
	alertFrame.title = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	alertFrame.title:SetPoint("TOPLEFT", alertFrame.icon, "TOPRIGHT", 10, -4)
	alertFrame.title:SetPoint("RIGHT", -12, 0)
	alertFrame.title:SetJustifyH("LEFT")
	alertFrame.title:SetWordWrap(false)
	alertFrame.line = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	alertFrame.line:SetPoint("BOTTOMLEFT", alertFrame.icon, "BOTTOMRIGHT", 10, 6)
	alertFrame.line:SetPoint("RIGHT", -12, 0)
	alertFrame.line:SetJustifyH("LEFT")
	alertFrame.line:SetWordWrap(false)
	return alertFrame
end

local function ShowNextAlert()
	local entry = table.remove(alertQueue, 1)
	if not entry then
		alertBusy = false
		if alertFrame then alertFrame:Hide() end
		return
	end
	alertBusy = true
	local popup = EnsureAlert()
	popup.icon:SetTexture(entry.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
	local r, g, b = 1, 0.82, 0
	if GetItemQualityColor then
		r, g, b = GetItemQualityColor(entry.quality or 1)
	end
	popup.title:SetText(entry.name or "Objeto")
	popup.title:SetTextColor(r, g, b)
	popup.line:SetText(entry.line or ("Posición " .. entry.rank .. " de importancia en " .. entry.slotName .. ". Lo necesitas."))
	popup:SetAlpha(0)
	popup:Show()
	local elapsedTotal = 0
	popup:SetScript("OnUpdate", function(self, elapsed)
		elapsedTotal = elapsedTotal + elapsed
		if elapsedTotal < 0.15 then
			self:SetAlpha(elapsedTotal / 0.15)
		elseif elapsedTotal < 4.6 then
			self:SetAlpha(1)
		elseif elapsedTotal < 5.3 then
			self:SetAlpha(1 - ((elapsedTotal - 4.6) / 0.7))
		else
			self:SetScript("OnUpdate", nil)
			self:Hide()
			ShowNextAlert()
		end
	end)
end

local function QueueAlert(entry)
	alertQueue[#alertQueue + 1] = entry
	if not alertBusy then
		ShowNextAlert()
	end
end

local function ConsiderDrop(itemID)
	if not itemID then return end
	local now = GetTime and GetTime() or 0
	if recentAlert[itemID] and (now - recentAlert[itemID]) < 12 then return end
	if AlreadyWearing(itemID) then return end
	local rank, slot, extra = RankOf(itemID)
	if not rank then return end
	recentAlert[itemID] = now
	local name, texture, quality = ItemVisual(itemID)
	local slotName = SLOT_NAME[slot] or slot
	local line
	if extra then
		line = "Alternativa, posición " .. rank .. " en " .. slotName .. ". Por detrás de la lista principal."
	else
		line = "Posición " .. rank .. " de importancia en " .. slotName .. ". Lo necesitas."
	end
	QueueAlert({
		name = name,
		texture = texture,
		quality = quality,
		rank = rank,
		slotName = slotName,
		line = line,
	})
	local link = ItemLink(itemID)
	print("|cffffd100FixmyBis|r: " .. (link or name or "Ese objeto") .. " " .. line)
	if not extra and PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
		pcall(PlaySound, SOUNDKIT.RAID_WARNING)
	end
end

local lootWatch = CreateFrame("Frame")
lootWatch:RegisterEvent("START_LOOT_ROLL")
lootWatch:RegisterEvent("LOOT_READY")
lootWatch:RegisterEvent("LOOT_OPENED")
lootWatch:SetScript("OnEvent", function(_, event, arg1)
	if event == "START_LOOT_ROLL" then
		if GetLootRollItemLink then
			ConsiderDrop(ItemIDFromLink(GetLootRollItemLink(arg1)))
		end
		return
	end
	local count = GetNumLootItems and GetNumLootItems() or 0
	for index = 1, count do
		if GetLootSlotLink then
			ConsiderDrop(ItemIDFromLink(GetLootSlotLink(index)))
		end
	end
end)

local whisperSessions = {}
local whisperBuckets = {}
local whisperRing = {}
local whisperRingAt = 0
local whisperNextAt = 0

local CLASS_ALIAS = {
	guerrero = "warrior", warrior = "warrior",
	paladin = "paladin",
	cazador = "hunter", hunter = "hunter",
	picaro = "rogue", rogue = "rogue",
	sacerdote = "priest", priest = "priest",
	chaman = "shaman", shaman = "shaman",
	mago = "mage", mage = "mage",
	brujo = "warlock", warlock = "warlock",
	druida = "druid", druid = "druid",
}

local SLOT_ALIAS = {
	cabeza = "head", head = "head",
	cuello = "neck", neck = "neck",
	hombros = "shoulder", shoulder = "shoulder",
	espalda = "back", capa = "back", back = "back",
	pecho = "chest", chest = "chest",
	munecas = "wrist", wrist = "wrist",
	manos = "hands", hands = "hands",
	cintura = "waist", waist = "waist",
	piernas = "legs", legs = "legs",
	pies = "feet", feet = "feet",
	anillos = "finger", anillo = "finger", finger = "finger",
	abalorios = "trinket", abalorio = "trinket", trinket = "trinket",
	["mano principal"] = "main-hand", ["main hand"] = "main-hand", ["main-hand"] = "main-hand",
	["mano izquierda"] = "off-hand", ["off hand"] = "off-hand", ["off-hand"] = "off-hand",
	["dos manos"] = "two-hand", ["two hand"] = "two-hand", ["two-hand"] = "two-hand",
	escudo = "shield", shield = "shield",
	["a distancia"] = "ranged", distancia = "ranged", ranged = "ranged",
	reliquia = "relic", relic = "relic",
}

local function Plain(text)
	text = tostring(text or ""):lower()
	text = text:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ü", "u"):gsub("ñ", "n")
	text = text:gsub("[^%w%s%-]", " ")
	text = text:gsub("%s+", " ")
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function JoinOptions(names)
	if #names <= 1 then return names[1] or "" end
	local head = {}
	for index = 1, #names - 1 do
		head[index] = names[index]
	end
	return table.concat(head, ", ") .. " o " .. names[#names]
end

local function ChopWhisper(text)
	local parts = {}
	text = tostring(text or "")
	while #text > 240 do
		local cut = text:sub(1, 240)
		local at = cut:match("^.*() / ")
		if not at then break end
		parts[#parts + 1] = text:sub(1, at - 1)
		text = text:sub(at + 3)
	end
	if text ~= "" then
		parts[#parts + 1] = text
	end
	return parts
end

local function Whisper(to, text)
	if not to or not text or text == "" or not SendChatMessage then return end
	local bucket = whisperBuckets[to]
	if not bucket then
		bucket = {}
		whisperBuckets[to] = bucket
		whisperRing[#whisperRing + 1] = to
	end
	for _, part in ipairs(ChopWhisper(text)) do
		bucket[#bucket + 1] = part
	end
end

local whisperPump = CreateFrame("Frame")
whisperPump:SetScript("OnUpdate", function()
	if #whisperRing == 0 or GetTime() < whisperNextAt then return end
	local spins = #whisperRing
	while spins > 0 do
		whisperRingAt = whisperRingAt + 1
		if whisperRingAt > #whisperRing then whisperRingAt = 1 end
		local to = whisperRing[whisperRingAt]
		local bucket = whisperBuckets[to]
		local text = bucket and table.remove(bucket, 1)
		if not text then
			whisperBuckets[to] = nil
			table.remove(whisperRing, whisperRingAt)
			whisperRingAt = whisperRingAt - 1
		else
			if #bucket == 0 then
				whisperBuckets[to] = nil
				table.remove(whisperRing, whisperRingAt)
				whisperRingAt = whisperRingAt - 1
			end
			local ok = pcall(SendChatMessage, text, "WHISPER", nil, to)
			if not ok then
				local short = tostring(to):match("^[^%-]+") or tostring(to)
				print("|cffffd100FixmyBis|r: no he podido susurrar a " .. short .. ".")
			end
			whisperNextAt = GetTime() + 0.7
			return
		end
		spins = spins - 1
	end
end)

local function LevelsForClass(class)
	local seen, levels = {}, {}
	if not FixmyBisData or not FixmyBisData.lists then return levels end
	for _, list in ipairs(FixmyBisData.lists) do
		if list.class == class and not seen[list.level] then
			seen[list.level] = true
			levels[#levels + 1] = list.level
		end
	end
	table.sort(levels)
	return levels
end

local function SlotsOn(list)
	local out = {}
	for _, slot in ipairs(SLOT_ORDER) do
		local items = list.slots and list.slots[slot]
		if items and #items > 0 then
			out[#out + 1] = slot
		end
	end
	return out
end

local function AskClass(who)
	Whisper(who, "¿Qué clase? " .. JoinOptions({
		"Guerrero", "Paladín", "Cazador", "Pícaro", "Sacerdote", "Chamán", "Mago", "Brujo", "Druida",
	}) .. ". Escribe cancelar para salir.")
end

local function AskLevel(who, class)
	local labels = {}
	for _, level in ipairs(LevelsForClass(class)) do
		labels[#labels + 1] = tostring(level)
	end
	Whisper(who, "¿Qué nivel? " .. JoinOptions(labels) .. ".")
end

local function AskSpec(who, lists)
	local labels = {}
	for _, list in ipairs(lists) do
		labels[#labels + 1] = ListLabel(list)
	end
	Whisper(who, "¿Qué especialización? " .. JoinOptions(labels) .. ".")
end

local function AskSlot(who, list)
	local labels = {}
	for _, slot in ipairs(SlotsOn(list)) do
		labels[#labels + 1] = SLOT_NAME[slot] or slot
	end
	Whisper(who, "¿Qué hueco? " .. JoinOptions(labels) .. ".")
end

local function ClassFromUnit(unit)
	if not unit or not UnitExists or not UnitExists(unit) or not UnitClass then return nil end
	local _, token = UnitClass(unit)
	token = token and token:lower()
	if token and CLASS_NAME[token] then return token end
end

local function ClassOf(sender, guid)
	if guid and guid ~= "" and GetPlayerInfoByGUID then
		local _, english = GetPlayerInfoByGUID(guid)
		english = type(english) == "string" and english:lower() or nil
		if english and CLASS_NAME[english] then return english end
	end
	local short = sender:match("^[^%-]+") or sender
	local found = ClassFromUnit(short) or ClassFromUnit(sender)
	if found then return found end
	local raid = IsInRaid and IsInRaid()
	local count = raid and GetNumGroupMembers and GetNumGroupMembers() or (GetNumSubgroupMembers and GetNumSubgroupMembers()) or 0
	for index = 1, count or 0 do
		local unit = (raid and "raid" or "party") .. index
		local name = UnitName and UnitName(unit)
		if name and (name == short or name == sender) then
			return ClassFromUnit(unit)
		end
	end
end

local function ClickableItem(item)
	local link = ItemLink(item.id)
	if link and link:find("|Hitem:", 1, true) and #link < 180 then
		return link
	end
	local colors = {
		[0] = "9d9d9d",
		[1] = "ffffff",
		[2] = "1eff00",
		[3] = "0070dd",
		[4] = "a335ee",
		[5] = "ff8000",
	}
	local name = item.name or tostring(item.id)
	return "|cff" .. (colors[item.quality] or "ffffff") .. "|Hitem:" .. item.id .. "::::::::|h[" .. name .. "]|h|r"
end

local function MatchList(lists, text)
	local wanted = Plain(text)
	local found
	for _, list in ipairs(lists) do
		local label = Plain(ListLabel(list))
		local spec = Plain(list.spec or "")
		local hit = wanted == label or (IsRealSpec(list.spec) and wanted == spec)
		if not hit and (list.spec == "pve" or list.spec == "pvp") then
			hit = wanted == label or wanted == spec or wanted == (list.mode == "pvp" and "jcj" or "jce") or wanted == (list.mode == "pvp" and "pvp" or "pve")
		end
		if hit then
			if found then return nil end
			found = list
		end
	end
	return found
end

local function ReplyList(who, session)
	local list = session.list
	local items = list.slots and list.slots[session.slot]
	local lines = {}
	local title = (CLASS_NAME[session.class] or session.class) .. " nivel " .. session.level .. ", " .. ListLabel(list) .. ", " .. (SLOT_NAME[session.slot] or session.slot) .. ". Pasa el ratón para verlas. Control y clic abre el probador."
	lines[1] = title
	local count = 0
	local function add(item)
		count = count + 1
		lines[#lines + 1] = count .. ". " .. ClickableItem(item)
	end
	if items then
		for _, item in ipairs(items) do
			if not item.extra and (item.faction == "both" or item.faction == session.faction) then
				add(item)
			end
		end
		local extras = 0
		for _, item in ipairs(items) do
			if item.extra and (item.faction == "both" or item.faction == session.faction) then
				if extras == 0 then
					lines[#lines + 1] = "Alternativas:"
				end
				if extras < 12 then
					add(item)
				end
				extras = extras + 1
			end
		end
		if extras > 12 then
			lines[#lines + 1] = "Hay " .. (extras - 12) .. " alternativas más."
		end
	end
	if count == 0 then
		Whisper(who, title .. " No hay piezas de ese hueco para esa facción.")
		return
	end
	local chunk = ""
	for _, line in ipairs(lines) do
		local nextChunk = chunk == "" and line or (chunk .. " / " .. line)
		if #nextChunk > 200 and chunk ~= "" then
			Whisper(who, chunk)
			chunk = line
		else
			chunk = nextChunk
		end
	end
	if chunk ~= "" then
		Whisper(who, chunk)
	end
end

local function HandleWhisper(message, sender, guid)
	if not sender or sender == "" or not message then return end
	local text = Plain(message)
	if text == "" then return end
	if text == "cancelar" or text == "parar" or text == "stop" or text == "salir" then
		if whisperSessions[sender] then
			whisperSessions[sender] = nil
			Whisper(sender, "De acuerdo, lo dejo. Susurra fixmybis cuando quieras empezar de nuevo.")
		end
		return
	end
	if text:find("fixmybis", 1, true) then
		local short = sender:match("^[^%-]+") or sender
		local class = ClassOf(sender, guid)
		print("|cffffd100FixmyBis|r: " .. short .. " ha pedido una lista por susurro.")
		if class then
			whisperSessions[sender] = { step = "level", class = class }
			Whisper(sender, "Te detecto como " .. CLASS_NAME[class] .. ". Si no es tu clase, escribe el nombre.")
			AskLevel(sender, class)
		else
			whisperSessions[sender] = { step = "class" }
			AskClass(sender)
		end
		return
	end
	local session = whisperSessions[sender]
	if not session then return end
	if session.step == "class" then
		local class = CLASS_ALIAS[text]
		if not class then
			AskClass(sender)
			return
		end
		session.class = class
		session.step = "level"
		AskLevel(sender, class)
		return
	end
	if session.step == "level" then
		local corrected = CLASS_ALIAS[text]
		if corrected then
			session.class = corrected
			AskLevel(sender, corrected)
			return
		end
		local level = tonumber(text:match("(%d+)"))
		local allowed = false
		for _, value in ipairs(LevelsForClass(session.class)) do
			if value == level then allowed = true end
		end
		if not allowed then
			AskLevel(sender, session.class)
			return
		end
		session.level = level
		session.step = "spec"
		AskSpec(sender, ListsFor(level, session.class))
		return
	end
	if session.step == "spec" then
		local list = MatchList(ListsFor(session.level, session.class), text)
		if not list then
			AskSpec(sender, ListsFor(session.level, session.class))
			return
		end
		session.list = list
		session.step = "slot"
		AskSlot(sender, list)
		return
	end
	if session.step == "slot" then
		local slot = SLOT_ALIAS[text]
		local allowed = false
		if slot then
			for _, value in ipairs(SlotsOn(session.list)) do
				if value == slot then allowed = true end
			end
		end
		if not allowed then
			AskSlot(sender, session.list)
			return
		end
		session.slot = slot
		session.faction = FactionToken()
		whisperSessions[sender] = nil
		if not session.faction then
			Whisper(sender, "No he podido leer la facción de este personaje. Prueba otra vez en un momento.")
			return
		end
		local ok, err = pcall(ReplyList, sender, session)
		if not ok then
			Whisper(sender, "No he podido montar esa lista. Susurra fixmybis para empezar de nuevo.")
			print("|cffffd100FixmyBis|r: error al montar la lista: " .. tostring(err))
		end
	end
end

local whisperWatch = CreateFrame("Frame")
whisperWatch:RegisterEvent("CHAT_MSG_WHISPER")
whisperWatch:SetScript("OnEvent", function(_, _, message, sender, _, _, _, _, _, _, _, _, _, guid)
	HandleWhisper(message, sender, guid)
end)

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
