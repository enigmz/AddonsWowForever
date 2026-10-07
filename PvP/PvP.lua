-- Marca en el mapa del mundo dónde apuntarse a cada campo de batalla de Forever.
-- Solo la facción del personaje. El pin va en el lienzo del mapa, no como punto de ruta.

local BATTLEGROUNDS = {
	{
		key = "wsg",
		name = "Garganta Grito de Guerra",
		detail = "10 contra 10. Desde nivel 10.",
		icon = "Interface\\Icons\\INV_Misc_Head_Orc_01",
		spots = {
			{ faction = "A", map = 63, x = 0.619, y = 0.838, place = "Arboleda Ala de Plata, Vallefresno", who = "Su'ura Swiftarrow", kind = "entrada" },
			{ faction = "A", map = 84, x = 0.811, y = 0.385, place = "Ventormenta", who = "Elfarran", kind = "ciudad" },
			{ faction = "A", map = 87, x = 0.699, y = 0.897, place = "Forjaz", who = "Lylandris", kind = "ciudad" },
			{ faction = "A", map = 89, x = 0.584, y = 0.345, place = "Darnassus", who = "Aethalas", kind = "ciudad" },
			{ faction = "H", map = 10, x = 0.467, y = 0.087, place = "Campamento Mor'shan, Los Baldíos", who = "Gargok", kind = "entrada" },
			{ faction = "H", map = 85, x = 0.801, y = 0.305, place = "Orgrimmar", who = "Brakgul Deathbringer", kind = "ciudad" },
			{ faction = "H", map = 90, x = 0.583, y = 0.979, place = "Entrañas", who = "Kurden Bloodclaw", kind = "ciudad" },
			{ faction = "H", map = 88, x = 0.574, y = 0.766, place = "Cima del Trueno", who = "Kergul Bloodaxe", kind = "ciudad" },
		},
	},
	{
		key = "ab",
		name = "Cuenca de Arathi",
		detail = "15 contra 15. Desde nivel 20.",
		icon = "Interface\\Icons\\INV_Jewelry_Talisman_07",
		spots = {
			{ faction = "A", map = 14, x = 0.457, y = 0.457, place = "Refugio de la Zaga, Tierras Altas de Arathi", who = "Radulf Leder", kind = "entrada" },
			{ faction = "A", map = 84, x = 0.811, y = 0.385, place = "Ventormenta", who = "Lady Hoteshem", kind = "ciudad" },
			{ faction = "A", map = 87, x = 0.699, y = 0.897, place = "Forjaz", who = "Donal Osgood", kind = "ciudad" },
			{ faction = "A", map = 89, x = 0.584, y = 0.345, place = "Darnassus", who = "Keras Wolfheart", kind = "ciudad" },
			{ faction = "H", map = 14, x = 0.735, y = 0.291, place = "Sentencia, Tierras Altas de Arathi", who = "The Black Bride", kind = "entrada" },
			{ faction = "H", map = 85, x = 0.801, y = 0.305, place = "Orgrimmar", who = "Deze Snowbane", kind = "ciudad" },
			{ faction = "H", map = 90, x = 0.583, y = 0.979, place = "Entrañas", who = "Maestro de batalla", kind = "ciudad" },
			{ faction = "H", map = 88, x = 0.574, y = 0.766, place = "Cima del Trueno", who = "Maestro de batalla", kind = "ciudad" },
		},
	},
	{
		key = "av",
		name = "Valle de Alterac",
		detail = "40 contra 40. Niveles 51 a 60.",
		icon = "Interface\\Icons\\INV_Hammer_16",
		spots = {
			{ faction = "A", map = 1416, x = 0.393, y = 0.823, place = "El Promontorio, Montañas de Alterac", who = "Grumbol Grimhammer", kind = "entrada" },
			{ faction = "A", map = 84, x = 0.811, y = 0.385, place = "Ventormenta", who = "Thelman Slatefist", kind = "ciudad" },
			{ faction = "A", map = 87, x = 0.699, y = 0.897, place = "Forjaz", who = "Glordrum Steelbeard", kind = "ciudad" },
			{ faction = "A", map = 89, x = 0.584, y = 0.345, place = "Darnassus", who = "Brogun Stoneshield", kind = "ciudad" },
			{ faction = "H", map = 1416, x = 0.631, y = 0.599, place = "Entrada de la Horda, Montañas de Alterac", who = "Maestro de batalla", kind = "entrada" },
			{ faction = "H", map = 85, x = 0.801, y = 0.305, place = "Orgrimmar", who = "Kartra Bloodsnarl", kind = "ciudad" },
			{ faction = "H", map = 90, x = 0.583, y = 0.979, place = "Entrañas", who = "Grizzle Halfmane", kind = "ciudad" },
			{ faction = "H", map = 88, x = 0.574, y = 0.766, place = "Cima del Trueno", who = "Taim Ragetotem", kind = "ciudad" },
		},
	},
	{
		key = "ds",
		name = "Islas Lanza Negra",
		detail = "15 contra 15. Desde nivel 30.",
		icon = "Interface\\Icons\\Spell_Nature_StormReach",
		spots = {
			{ faction = "A", map = 84, x = 0.810, y = 0.386, place = "Ventormenta", who = "James Battlewing", kind = "ciudad" },
			{ faction = "A", map = 87, x = 0.699, y = 0.897, place = "Forjaz", who = "Sean Guardoff", kind = "ciudad" },
			{ faction = "A", map = 89, x = 0.584, y = 0.345, place = "Darnassus", who = "Pherry Leftee", kind = "ciudad" },
			{ faction = "H", map = 85, x = 0.796, y = 0.306, place = "Orgrimmar", who = "Gruga Bloodblade", kind = "ciudad" },
			{ faction = "H", map = 90, x = 0.600, y = 0.868, place = "Entrañas", who = "Rugbul Boomfirst", kind = "ciudad" },
			{ faction = "H", map = 88, x = 0.570, y = 0.768, place = "Cima del Trueno", who = "Borook Gallfist", kind = "ciudad" },
		},
	},
}

