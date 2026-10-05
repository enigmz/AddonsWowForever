-- La capa sale del identificador de zona que el cliente pone en cada criatura.
-- No hay forma de saltar a una capa: alguien que ya está allí tiene que invitarte.
-- Mientras sigues en su grupo estás en su capa. Al salir, vuelves a la tuya.

local PREFIX = "CAPA"
local FRESH = 180

local db
local peers = {}
local guildToken
local currentId
local currentZone
local label, panel
local rows = {}
local host = true

local function UsableString(value)
	if type(value) ~= "string" or value == "" then return nil end
	local ok = pcall(function()
		return value .. ""
	end)
	if ok then return value end
end

local function UsableNumber(value)
	if type(value) ~= "number" then return nil end
	local ok, number = pcall(function()
		return value + 0
	end)
	if ok and type(number) == "number" then return number end
end

local function ShortName(name)
	name = UsableString(name)
	if not name then return nil end
	return name:match("^([^%-]+)") or name
end

local function MyName()
	return ShortName(UnitName and UnitName("player"))
end

local function Now()
	return GetTime and GetTime() or 0
end

local function Say(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cff7ec8ffCapa:|r " .. text)
	end
end

local function ZoneKey()
	local map
	if C_Map and C_Map.GetBestMapForUnit then
		local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
		if ok then map = UsableNumber(id) end
	end
	if map then return "mapa:" .. map end
	local name = UsableString(GetZoneText and GetZoneText())
	if name then return "zona:" .. name end
	return "aqui"
end

local function ZoneName()
	return UsableString(GetZoneText and GetZoneText()) or "esta zona"
end

local function ZoneUID(unit)
	if not unit or not UnitExists or not UnitExists(unit) or not UnitGUID then return nil end
	local ok, guid = pcall(UnitGUID, unit)
	if not ok then return nil end
	guid = UsableString(guid)
	if not guid then return nil end
	local kind, _, _, _, zoneUID = strsplit("-", guid)
	if kind ~= "Creature" and kind ~= "Vehicle" and kind ~= "GameObject" then return nil end
	zoneUID = tonumber(zoneUID)
	if zoneUID and zoneUID > 0 then return zoneUID end
end

local function RememberId(zone, id)
	if not zone or not id then return end
	db.zones[zone] = db.zones[zone] or {}
	local list = db.zones[zone]
	for index = 1, #list do
		if list[index] == id then return end
	end
	list[#list + 1] = id
	table.sort(list)
end

local function IdsIn(zone)
	local list = {}
	local saved = zone and db.zones[zone]
	if saved then
		for index = 1, #saved do
			list[#list + 1] = saved[index]
		end
	end
	return list
end

local function LetterFor(zone, id)
	local list = IdsIn(zone)
	for index = 1, #list do
		if list[index] == id then
			if index <= 26 then return string.char(64 + index) end
			return tostring(index)
		end
	end
end

local function IdForLetter(zone, letter)
	letter = UsableString(letter)
	if not letter then return nil end
	letter = letter:upper()
	local list = IdsIn(zone)
	for index = 1, #list do
		local name = index <= 26 and string.char(64 + index) or tostring(index)
		if name == letter then return list[index] end
	end
	local asNumber = tonumber(letter)
	if not asNumber then return nil end
	for index = 1, #list do
		if list[index] == asNumber then return list[index] end
	end
end

local function EachUnit(fn)
	fn("target")
	fn("mouseover")
	fn("softinteract")
	fn("focus")
	if C_NamePlate and C_NamePlate.GetNamePlates then
		local ok, plates = pcall(C_NamePlate.GetNamePlates)
		if ok and type(plates) == "table" then
			for _, plate in pairs(plates) do
				if plate then
					local unit
					pcall(function()
						unit = plate.namePlateUnitToken or plate.namePlateUnitID
					end)
					unit = UsableString(unit)
					if unit then fn(unit) end
				end
			end
		end
	end
	for index = 1, 40 do
		local plate = _G["NamePlate" .. index]
		if plate and plate.IsShown and plate:IsShown() then
			local unit
			pcall(function()
				unit = plate.namePlateUnitToken or plate.namePlateUnitID
			end)
			unit = UsableString(unit)
			if unit then fn(unit) end
		end
	end
end

local function LayerChannel()
	if not GetChannelName then return nil end
	local names = { "layer", "Layer" }
	for index = 1, #names do
		local ok, id = pcall(GetChannelName, names[index])
		id = ok and UsableNumber(id)
		if id and id > 0 then return id end
	end
end

local joinTried = false

local function EnsureChannel()
	local id = LayerChannel()
	if id then return id end
	if joinTried then return nil end
	joinTried = true
	if JoinChannelByName and not (InCombatLockdown and InCombatLockdown()) then
		pcall(JoinChannelByName, "layer")
	end
	return LayerChannel()
end

local function SendAddon(text, channel, target)
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		pcall(C_ChatInfo.SendAddonMessage, PREFIX, text, channel, target)
	elseif SendAddonMessage then
		pcall(SendAddonMessage, PREFIX, text, channel, target)
	end
end

local function Announce()
	if not currentId then return end
	local place = (ZoneName() or ""):gsub(";", " ")
	local text = "AT;" .. currentId .. ";" .. currentZone .. ";" .. place
	SendAddon(text, "GUILD")
	local channel = EnsureChannel()
	if channel then SendAddon(text, "CHANNEL", channel) end
end

local function FreshPeers()
	local list, now = {}, Now()
	for name, peer in pairs(peers) do
		if now - peer.at <= FRESH then
			list[#list + 1] = peer
			list[#list].name = name
		else
			peers[name] = nil
		end
	end
	table.sort(list, function(a, b)
		return a.at > b.at
	end)
	return list
end

local function PeerOn(id)
	local mine = MyName()
	local found
	for _, peer in ipairs(FreshPeers()) do
		if peer.id == id and peer.zone == currentZone and peer.name ~= mine then
			if not found or peer.at > found.at then found = peer end
		end
	end
	return found
end

local function CanInvite()
	if InCombatLockdown and InCombatLockdown() then return false, "sal de combate para invitar" end
	if IsInInstance then
		local ok, inside, kind = pcall(IsInInstance)
		if ok and inside and kind and kind ~= "none" then return false, "no se puede desde una estancia" end
	end
	if IsInRaid and IsInRaid() then return false, "no se puede desde una banda" end
	if IsInGroup and IsInGroup() and UnitIsGroupLeader and not UnitIsGroupLeader("player") then
		return false, "no eres el líder del grupo"
	end
	if GetNumGroupMembers and IsInGroup and IsInGroup() and GetNumGroupMembers() >= 5 then
		return false, "el grupo está lleno"
	end
	return true
end

local function AskChat(letter)
	local channel = EnsureChannel()
	if not channel then
		Say("Entra en el canal con /join layer y vuelve a pedirlo.")
		return false
	end
	local text = letter and ("inv layer " .. letter) or "inv layer"
	local ok = pcall(SendChatMessage, text, "CHANNEL", nil, channel)
	if not ok then
		Say("No he podido escribir en el canal layer.")
		return false
	end
	Say("He pedido una invitación en el canal layer. Acéptala: sigues en esa capa mientras estés en el grupo.")
	return true
end

local function AskLayer(id)
	if not id then
		AskChat(nil)
		return
	end
	if id == currentId then
		Say("Ya estás en esa capa.")
		return
	end
	local peer = PeerOn(id)
	if peer then
		SendAddon("ASK;" .. id, "WHISPER", peer.full or peer.name)
		Say("He pedido a " .. peer.name .. " que te invite a la capa " .. id .. ". Acepta la invitación.")
		return
	end
	local letter = LetterFor(currentZone, id)
	Say("Nadie con este addon está ahora en la capa " .. id .. ". Pido en el canal layer" .. (letter and (" como capa " .. letter) or "") .. ".")
	AskChat(letter)
end

local function NotePeer(sender, id, zone, place, fromGuild)
	local full = UsableString(sender)
	local name = ShortName(full)
	id = tonumber(id)
	zone = UsableString(zone)
	place = UsableString(place)
	if not name or name == MyName() or not id or not zone then return end
	local previous = peers[name]
	peers[name] = {
		id = id,
		zone = zone,
		place = place,
		at = Now(),
		full = full,
		guild = fromGuild or (previous and previous.guild) or false,
	}
	if zone == currentZone then RememberId(zone, id) end
end

local function InGuild()
	if not IsInGuild then return false end
	local ok, inside = pcall(IsInGuild)
	return ok and inside and true or false
end

local function GuildNames()
	local names = {}
	if not InGuild() then return names end
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		pcall(C_GuildInfo.GuildRoster)
	elseif _G.GuildRoster then
		pcall(_G.GuildRoster)
	end
	local count = GetNumGuildMembers and GetNumGuildMembers() or 0
	for index = 1, count do
		local name = GetGuildRosterInfo(index)
		name = ShortName(name)
		if name then names[name] = true end
	end
	return names
end

local function LayerText(zone, id)
	local letter = LetterFor(zone, id)
	if letter then return "capa " .. letter .. " (" .. id .. ")" end
	return "capa " .. id
end

local function PrintGuildLayers()
	if not InGuild() then
		Say("No estás en una hermandad.")
		return
	end
	if currentId then
		Say("Tú: " .. LayerText(currentZone, currentId) .. ", " .. ZoneName() .. ".")
	else
		Say("Tu capa aún no se ve. Mira a un NPC.")
	end
	local roster = GuildNames()
	local groups, order = {}, {}
	local now = Now()
	for _, peer in ipairs(FreshPeers()) do
		if peer.guild or roster[peer.name] then
			local key = tostring(peer.id) .. "\t" .. (peer.place or peer.zone or "")
			local group = groups[key]
			if not group then
				group = { id = peer.id, zone = peer.zone, place = peer.place, names = {} }
				groups[key] = group
				order[#order + 1] = group
			end
			local ago = math.max(0, math.floor(now - peer.at))
			local when = ago < 60 and (ago .. " s") or (math.floor(ago / 60) .. " min")
			group.names[#group.names + 1] = peer.name .. " (" .. when .. ")"
		end
	end
	table.sort(order, function(a, b)
		return a.id < b.id
	end)
	if #order == 0 then
		Say("Nadie más de la hermandad con Capa ha informado su capa.")
		return
	end
	for index = 1, #order do
		local group = order[index]
		local where = group.place or "otra zona"
		Say(LayerText(group.zone, group.id) .. " · " .. where .. ": " .. table.concat(group.names, ", "))
	end
end

local function AskGuild()
	if not InGuild() then
		Say("No estás en una hermandad.")
		return
	end
	SendAddon("PING", "GUILD")
	Announce()
	local token = {}
	guildToken = token
	Say("Preguntando a la hermandad...")
	if C_Timer and C_Timer.After then
		C_Timer.After(1.2, function()
			if guildToken ~= token then return end
			PrintGuildLayers()
		end)
	else
		PrintGuildLayers()
	end
end

local function OnAddon(prefix, text, channel, sender)
	if prefix ~= PREFIX then return end
	text = UsableString(text)
	if not text then return end
	local kind, first, second, third = strsplit(";", text)
	if kind == "PING" then
		if channel == "GUILD" then Announce() end
		return
	end
	if kind == "AT" then
		NotePeer(sender, first, second, third, channel == "GUILD")
		if panel and panel:IsShown() and panel.Refresh then panel:Refresh() end
		return
	end
	if kind ~= "ASK" or not host then return end
	local wanted = tonumber(first)
	local who = UsableString(sender)
	local name = ShortName(who)
	if not wanted or not name or name == MyName() then return end
	if wanted ~= currentId then return end
	local allowed, reason = CanInvite()
	if not allowed then
		SendAddon("NO;" .. (reason or "no"), "WHISPER", who)
		return
	end
	local ok = pcall(InviteUnit, who)
	if ok then
		Say("He invitado a " .. name .. " a esta capa.")
	else
		SendAddon("NO;no he podido invitar", "WHISPER", who)
	end
end

local function Scan()
	local zone = ZoneKey()
	local seen, best, bestCount = {}, nil, 0
	EachUnit(function(unit)
		local id = ZoneUID(unit)
		if not id then return end
		seen[id] = (seen[id] or 0) + 1
		if seen[id] > bestCount then
			best = id
			bestCount = seen[id]
		end
	end)
	if zone ~= currentZone then
		currentZone = zone
		currentId = nil
	end
	if not best then return end
	RememberId(zone, best)
	if best ~= currentId then
		currentId = best
		local letter = LetterFor(zone, best)
		Say("Estás en la capa " .. (letter or "?") .. " (" .. best .. ") de " .. ZoneName() .. ".")
		Announce()
	end
	if label then
		local letter = LetterFor(zone, currentId)
		label:SetText("Capa " .. (letter or "?") .. "  " .. currentId)
	end
end

local function PaintLabel()
	if not label then return end
	if not currentId then
		label:SetText("Capa: mira a un NPC")
		return
	end
	local letter = LetterFor(currentZone, currentId)
	label:SetText("Capa " .. (letter or "?") .. "  " .. currentId)
end

local function MakeLabel()
	label = CreateFrame("Button", "CapaLabel", UIParent)
	label:SetSize(220, 22)
	label:SetFrameStrata("MEDIUM")
	label:SetMovable(true)
	label:RegisterForDrag("LeftButton")
	label:SetScript("OnDragStart", function(self)
		self.dragging = true
		self:StartMoving()
	end)
	label:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relative, x, y = self:GetPoint()
		db.point, db.relative, db.x, db.y = point, relative, x, y
		self.dragging = false
	end)
	if db.point then
		label:SetPoint(db.point, UIParent, db.relative or db.point, db.x or 0, db.y or 0)
	else
		label:SetPoint("TOP", UIParent, "TOP", 0, -100)
	end
	local font = label:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	font:SetAllPoints()
	local file = font:GetFont()
	if file then font:SetFont(file, 14, "OUTLINE") end
	label:SetFontString(font)
	label:SetScript("OnClick", function(self)
		if self.dragging then return end
		if panel:IsShown() then panel:Hide() else panel:Show() end
	end)
	PaintLabel()
end

local function MakePanel()
	panel = CreateFrame("Frame", "CapaFrame", UIParent)
	panel:SetSize(360, 280)
	panel:SetPoint("CENTER")
	panel:SetFrameStrata("DIALOG")
	panel:SetMovable(true)
	panel:EnableMouse(true)
	panel:RegisterForDrag("LeftButton")
	panel:SetScript("OnDragStart", panel.StartMoving)
	panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
	panel:Hide()
	tinsert(UISpecialFrames, "CapaFrame")

	local bg = panel:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.07, 0.92)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -12)
	title:SetText("Capa")

	local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local info = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	info:SetPoint("TOPLEFT", 16, -40)
	info:SetPoint("TOPRIGHT", -16, -40)
	info:SetJustifyH("LEFT")
	info:SetJustifyV("TOP")
	info:SetHeight(48)
	panel.info = info

	local any = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	any:SetSize(150, 22)
	any:SetPoint("TOPLEFT", 16, -96)
	any:SetText("Pedir otra capa")
	any:SetScript("OnClick", function()
		AskLayer(nil)
	end)

	local hostButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	hostButton:SetSize(150, 22)
	hostButton:SetPoint("LEFT", any, "RIGHT", 8, 0)
	hostButton:SetScript("OnClick", function()
		host = not host
		db.host = host
		panel:Refresh()
	end)
	panel.hostButton = hostButton

	local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 16, 12)
	hint:SetPoint("BOTTOMRIGHT", -16, 12)
	hint:SetJustifyH("LEFT")
	hint:SetText("La letra es de este personaje. El número es la capa de verdad. Acepta tú la invitación.")

	for index = 1, 6 do
		local row = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		row:SetSize(328, 20)
		row:SetPoint("TOPLEFT", 16, -126 - (index - 1) * 22)
		row:SetScript("OnClick", function(self)
			if self.layerId then AskLayer(self.layerId) end
		end)
		row:Hide()
		rows[index] = row
	end

	function panel:Refresh()
		local letter = currentId and LetterFor(currentZone, currentId)
		if currentId then
			info:SetText("Estás en la capa " .. (letter or "?") .. " (" .. currentId .. "), " .. ZoneName() .. ".")
		else
			info:SetText("Todavía no la veo. Selecciona o pasa el ratón por un NPC.")
		end
		hostButton:SetText(host and "Anfitrión: sí" or "Anfitrión: no")
		local shown = 0
		local list = IdsIn(currentZone)
		for index = 1, #list do
			if shown >= #rows then break end
			local id = list[index]
			local row = rows[shown + 1]
			local mark = LetterFor(currentZone, id) or "?"
			local people = 0
			for _, peer in ipairs(FreshPeers()) do
				if peer.id == id and peer.zone == currentZone then people = people + 1 end
			end
			if id == currentId then
				row.layerId = nil
				row:SetText("Capa " .. mark .. "  " .. id .. "  (esta)")
				row:Disable()
			else
				row.layerId = id
				local extra = people > 0 and ("  ·  " .. people .. " con el addon") or ""
				row:SetText("Pedir capa " .. mark .. "  " .. id .. extra)
				row:Enable()
			end
			row:Show()
			shown = shown + 1
		end
		for index = shown + 1, #rows do
			rows[index].layerId = nil
			rows[index]:Hide()
		end
	end

	panel:SetScript("OnShow", function(self)
		Announce()
		self:Refresh()
	end)
end

local function Toggle()
	if panel:IsShown() then panel:Hide() else panel:Show() end
end

local function HandleSlash(message)
	message = UsableString(message) or ""
	message = message:gsub("^%s+", ""):gsub("%s+$", "")
	local word, rest = message:match("^(%S+)%s*(.*)$")
	word = word and word:lower()
	if not word or word == "" or word == "mostrar" then
		Toggle()
		return
	end
	if word == "ayuda" then
		Say("/capa  ·  /capa hermandad  ·  /capa pedir  ·  /capa B  ·  /capa 2105  ·  /capa anfitrion")
		return
	end
	if word == "hermandad" or word == "guild" or word == "gremio" then
		AskGuild()
		return
	end
	if word == "anfitrion" or word == "anfitrión" then
		host = not host
		db.host = host
		Say(host and "Anfitrión activado: invitaré a quien pida esta capa." or "Anfitrión apagado.")
		if panel:IsShown() then panel:Refresh() end
		return
	end
	if word == "pedir" and (not rest or rest == "") then
		AskLayer(nil)
		return
	end
	local token = (word == "pedir" and rest ~= "" and rest) or word
	local id = tonumber(token)
	if not id or id < 100 then
		id = IdForLetter(currentZone, token)
	end
	if not id then
		Say("No conozco esa capa. Mira a un NPC o usa /capa pedir.")
		return
	end
	AskLayer(id)
end

local elapsed, announced = 0, 0
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
watcher:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
watcher:RegisterEvent("NAME_PLATE_UNIT_ADDED")
watcher:RegisterEvent("CHAT_MSG_ADDON")
watcher:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		CapaDB = CapaDB or {}
		db = CapaDB
		db.zones = db.zones or {}
		if db.host == nil then db.host = true end
		host = db.host and true or false
		if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
			pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
		elseif RegisterAddonMessagePrefix then
			pcall(RegisterAddonMessagePrefix, PREFIX)
		end
		MakePanel()
		MakeLabel()
		EnsureChannel()
		Scan()
		return
	end
	if event == "CHAT_MSG_ADDON" then
		OnAddon(...)
		return
	end
	Scan()
	PaintLabel()
end)
watcher:SetScript("OnUpdate", function(_, delta)
	elapsed = elapsed + delta
	announced = announced + delta
	if elapsed >= 0.5 then
		elapsed = 0
		Scan()
		PaintLabel()
	end
	if announced >= 20 then
		announced = 0
		Announce()
	end
end)

SLASH_CAPA1 = "/capa"
SlashCmdList.CAPA = HandleSlash
