-- Ventana con las webs útiles de Forever. Pulsar una imagen prepara su enlace para copiarlo.

local ADDON = "Herramientas"
local POPUP = "HERRAMIENTAS_URL"

local SITES = {
	{
		name = "TravelCraft",
		detail = "Rutas, viajes y entradas",
		url = "https://wow-travelcraft.com",
		image = "Interface\\AddOns\\Herramientas\\Media\\travelcraft",
	},
	{
		name = "Forever Changes",
		detail = "Cambios del servidor",
		url = "https://foreverchanges.pro",
		image = "Interface\\AddOns\\Herramientas\\Media\\changes",
	},
	{
		name = "Wowhead",
		detail = "Base de datos de Forever",
		url = "https://www.wowhead.com/forever",
		image = "Interface\\AddOns\\Herramientas\\Media\\wowhead",
	},
	{
		name = "MythicSim",
		detail = "Simulador de daño y equipo",
		url = "https://mythicsim.com",
		image = "Interface\\AddOns\\Herramientas\\Media\\mythicsim",
	},
	{
		name = "WoW Professions",
		detail = "Guías de profesiones",
		url = "https://www.wow-professions.com",
		image = "Interface\\AddOns\\Herramientas\\Media\\professions",
	},
	{
		name = "Everloot",
		detail = "Botín de banda",
		url = "https://everloot.app/tools/raid",
		image = "Interface\\AddOns\\Herramientas\\Media\\everloot",
	},
}

local db
local frame
local started

local function Say(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Herramientas|r: " .. text)
	end
end

local function BindDB()
	if type(_G.HerramientasDB) ~= "table" then
		_G.HerramientasDB = {}
	end
	db = _G.HerramientasDB
end

local function PopupBox(dialog)
	if dialog.editBox and dialog.editBox.GetText then return dialog.editBox end
	if dialog.GetName then
		local name = dialog:GetName()
		if name then
			return _G[name .. "WideEditBox"] or _G[name .. "EditBox"]
		end
	end
end

local function ShowPopup(site)
	local safeName = site.name
	local ok, cleaned = pcall(function()
		return site.name:gsub("%%", "")
	end)
	if ok and type(cleaned) == "string" and cleaned ~= "" then
		safeName = cleaned
	end
	StaticPopupDialogs[POPUP].text = safeName .. ".\nEl enlace está seleccionado: cópialo y ábrelo en el navegador."
	StaticPopupDialogs[POPUP].url = site.url
	local dialog = StaticPopup_Show(POPUP, nil, nil, site.url)
	if not dialog then
		Say(site.url)
	end
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs[POPUP] = {
	text = "El enlace está seleccionado: cópialo y ábrelo en el navegador.",
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

local function SavePoint(self)
	local point, _, relative, x, y = self:GetPoint()
	if type(point) ~= "string" or not db then return end
	db.point = point
	db.relative = type(relative) == "string" and relative or point
	local function Num(value)
		if type(value) ~= "number" then return 0 end
		local ok, number = pcall(function()
			return value + 0
		end)
		if ok and type(number) == "number" then return number end
		return 0
	end
	db.x = Num(x)
	db.y = Num(y)
end

local function MakeFrame()
	frame = CreateFrame("Frame", "HerramientasFrame", UIParent)
	frame:SetSize(640, 470)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePoint(self)
	end)
	if db and type(db.point) == "string" then
		frame:SetPoint(db.point, UIParent, db.relative or db.point, db.x or 0, db.y or 0)
	else
		frame:SetPoint("CENTER")
	end
	tinsert(UISpecialFrames, "HerramientasFrame")

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.07, 0.94)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Herramientas")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local info = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	info:SetPoint("TOPLEFT", 20, -40)
	info:SetPoint("TOPRIGHT", -36, -40)
	info:SetJustifyH("LEFT")
	info:SetText("Pulsa una imagen para copiar el enlace. Ábrelo después en el navegador.")

	local cardW, cardH = 190, 176
	local gapX, gapY = 14, 12
	for index = 1, #SITES do
		local site = SITES[index]
		local column = (index - 1) % 3
		local row = math.floor((index - 1) / 3)
		local card = CreateFrame("Button", nil, frame)
		card:SetSize(cardW, cardH)
		card:SetPoint("TOPLEFT", 20 + column * (cardW + gapX), -64 - row * (cardH + gapY))
		local cardBg = card:CreateTexture(nil, "BACKGROUND")
		cardBg:SetAllPoints()
		cardBg:SetColorTexture(0.12, 0.12, 0.15, 1)
		local image = card:CreateTexture(nil, "ARTWORK")
		image:SetSize(96, 96)
		image:SetPoint("TOP", 0, -14)
		image:SetTexture(site.image)
		local name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		name:SetPoint("TOP", image, "BOTTOM", 0, -8)
		name:SetText(site.name)
		local detail = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		detail:SetPoint("TOP", name, "BOTTOM", 0, -2)
		detail:SetWidth(cardW - 16)
		detail:SetJustifyH("CENTER")
		detail:SetText(site.detail)
		card:SetScript("OnClick", function()
			ShowPopup(site)
		end)
		card:SetScript("OnEnter", function(self)
			cardBg:SetColorTexture(0.28, 0.22, 0.08, 1)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(site.name)
			GameTooltip:AddLine(site.detail, 1, 1, 1)
			GameTooltip:AddLine(site.url, 0.7, 0.7, 0.7)
			GameTooltip:AddLine("Clic para copiar el enlace.", 1, 0.82, 0)
			GameTooltip:Show()
		end)
		card:SetScript("OnLeave", function()
			cardBg:SetColorTexture(0.12, 0.12, 0.15, 1)
			GameTooltip:Hide()
		end)
	end

	frame.ready = false
	frame:SetScript("OnShow", function(self)
		if self.ready and db then db.open = true end
	end)
	frame:SetScript("OnHide", function(self)
		if self.ready and db then db.open = false end
	end)
	frame:Hide()
	frame.ready = true
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
	local button = _G.HerramientasMinimapButton
	if not button then
		button = CreateFrame("Button", "HerramientasMinimapButton", Minimap)
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
		icon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
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
			GameTooltip:SetText("Herramientas")
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
	local angle = tonumber(db.minimapAngle) or 300
	PlaceMinimapButton(button, angle)
end

SLASH_HERRAMIENTAS1 = "/herramientas"
SLASH_HERRAMIENTAS2 = "/tools"
SlashCmdList.HERRAMIENTAS = function()
	Toggle()
end

local function Startup()
	if started then
		EnsureMinimapButton()
		return
	end
	started = true
	BindDB()
	if not frame then MakeFrame() end
	EnsureMinimapButton()
	Say("Herramientas 1.0.0 cargado. El mapa del minimapa abre las webs de Forever.")
	if db.open and frame then frame:Show() end
	if C_Timer and C_Timer.After then
		C_Timer.After(1, EnsureMinimapButton)
	end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", Startup)