local db
local frame
local selected
local pins = {}

local function SafeNumber(value)
	if type(value) ~= "number" then return nil end
	local ok, number = pcall(function()
		return value + 0
	end)
	if ok and type(number) == "number" then return number end
end

local function Faction()
	if not UnitFactionGroup then return nil end
	local ok, token = pcall(UnitFactionGroup, "player")
	if not ok then return nil end
	if token == "Alliance" then return "A" end
	if token == "Horde" then return "H" end
end

local function Battleground(key)
	for index = 1, #BATTLEGROUNDS do
		if BATTLEGROUNDS[index].key == key then return BATTLEGROUNDS[index] end
	end
end

local function SpotsFor(bg)
	local side = Faction()
	local list = {}
	if not bg then return list end
	for index = 1, #bg.spots do
		local spot = bg.spots[index]
		if not side or spot.faction == side then
			list[#list + 1] = spot
		end
	end
	return list
end

local function FirstSpot(bg)
	local list = SpotsFor(bg)
	for index = 1, #list do
		if list[index].kind == "entrada" then return list[index] end
	end
	return list[1]
end

local function Canvas()
	if not WorldMapFrame then return nil end
	if type(WorldMapFrame.GetCanvas) == "function" then
		local ok, canvas = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
		if ok and canvas then return canvas end
	end
	if WorldMapFrame.ScrollContainer then
		return WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
	end
end

local function CurrentMap()
	if not WorldMapFrame or type(WorldMapFrame.GetMapID) ~= "function" then return nil end
	local ok, mapID = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
	if ok then return SafeNumber(mapID) end
end

local function HidePins()
	for index = 1, #pins do
		pins[index]:Hide()
	end
end

local function PlacePin(pin, parent, spot)
	if pin:GetParent() ~= parent then
		pin:SetParent(parent)
	end
	pin.spot = spot
	pin.icon:SetTexture(selected and selected.icon or "Interface\\Icons\\INV_BannerPVP_02")
	local placed = false
	if WorldMapFrame and type(WorldMapFrame.SetPinPosition) == "function" then
		placed = pcall(WorldMapFrame.SetPinPosition, WorldMapFrame, pin, spot.x, spot.y)
	end
	if not placed then
		local width, height = parent:GetWidth(), parent:GetHeight()
		width = SafeNumber(width)
		height = SafeNumber(height)
		if not width or not height or width <= 1 or height <= 1 then
			pin:Hide()
			return
		end
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", parent, "TOPLEFT", width * spot.x, -height * spot.y)
	end
	pin:Show()
end

local function EnsurePin(index)
	local pin = pins[index]
	if pin then return pin end
	local parent = Canvas() or UIParent
	pin = CreateFrame("Button", nil, parent)
	pin:SetSize(26, 26)
	pin:SetFrameLevel(9000)
	pin:EnableMouse(true)
	local icon = pin:CreateTexture(nil, "OVERLAY")
	icon:SetAllPoints()
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pin.icon = icon
	pin:SetScript("OnEnter", function(self)
		local spot = self.spot
		if not spot or not selected then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(spot.who)
		GameTooltip:AddLine(spot.place, 1, 0.82, 0.2)
		GameTooltip:AddLine("Aquí te apuntas a " .. selected.name .. ".", 0.6, 0.9, 1)
		GameTooltip:Show()
	end)
	pin:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	pin:Hide()
	pins[index] = pin
	return pin
end

local function RefreshPins()
	local parent = Canvas()
	local mapID = CurrentMap()
	local shown = WorldMapFrame and WorldMapFrame:IsShown()
	if not shown or not parent or not mapID or not selected then
		HidePins()
		return
	end
	local list = SpotsFor(selected)
	local used = 0
	for index = 1, #list do
		local spot = list[index]
		if spot.map == mapID then
			used = used + 1
			PlacePin(EnsurePin(used), parent, spot)
		end
	end
	for index = used + 1, #pins do
		pins[index]:Hide()
	end
end

local function OpenMap(mapID)
	if not WorldMapFrame then return end
	if not WorldMapFrame:IsShown() and ToggleWorldMap then
		ToggleWorldMap()
	end
	mapID = SafeNumber(mapID)
	if mapID and type(WorldMapFrame.SetMapID) == "function" then
		pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
	end
	RefreshPins()
end

local function ShowSpot(spot)
	if not spot then return end
	OpenMap(spot.map)
end

local function Paint()
	if not frame then return end
	local side = Faction()
	if side == "A" then
		frame.info:SetText("Puntos de la Alianza. Elige un campo y se marca en su mapa.")
	elseif side == "H" then
		frame.info:SetText("Puntos de la Horda. Elige un campo y se marca en su mapa.")
	else
		frame.info:SetText("Elige un campo. Se marcan la entrada y las ciudades.")
	end
	for index = 1, #BATTLEGROUNDS do
		local bg = BATTLEGROUNDS[index]
		local row = frame.rows[index]
		local on = selected and selected.key == bg.key
		row.name:SetTextColor(on and 1 or 1, on and 0.82 or 0.82, on and 0.2 or 0.2)
	end
	local list = SpotsFor(selected)
	for index = 1, #frame.spots do
		local button = frame.spots[index]
		local spot = list[index]
		if spot then
			local kind = spot.kind == "entrada" and "Entrada" or "Ciudad"
			button:SetText(kind .. ": " .. spot.place)
			button.spot = spot
			button:Show()
		else
			button.spot = nil
			button:Hide()
		end
	end
end

local function SelectBattleground(bg)
	selected = bg
	if db then db.key = bg and bg.key or nil end
	Paint()
	ShowSpot(FirstSpot(bg))
end

local function SavePoint(self)
	local point, _, relative, x, y = self:GetPoint()
	if type(point) ~= "string" then return end
	db.point = point
	db.relative = type(relative) == "string" and relative or point
	db.x = SafeNumber(x) or 0
	db.y = SafeNumber(y) or 0
end

local function MakeFrame()
	frame = CreateFrame("Frame", "PvPFrame", UIParent)
	frame:SetSize(440, 520)
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePoint(self)
	end)
	if db.point then
		frame:SetPoint(db.point, UIParent, db.relative or db.point, db.x or 0, db.y or 0)
	else
		frame:SetPoint("CENTER")
	end
	tinsert(UISpecialFrames, "PvPFrame")

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.07, 0.92)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -12)
	title:SetText("PvP")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	info:SetPoint("TOPLEFT", 16, -40)
	info:SetPoint("TOPRIGHT", -16, -40)
	info:SetJustifyH("LEFT")
	info:SetHeight(32)
	frame.info = info

	frame.rows = {}
	for index = 1, #BATTLEGROUNDS do
		local battleground = BATTLEGROUNDS[index]
		local row = CreateFrame("Button", nil, frame)
		row:SetSize(408, 44)
		row:SetPoint("TOPLEFT", 16, -76 - (index - 1) * 48)
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(28, 28)
		icon:SetPoint("LEFT", 4, 0)
		icon:SetTexture(battleground.icon)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 2)
		name:SetText(battleground.name)
		row.name = name
		local detail = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		detail:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
		detail:SetText(battleground.detail)
		row:SetScript("OnClick", function()
			SelectBattleground(battleground)
		end)
		frame.rows[index] = row
	end

	frame.spots = {}
	for index = 1, 4 do
		local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		button:SetSize(408, 22)
		button:SetPoint("TOPLEFT", 16, -276 - (index - 1) * 26)
		button:SetScript("OnClick", function(self)
			ShowSpot(self.spot)
		end)
		button:Hide()
		frame.spots[index] = button
	end

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 16, 14)
	hint:SetPoint("BOTTOMRIGHT", -16, 14)
	hint:SetJustifyH("CENTER")
	hint:SetHeight(32)
	if hint.SetSpacing then hint:SetSpacing(2) end
	hint:SetText("La entrada es el campo. La ciudad es el maestro de batalla.\nEl pin solo se ve en el mapa de esa zona.")

	frame.ready = false
	frame:SetScript("OnShow", function(self)
		if self.ready then db.open = true end
		Paint()
		RefreshPins()
	end)
	frame:SetScript("OnHide", function(self)
		if self.ready then db.open = false end
	end)
	frame:Hide()
	frame.ready = true
