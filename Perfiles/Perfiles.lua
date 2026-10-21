-- Perfiles de addons: farmeo, JcJ, mazmorras, banda.
-- Cada perfil guarda qué addons están activos y qué diseño del modo edición usa.
-- Cambiar de perfil recarga la interfaz. Perfiles no se puede apagar.

local ADDON = "Perfiles"
local MAX_NODES = 5000
local MAX_DEPTH = 10
local MAX_PROFILES = 12
local DEFAULTS = { "Farmeo", "JcJ", "Mazmorras", "Banda" }

local db
local frame
local characterKey
local started
local editing
local searchText = ""
local addonCache
local rows = {}
local profileButtons = {}

local function Say(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Perfiles|r: " .. text)
	end
end

local function SafeNumber(value)
	if type(value) ~= "number" then return nil end
	local ok, number = pcall(function()
		return value + 0
	end)
	if ok and type(number) == "number" then return number end
end

local function Plain(text)
	if type(text) ~= "string" or text == "" then return "" end
	local ok, value = pcall(function()
		text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
		text = text:lower()
		text = text:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ü", "u"):gsub("ñ", "n")
		return text
	end)
	if ok and type(value) == "string" then return value end
	return ""
end

local function CleanName(text)
	if type(text) ~= "string" then return nil end
	local ok, value = pcall(function()
		return text:gsub("^%s+", ""):gsub("%s+$", "")
	end)
	if not ok or type(value) ~= "string" or value == "" or #value > 24 then return nil end
	return value
end

local function CharacterKey()
	if characterKey then return characterKey end
	local name, realm
	pcall(function()
		name = UnitName("player")
		realm = GetRealmName()
	end)
	if type(name) ~= "string" or name == "" then return nil end
	if type(realm) == "string" and realm ~= "" then
		characterKey = name .. " - " .. realm
	else
		characterKey = name
	end
	return characterKey
end

local function ShortName()
	local name
	pcall(function()
		name = UnitName("player")
	end)
	if type(name) == "string" and name ~= "" then return name end
end

local function Metadata(addon, field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		local ok, result = pcall(C_AddOns.GetAddOnMetadata, addon, field)
		if ok and type(result) == "string" and result ~= "" then return result end
	end
	if GetAddOnMetadata then
		local ok, result = pcall(GetAddOnMetadata, addon, field)
		if ok and type(result) == "string" and result ~= "" then return result end
	end
end

local function AsEnabled(state)
	if state == true then return true end
	if state == false or state == nil then return false end
	if type(state) == "number" then return state > 0 end
	return false
end

local function AddonIsEnabled(name)
	if C_AddOns and C_AddOns.GetAddOnEnableState then
		local ok, state = pcall(C_AddOns.GetAddOnEnableState, name)
		if ok and (type(state) == "number" or type(state) == "boolean") then
			return AsEnabled(state)
		end
	end
	return true
end

local function SetAddonEnabled(name, enabled)
	local fn
	if enabled then
		fn = (C_AddOns and C_AddOns.EnableAddOn) or EnableAddOn
	else
		fn = (C_AddOns and C_AddOns.DisableAddOn) or DisableAddOn
	end
	if type(fn) ~= "function" then return end
	pcall(fn, name)
end

local function AddonList()
	if addonCache then return addonCache end
	local total = 0
	pcall(function()
		if C_AddOns and C_AddOns.GetNumAddOns then
			total = C_AddOns.GetNumAddOns()
		else
			total = GetNumAddOns()
		end
	end)
	local list = {}
	for index = 1, total or 0 do
		local name, title, _, _, _, _, security
		pcall(function()
			if C_AddOns and C_AddOns.GetAddOnInfo then
				name, title = C_AddOns.GetAddOnInfo(index)
			else
				name, title, _, _, _, _, security = GetAddOnInfo(index)
			end
		end)
		if type(name) == "string" and name ~= "" and name ~= ADDON and name:sub(1, 9) ~= "Blizzard_" and security ~= "SECURE" then
			local clean = Plain(title)
			if clean == "" then clean = name end
			local show = title
			if type(show) ~= "string" or show == "" then show = name end
			local ok, stripped = pcall(function()
				return show:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
			end)
			if ok and type(stripped) == "string" and stripped ~= "" then show = stripped end
			list[#list + 1] = { name = name, title = show, sort = clean }
		end
	end
	table.sort(list, function(a, b)
		if a.sort == b.sort then return a.name < b.name end
		return a.sort < b.sort
	end)
	addonCache = list
	return list
end

local function VariableNames(addon)
	local names = {}
	local seen = {}
	local fields = { "SavedVariables", "SavedVariablesPerCharacter" }
	for index = 1, #fields do
		local text = Metadata(addon, fields[index])
		if type(text) == "string" then
			for piece in text:gmatch("[^,%s]+") do
				if piece ~= "PerfilesDB" and not seen[piece] then
					seen[piece] = true
					names[#names + 1] = piece
				end
			end
		end
	end
	return names
end

local function KnownVariables()
	local known = {}
	local list = AddonList()
	for index = 1, #list do
		local vars = VariableNames(list[index].name)
		for varIndex = 1, #vars do
			known[vars[varIndex]] = true
		end
	end
	return known
end

local CopyValue
CopyValue = function(value, seen, nodes, depth)
	nodes.n = nodes.n + 1
	if nodes.n > MAX_NODES then
		nodes.overflow = true
		return nil, false
	end
	local kind = type(value)
	if kind == "boolean" or kind == "number" then
		return value, true
	end
	if kind == "string" then
		return value, true
	end
	if kind ~= "table" or depth > MAX_DEPTH then
		return nil, false
	end
	if seen[value] then
		return seen[value], true
	end
	local out = {}
	seen[value] = out
	local ok = pcall(function()
		for key, child in pairs(value) do
			local keyType = type(key)
			if (keyType == "string" or keyType == "number") and key ~= nil then
				local copied, keep = CopyValue(child, seen, nodes, depth + 1)
				if keep and not nodes.overflow then
					out[key] = copied
				end
			end
		end
	end)
	if not ok or nodes.overflow then
		nodes.overflow = true
		return nil, false
	end
	return out, true
end

local function CurrentAddonMap()
	local map = {}
	local list = AddonList()
	for index = 1, #list do
		map[list[index].name] = AddonIsEnabled(list[index].name) and true or false
	end
	return map
end

local function BindDB()
	if db then return end
	local old = _G.PerfilesDB
	if type(old) ~= "table" then
		old = {}
		_G.PerfilesDB = old
	end
	old.chars = nil
	if type(old.profiles) == "table" then
		for _, profile in pairs(old.profiles) do
			if type(profile) == "table" then
				profile.saved = nil
			end
		end
	end
	PerfilesDB = old
	db = old
end

local function CharDB()
	BindDB()
	db.profiles = db.profiles or {}
	db.order = db.order or {}
	local created = false
	local kept = {}
	local order = {}
	for index = 1, #db.order do
		local profileName = db.order[index]
		if type(profileName) == "string" and type(db.profiles[profileName]) == "table" and not kept[profileName] then
			kept[profileName] = true
			order[#order + 1] = profileName
			db.profiles[profileName].addons = db.profiles[profileName].addons or {}
			db.profiles[profileName].saved = nil
		end
	end
	db.order = order
	if #db.order == 0 then
		created = true
		local map = CurrentAddonMap()
		for index = 1, #DEFAULTS do
			local profileName = DEFAULTS[index]
			local addons = {}
			for addonName, enabled in pairs(map) do
				addons[addonName] = enabled and true or false
			end
			db.profiles[profileName] = { addons = addons }
			db.order[#db.order + 1] = profileName
		end
		db.active = DEFAULTS[1]
	end
	if type(db.profiles[db.active]) ~= "table" then
		db.active = db.order[1]
	end
	return db, created
end

local function EditingName()
	local char = CharDB()
	if not char then return nil end
	if type(editing) == "string" and char.profiles[editing] then return editing end
	editing = char.active
	return editing
end

local function Snapshot(profile, report)
	if type(profile) ~= "table" then return end
	profile.saved = profile.saved or {}
	local known = KnownVariables()
	local skipped = {}
	for varName in pairs(known) do
		local live = _G[varName]
		if type(live) == "table" and live ~= _G.PerfilesDB then
			local nodes = { n = 0 }
			local copy, keep = CopyValue(live, {}, nodes, 0)
			if keep and copy and not nodes.overflow then
				profile.saved[varName] = copy
			else
				skipped[#skipped + 1] = varName
			end
		end
	end
	if report and #skipped > 0 then
		table.sort(skipped)
		local shown = {}
		local limit = #skipped
		if limit > 8 then limit = 8 end
		for index = 1, limit do
			shown[index] = skipped[index]
		end
		local text = table.concat(shown, ", ")
		if #skipped > 8 then
			text = text .. " y " .. (#skipped - 8) .. " más"
		end
		Say("Estas opciones son demasiado grandes y se quedan como están: " .. text)
	end
end

local function Restore(profile)
	if type(profile) ~= "table" or type(profile.saved) ~= "table" then return end
	local known = KnownVariables()
	for varName, stored in pairs(profile.saved) do
		if known[varName] and type(stored) == "table" then
			local nodes = { n = 0 }
			local copy, keep = CopyValue(stored, {}, nodes, 0)
			if keep and copy and not nodes.overflow then
				local live = _G[varName]
				if type(live) == "table" and live ~= _G.PerfilesDB then
					local keys = {}
					local ok = pcall(function()
						for key in pairs(live) do
							keys[#keys + 1] = key
						end
					end)
					if ok then
						for index = 1, #keys do
							live[keys[index]] = nil
						end
						for key, value in pairs(copy) do
							live[key] = value
						end
					end
				else
					_G[varName] = copy
				end
			end
		end
	end
end

local function PlainLayoutName(name, index)
	if type(name) == "string" and name ~= "" then
		local ok, length = pcall(function()
			return #name
		end)
		if ok and type(length) == "number" and length > 0 and length <= 80 then
			return name
		end
	end
	return "Diseño " .. index
end

local function LayoutEntries()
	local entries = {}
	local manager = _G.EditModeManagerFrame
	if not manager then
		local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
		if type(load) == "function" then
			pcall(load, "Blizzard_EditMode")
			manager = _G.EditModeManagerFrame
		end
	end
	local layouts
	local fromManager = false
	if manager and type(manager.GetLayouts) == "function" then
		local ok, result = pcall(manager.GetLayouts, manager)
		if ok and type(result) == "table" and #result > 0 then
			layouts = result
			fromManager = true
		end
	end
	if not layouts and C_EditMode and type(C_EditMode.GetLayouts) == "function" then
		local ok, info = pcall(C_EditMode.GetLayouts)
		if ok and type(info) == "table" and type(info.layouts) == "table" then
			layouts = info.layouts
		end
	end
	if type(layouts) ~= "table" then return entries, manager, fromManager end
	local preset = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset
	local characterType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character
	for index = 1, #layouts do
		local layout = layouts[index]
		if type(layout) == "table" then
			local name = PlainLayoutName(layout.layoutName, index)
			local layoutType = layout.layoutType
			if type(layoutType) ~= "number" then layoutType = -1 end
			local suffix = ""
			if preset and layoutType == preset then
				suffix = " · predeterminado"
			elseif characterType and layoutType == characterType then
				suffix = " · personaje"
			end
			entries[#entries + 1] = {
				index = index,
				key = layoutType .. "\031" .. name,
				name = name,
				label = name .. suffix,
			}
		end
	end
	return entries, manager, fromManager
end

local function LayoutIndex(entry, fromManager)
	if fromManager or type(entry) ~= "table" then return entry and entry.index end
	local presets = 0
	local presetManager = _G.EditModePresetLayoutManager
	if type(presetManager) == "table" and type(presetManager.GetCopyOfPresetLayouts) == "function" then
		local ok, all = pcall(presetManager.GetCopyOfPresetLayouts, presetManager)
		if ok and type(all) == "table" then presets = #all end
	end
	return presets + entry.index
end

local function ApplyLayout(profile)
	if type(profile) ~= "table" or type(profile.layoutKey) ~= "string" or profile.layoutKey == "" then
		return
	end
	local entries, manager, fromManager = LayoutEntries()
	local found
	for index = 1, #entries do
		if entries[index].key == profile.layoutKey then
			found = entries[index]
			break
		end
	end
	if not found then
		Say("No encuentro el diseño de interfaz de este perfil. Los addons sí cambian.")
		return
	end
	local layoutIndex = LayoutIndex(found, fromManager)
	local applied = false
	if manager and type(manager.SelectLayout) == "function" and type(layoutIndex) == "number" then
		applied = pcall(manager.SelectLayout, manager, layoutIndex)
	end
	if not applied and C_EditMode and type(C_EditMode.SetActiveLayout) == "function" and type(layoutIndex) == "number" then
		applied = pcall(C_EditMode.SetActiveLayout, layoutIndex)
	end
	if not applied then
		Say("No he podido cambiar el diseño de interfaz. Los addons sí cambian.")
	end
end

local function Reload()
	if type(ReloadUI) == "function" then
		ReloadUI()
		return
	end
	if C_UI and type(C_UI.Reload) == "function" then
		C_UI.Reload()
	end
end

local function Apply(name)
	local char = CharDB()
	if not char or type(char.profiles[name]) ~= "table" then return end
	local profile = char.profiles[name]
	local addons = profile.addons or {}
	for addonName, enabled in pairs(addons) do
		if addonName ~= ADDON then
			SetAddonEnabled(addonName, enabled and true or false)
		end
	end
	SetAddonEnabled(ADDON, true)
	ApplyLayout(profile)
	char.active = name
	editing = name
	Say("Aplicando " .. name .. ". Recargo la interfaz.")
	Reload()
end

local function ApplyPrompt(name)
	local char = CharDB()
	local profile = char and char.profiles[name]
	local layout = profile and profile.layoutName
	local detail = "Se encienden y apagan sus addons y se recarga la interfaz."
	if type(layout) == "string" and layout ~= "" then
		local ok, safe = pcall(function()
			return layout:gsub("%%", "")
		end)
		if ok and type(safe) == "string" and safe ~= "" then
			detail = "Se encienden y apagan sus addons, se usa el diseño " .. safe .. " y se recarga la interfaz."
		end
	end
	local safeName = name
	local okName, cleaned = pcall(function()
		return name:gsub("%%", "")
	end)
	if okName and type(cleaned) == "string" and cleaned ~= "" then
		safeName = cleaned
	end
	StaticPopupDialogs.PERFILES_APPLY.text = "Vas a usar el perfil " .. safeName .. ".\n" .. detail
	StaticPopup_Show("PERFILES_APPLY", nil, nil, name)
end

local function CreateProfile(text)
	local name = CleanName(text)
	if not name then
		Say("Escribe un nombre de hasta 24 letras.")
		return
	end
	local char = CharDB()
	if not char then return end
	if char.profiles[name] then
		Say("Ya existe un perfil con ese nombre.")
		return
	end
	if #char.order >= MAX_PROFILES then
		Say("No caben más de " .. MAX_PROFILES .. " perfiles.")
		return
	end
	local source = char.profiles[char.active]
	local addons = {}
	if source and source.addons then
		for addonName, enabled in pairs(source.addons) do
			addons[addonName] = enabled and true or false
		end
	end
	char.profiles[name] = { addons = addons }
	if source and type(source.layoutKey) == "string" and source.layoutKey ~= "" then
		char.profiles[name].layoutKey = source.layoutKey
		char.profiles[name].layoutName = source.layoutName
	end
	char.order[#char.order + 1] = name
	editing = name
	if frame then frame:Show() end
end

local function DeleteProfile(name)
	local char = CharDB()
	if not char or type(char.profiles[name]) ~= "table" then return end
	if #char.order <= 1 then
		Say("Tiene que quedar al menos un perfil.")
		return
	end
	local wasActive = char.active == name
	char.profiles[name] = nil
	for index = #char.order, 1, -1 do
		if char.order[index] == name then
			table.remove(char.order, index)
		end
	end
	if wasActive then
		char.active = char.order[1]
		Say(name .. " estaba en uso. Los addons no cambian hasta que apliques otro perfil.")
	end
	if editing == name then editing = char.active end
end

local function SetAll(enabled)
	local char = CharDB()
	local name = EditingName()
	if not char or not name then return end
	local profile = char.profiles[name]
	local list = AddonList()
	for index = 1, #list do
		profile.addons[list[index].name] = enabled and true or false
	end
end

local function SavePoint(self)
	local point, _, relative, x, y = self:GetPoint()
	if type(point) ~= "string" or not db then return end
	db.point = point
	db.relative = type(relative) == "string" and relative or point
	db.x = SafeNumber(x) or 0
	db.y = SafeNumber(y) or 0
end

local Refresh

local function DialogEditText(dialog)
	if dialog.editBox and dialog.editBox.GetText then
		return dialog.editBox:GetText()
	end
	if dialog.GetName then
		local box = _G[dialog:GetName() .. "EditBox"]
		if box and box.GetText then return box:GetText() end
	end
	return ""
end

local function MakeFrame()
	frame = CreateFrame("Frame", "PerfilesFrame", UIParent)
	frame:SetSize(720, 580)
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePoint(self)
	end)
	if db and db.point then
		frame:SetPoint(db.point, UIParent, db.relative or db.point, db.x or 0, db.y or 0)
	else
		frame:SetPoint("CENTER")
	end
	tinsert(UISpecialFrames, "PerfilesFrame")

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.07, 0.94)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -12)
	title:SetText("Perfiles")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local info = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	info:SetPoint("TOPLEFT", 16, -36)
	info:SetPoint("TOPRIGHT", -36, -36)
	info:SetJustifyH("LEFT")
	info:SetHeight(32)
	if info.SetSpacing then info:SetSpacing(2) end
	info:SetText("Cada perfil recuerda los addons activos y un diseño del modo edición. Aplicar recarga la interfaz.\nLas opciones de cada addon las guarda ese addon. Perfiles se queda siempre activo.")

	local layoutLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	layoutLabel:SetPoint("TOPLEFT", 200, -72)
	layoutLabel:SetText("Diseño del modo edición")
	frame.layoutLabel = layoutLabel
	frame.layoutRows = {}

	local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	status:SetPoint("TOPLEFT", 16, -72)
	status:SetPoint("RIGHT", layoutLabel, "LEFT", -12, 0)
	status:SetJustifyH("LEFT")
	status:SetHeight(18)
	frame.status = status

	local side = frame:CreateTexture(nil, "BACKGROUND")
	side:SetPoint("TOPLEFT", 12, -96)
	side:SetSize(176, 408)
	side:SetColorTexture(0.09, 0.09, 0.12, 1)

	local scroll = CreateFrame("ScrollFrame", nil, frame)
	scroll:SetPoint("TOPLEFT", 200, -220)
	scroll:SetPoint("BOTTOMRIGHT", -28, 64)
	scroll:EnableMouseWheel(true)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(480, 1)
	scroll:SetScrollChild(child)
	frame.scroll = scroll
	frame.child = child

	local slider = CreateFrame("Slider", nil, frame)
	slider:SetOrientation("VERTICAL")
	slider:SetPoint("TOPRIGHT", -10, -220)
	slider:SetPoint("BOTTOMRIGHT", -10, 64)
	slider:SetWidth(12)
	slider:SetMinMaxValues(0, 1)
	slider:SetValue(0)
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(12, 28)
	thumb:SetColorTexture(0.75, 0.62, 0.28, 0.95)
	slider:SetThumbTexture(thumb)
	frame.slider = slider

	local scrolling = false
	local function SetScroll(offset)
		if scrolling then return end
		local range = scroll.range or 0
		if offset < 0 then offset = 0 end
		if offset > range then offset = range end
		scrolling = true
		scroll:SetVerticalScroll(offset)
		slider:SetValue(offset)
		scrolling = false
	end
	slider:SetScript("OnValueChanged", function(_, value)
		if not frame:IsShown() then return end
		local offset = SafeNumber(value)
		if not offset then return end
		SetScroll(offset)
	end)
	local function OnWheel(_, delta)
		SetScroll(scroll:GetVerticalScroll() - delta * 36)
	end
	scroll:SetScript("OnMouseWheel", OnWheel)
	child:EnableMouseWheel(true)
	child:SetScript("OnMouseWheel", OnWheel)
	frame.SetScroll = SetScroll
	frame.OnWheel = OnWheel

	local search = CreateFrame("EditBox", "PerfilesSearchBox", frame, "InputBoxTemplate")
	search:SetSize(220, 20)
	search:SetPoint("TOPLEFT", 208, -190)
	frame.search = search
	search:SetAutoFocus(false)
	search:SetMaxLetters(40)
	search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	search:SetScript("OnTextChanged", function(self)
		searchText = Plain(self:GetText() or "")
		Refresh()
	end)

	local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	searchLabel:SetPoint("BOTTOMLEFT", search, "TOPLEFT", -4, 2)
	searchLabel:SetText("Buscar addon")

	local allButton = CreateFrame("Button", "PerfilesAllButton", frame, "UIPanelButtonTemplate")
	allButton:SetSize(72, 22)
	allButton:SetPoint("LEFT", search, "RIGHT", 12, 0)
	allButton:SetText("Todos")
	allButton:SetScript("OnClick", function()
		SetAll(true)
		Refresh()
	end)

	local noneButton = CreateFrame("Button", "PerfilesNoneButton", frame, "UIPanelButtonTemplate")
	noneButton:SetSize(80, 22)
	noneButton:SetPoint("LEFT", allButton, "RIGHT", 6, 0)
	noneButton:SetText("Ninguno")
	noneButton:SetScript("OnClick", function()
		SetAll(false)
		Refresh()
	end)

	local applyButton = CreateFrame("Button", "PerfilesApplyButton", frame, "UIPanelButtonTemplate")
	applyButton:SetSize(170, 24)
	applyButton:SetPoint("BOTTOMLEFT", 16, 28)
	applyButton:SetText("Aplicar y recargar")
	applyButton:SetScript("OnClick", function()
		local name = EditingName()
		if not name then return end
		ApplyPrompt(name)
	end)

	local newButton = CreateFrame("Button", "PerfilesNewButton", frame, "UIPanelButtonTemplate")
	newButton:SetSize(110, 24)
	newButton:SetPoint("LEFT", applyButton, "RIGHT", 8, 0)
	newButton:SetText("Nuevo perfil")
	newButton:SetScript("OnClick", function()
		StaticPopup_Show("PERFILES_NEW")
	end)

	local deleteButton = CreateFrame("Button", "PerfilesDeleteButton", frame, "UIPanelButtonTemplate")
	deleteButton:SetSize(110, 24)
	deleteButton:SetPoint("LEFT", newButton, "RIGHT", 8, 0)
	deleteButton:SetText("Borrar perfil")
	deleteButton:SetScript("OnClick", function()
		local name = EditingName()
		if not name then return end
		StaticPopupDialogs.PERFILES_DELETE.text = "¿Borrar el perfil " .. name .. "?"
		StaticPopup_Show("PERFILES_DELETE", nil, nil, name)
	end)

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 16, 8)
	hint:SetPoint("BOTTOMRIGHT", -16, 8)
	hint:SetJustifyH("LEFT")
	hint:SetText("El diseño del modo edición se aplica junto con los addons, al recargar.")

	frame.ready = false
	frame:SetScript("OnShow", function(self)
		if self.ready and db then db.open = true end
		Refresh()
	end)
	frame:SetScript("OnHide", function(self)
		if self.ready and db then db.open = false end
	end)

	frame:Hide()
	frame.ready = true
end

Refresh = function()
	if not frame then return end
	local char = CharDB()
	if not char then return end
	local selected = EditingName()
	if char.active == selected then
		frame.status:SetText("|cffffd100En uso y seleccionado:|r " .. selected)
	else
		frame.status:SetText("|cffffd100En uso:|r " .. char.active .. "    |cffffd100Seleccionado:|r " .. selected)
	end

	for index = 1, #char.order do
		local button = profileButtons[index]
		if not button then
			button = CreateFrame("Button", nil, frame)
			button:SetSize(164, 26)
			local buttonBg = button:CreateTexture(nil, "BACKGROUND")
			buttonBg:SetAllPoints()
			buttonBg:SetColorTexture(0.16, 0.16, 0.2, 1)
			local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			label:SetPoint("LEFT", 8, 0)
			label:SetPoint("RIGHT", -6, 0)
			label:SetJustifyH("LEFT")
			button.bg = buttonBg
			button.label = label
			button:SetScript("OnClick", function(self)
				editing = self.profileName
				Refresh()
			end)
			profileButtons[index] = button
		end
		local profileName = char.order[index]
		button.profileName = profileName
		button:SetPoint("TOPLEFT", 18, -102 - (index - 1) * 28)
		local suffix = ""
		if profileName == char.active then suffix = "  · en uso" end
		button.label:SetText(profileName .. suffix)
		if profileName == selected then
			button.bg:SetColorTexture(0.35, 0.28, 0.1, 1)
		elseif profileName == char.active then
			button.bg:SetColorTexture(0.18, 0.24, 0.16, 1)
		else
			button.bg:SetColorTexture(0.16, 0.16, 0.2, 1)
		end
		button:Show()
	end
	for index = #char.order + 1, #profileButtons do
		profileButtons[index]:Hide()
	end

	local profile = char.profiles[selected]
	local entries = LayoutEntries()
	local choices = {
		{ key = "", name = nil, label = "No cambiar la interfaz" },
	}
	for index = 1, #entries do
		choices[#choices + 1] = entries[index]
	end
	if #entries == 0 then
		choices[#choices + 1] = { key = "", name = nil, label = "Sin diseños de modo edición", disabled = true }
	end
	local selectedKey = profile and profile.layoutKey or ""
	if type(selectedKey) ~= "string" then selectedKey = "" end
	for index = 1, #choices do
		local button = frame.layoutRows[index]
		if not button then
			button = CreateFrame("Button", nil, frame)
			button:SetSize(490, 22)
			local buttonBg = button:CreateTexture(nil, "BACKGROUND")
			buttonBg:SetAllPoints()
			buttonBg:SetColorTexture(0.16, 0.16, 0.2, 1)
			local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			label:SetPoint("LEFT", 8, 0)
			label:SetPoint("RIGHT", -8, 0)
			label:SetJustifyH("LEFT")
			button.bg = buttonBg
			button.label = label
			button:SetScript("OnClick", function(self)
				if self.disabled then return end
				local current = CharDB()
				local profileName = EditingName()
				local target = current and profileName and current.profiles[profileName]
				if not target then return end
				if type(self.layoutKey) == "string" and self.layoutKey ~= "" then
					target.layoutKey = self.layoutKey
					target.layoutName = self.layoutName
				else
					target.layoutKey = nil
					target.layoutName = nil
				end
				Refresh()
			end)
			frame.layoutRows[index] = button
		end
		local choice = choices[index]
		button.layoutKey = choice.key
		button.layoutName = choice.name
		button.disabled = choice.disabled
		button.label:SetText(choice.label)
		button:SetPoint("TOPLEFT", 200, -94 - (index - 1) * 24)
		if choice.disabled then
			button.bg:SetColorTexture(0.12, 0.12, 0.12, 1)
		elseif choice.key == selectedKey and not (choice.key == "" and choice.disabled) then
			button.bg:SetColorTexture(0.35, 0.28, 0.1, 1)
		else
			button.bg:SetColorTexture(0.16, 0.16, 0.2, 1)
		end
		button:Show()
	end
	for index = #choices + 1, #frame.layoutRows do
		frame.layoutRows[index]:Hide()
	end
	local below = 94 + #choices * 24 + 10
	if frame.search then
		frame.search:ClearAllPoints()
		frame.search:SetPoint("TOPLEFT", 208, -below)
	end
	frame.scroll:ClearAllPoints()
	frame.scroll:SetPoint("TOPLEFT", 200, -(below + 28))
	frame.scroll:SetPoint("BOTTOMRIGHT", -28, 64)
	frame.slider:ClearAllPoints()
	frame.slider:SetPoint("TOPRIGHT", -10, -(below + 28))
	frame.slider:SetPoint("BOTTOMRIGHT", -10, 64)
	local list = AddonList()
	local shown = 0
	for index = 1, #list do
		local info = list[index]
		if searchText == "" or Plain(info.title .. " " .. info.name):find(searchText, 1, true) then
			shown = shown + 1
			local row = rows[shown]
			if not row then
				row = CreateFrame("Frame", nil, frame.child)
				row:SetSize(470, 24)
				row:EnableMouseWheel(true)
				row:SetScript("OnMouseWheel", frame.OnWheel)
				local box = CreateFrame("CheckButton", nil, row)
				box:SetSize(22, 22)
				box:SetPoint("LEFT", 0, 0)
				box:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
				box:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
				box:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
				box:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
				box:SetScript("OnClick", function(self)
					local current = CharDB()
					local profileName = EditingName()
					if not current or not profileName or not current.profiles[profileName] then return end
					current.profiles[profileName].addons[self.addonName] = not not self:GetChecked()
				end)
				local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
				label:SetPoint("LEFT", box, "RIGHT", 4, 0)
				label:SetWidth(430)
				label:SetJustifyH("LEFT")
				row.box = box
				row.label = label
				rows[shown] = row
			end
			row:SetPoint("TOPLEFT", 4, -((shown - 1) * 24))
			row.box.addonName = info.name
			local enabled = profile.addons[info.name]
			if enabled == nil then enabled = AddonIsEnabled(info.name) end
			row.box:SetChecked(enabled and true or false)
			if info.title ~= info.name then
				row.label:SetText(info.title .. "  |cffaaaaaa" .. info.name .. "|r")
			else
				row.label:SetText(info.title)
			end
			row:Show()
		end
	end
	for index = shown + 1, #rows do
		rows[index]:Hide()
	end

	local height = shown * 24
	if height < 1 then height = 1 end
	frame.child:SetHeight(height)
	local view = frame.scroll:GetHeight() or 1
	local range = height - view
	if range < 0 then range = 0 end
	frame.scroll.range = range
	if range < 1 then
		frame.slider:Hide()
		frame.SetScroll(0)
	else
		frame.slider:Show()
		frame.slider:SetMinMaxValues(0, range)
		local current = frame.scroll:GetVerticalScroll() or 0
		if current > range then current = range end
		frame.SetScroll(current)
	end
end

local function Toggle()
	if not started then return end
	if not frame then MakeFrame() end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
	end
end

local function PlaceMinimapButton(button, angle)
	local radius = Minimap and Minimap:GetWidth() / 2
	if not radius or radius < 20 then radius = 80 end
	local rad = math.rad(angle)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function EnsureMinimapButton()
	if not Minimap or not db then return end
	local button = _G.PerfilesMinimapButton
	if not button then
	button = CreateFrame("Button", "PerfilesMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("CENTER", 1, 0)

	local downX, downY
	button:SetScript("OnMouseDown", function(_, mouseButton)
		if mouseButton == "LeftButton" then
			downX, downY = GetCursorPosition()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local cx, cy = GetCursorPosition()
			if downX and cx and ((cx - downX) ^ 2 + (cy - downY) ^ 2) < 64 then return end
			local mx, my = Minimap:GetCenter()
			local scale = Minimap:GetEffectiveScale()
			if scale and scale > 0 then
				cx, cy = cx / scale, cy / scale
			end
			if not mx or not my or not cx or not cy then return end
			local nextAngle = math.deg(math.atan2(cy - my, cx - mx))
			db.minimapAngle = nextAngle
			PlaceMinimapButton(self, nextAngle)
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	button:SetScript("OnClick", function()
		local cx, cy = GetCursorPosition()
		if downX and cx and ((cx - downX) ^ 2 + (cy - downY) ^ 2) >= 64 then return end
		Toggle()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("Perfiles")
		local char = CharDB()
		if char then
			GameTooltip:AddLine("En uso: " .. char.active, 1, 0.82, 0)
		end
		GameTooltip:AddLine("Clic para abrir. Arrastra para moverlo.", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	end
	button:SetParent(Minimap)
	button:SetFrameStrata("HIGH")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 25)
	button:Show()
	PlaceMinimapButton(button, tonumber(db.minimapAngle) or 125)
end

local function FindProfile(text)
	local wanted = Plain(text)
	if wanted == "" then return nil end
	local char = CharDB()
	if not char then return nil end
	for index = 1, #char.order do
		if Plain(char.order[index]) == wanted then
			return char.order[index]
		end
	end
end

SLASH_PERFILES1 = "/perfiles"
SLASH_PERFILES2 = "/perfil"
SlashCmdList.PERFILES = function(message)
	if not started then return end
	local profileName = FindProfile(message or "")
	if profileName then
		editing = profileName
		if frame then frame:Show() end
		ApplyPrompt(profileName)
		return
	end
	Toggle()
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.PERFILES_APPLY = {
	text = "¿Aplicar este perfil y recargar la interfaz?",
	button1 = "Recargar",
	button2 = "Cancelar",
	OnAccept = function(self, data)
		if type(data) == "string" then Apply(data) end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
StaticPopupDialogs.PERFILES_NEW = {
	text = "Nombre del perfil nuevo",
	button1 = "Crear",
	button2 = "Cancelar",
	hasEditBox = true,
	maxLetters = 24,
	OnShow = function(self)
		local edit = self.editBox
		if not edit and self.GetName then edit = _G[self:GetName() .. "EditBox"] end
		if edit then
			edit:SetText("")
			edit:SetFocus()
		end
	end,
	OnAccept = function(self)
		local created = CreateProfile(DialogEditText(self))
		if frame and created ~= false then Refresh() end
	end,
	EditBoxOnEnterPressed = function(self)
		CreateProfile(self:GetText() or "")
		if frame then Refresh() end
		self:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
StaticPopupDialogs.PERFILES_DELETE = {
	text = "¿Borrar este perfil?",
	button1 = "Borrar",
	button2 = "Cancelar",
	OnAccept = function(self, data)
		if type(data) == "string" then
			DeleteProfile(data)
			if frame then Refresh() end
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function Startup()
	if started then
		EnsureMinimapButton()
		return
	end
	started = true
	BindDB()
	local _, created = CharDB()
	if not frame then MakeFrame() end
	EnsureMinimapButton()
	if created then
		Say("Perfiles 1.0.7 cargado. He creado Farmeo, JcJ, Mazmorras y Banda con los addons que tienes ahora. Quita los que no quieras en cada uno y pulsa Aplicar.")
	else
		local char = CharDB()
		Say("Perfiles 1.0.7 cargado. En uso: " .. (char and char.active or "Farmeo") .. ". El libro del minimapa abre el menú.")
	end
	if db.open and frame then frame:Show() end
	if C_Timer and C_Timer.After then
		C_Timer.After(1, EnsureMinimapButton)
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", Startup)