end

local function Toggle()
	if not frame then return end
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
	if _G.PvPMinimapButton or not Minimap or not db then return end
	local button = CreateFrame("Button", "PvPMinimapButton", Minimap)
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
	icon:SetTexture("Interface\\Icons\\INV_BannerPVP_02")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("CENTER", 1, 0)

	local angle = tonumber(db.minimapAngle) or 40
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
		GameTooltip:SetText("PvP")
		GameTooltip:AddLine("Clic para ver dónde apuntarte. Arrastra para moverlo.", 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

SLASH_PVPFOREVER1 = "/pvp"
SlashCmdList.PVPFOREVER = function()
	Toggle()
end

local told = false
local elapsed = 0
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg ~= "PvP" then return end
	PvPDB = PvPDB or {}
	db = PvPDB
	if not frame then MakeFrame() end
	EnsureMinimapButton()
	if db.key then selected = Battleground(db.key) end
	if event == "PLAYER_LOGIN" and not told and DEFAULT_CHAT_FRAME then
		told = true
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100PvP|r cargado. El botón del minimapa marca dónde apuntarte a cada campo.")
		if db.open ~= false then frame:Show() end
	end
	Paint()
end)
watcher:SetScript("OnUpdate", function(_, delta)
	elapsed = elapsed + delta
	if elapsed < 0.25 then return end
	elapsed = 0
	if selected and WorldMapFrame and WorldMapFrame:IsShown() then
		RefreshPins()
	else
		HidePins()
	end
end)
