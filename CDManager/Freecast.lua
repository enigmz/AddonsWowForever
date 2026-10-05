-- Lista de cortes, controles, defensivos y ofensivos.
-- No lee placas ni el registro de combate: en este cliente eso bloquea el addon.
-- Sigue al objetivo, al foco, al grupo y a los jefes.
-- LIBRE sale cuando el corte de ese jugador está en recuperación.
-- Prueba: también los aliados. Pasar a false cuando ya no haga falta.
local SHOW_ALLIES = true

local SPELLS = {
	kick = { id = 1766, cd = 10, kind = "interrupt", names = { "kick", "patada" } },
	pummel = { id = 6552, cd = 10, kind = "interrupt", names = { "pummel", "zurrar" } },
	shieldbash = { id = 72, cd = 12, kind = "interrupt", names = { "shield bash", "azote con escudo" } },
	counterspell = { id = 2139, cd = 30, kind = "interrupt", names = { "counterspell", "contrahechizo" } },
	earthshock = { id = 8042, cd = 6, kind = "interrupt", names = { "earth shock", "choque de tierra" } },
	windshear = { id = 57994, cd = 12, kind = "interrupt", names = { "wind shear", "corte de viento" } },
	spelllock = { id = 19647, cd = 24, kind = "interrupt", names = { "spell lock", "bloqueo de hechizo" } },
	silence = { id = 15487, cd = 45, kind = "interrupt", names = { "silence", "silencio" } },
	hoj = { id = 853, cd = 60, kind = "stun", names = { "hammer of justice", "martillo de justicia" } },
	kidney = { id = 408, cd = 20, kind = "stun", names = { "kidney shot", "golpe en los rinones" } },
	bash = { id = 5211, cd = 60, kind = "stun", names = { "bash", "machaque" } },
	warstomp = { id = 20549, cd = 120, kind = "stun", names = { "war stomp", "pisoton de guerra" } },
	scream = { id = 8122, cd = 30, kind = "fear", names = { "psychic scream", "alarido psiquico" } },
	howl = { id = 5484, cd = 40, kind = "fear", names = { "howl of terror", "aullido de terror" } },
	shout = { id = 5246, cd = 180, kind = "fear", names = { "intimidating shout", "grito intimidador" } },
	fear = { id = 5782, cd = 0, kind = "fear", names = { "fear", "miedo" } },
	rage = { id = 18499, cd = 30, kind = "defensive", names = { "berserker rage", "ira rabiosa", "rabia rabiosa" } },
	shieldwall = { id = 871, cd = 1800, kind = "defensive", names = { "shield wall", "muro de escudo" } },
	retaliation = { id = 20230, cd = 1800, kind = "defensive", names = { "retaliation", "represalias" } },
	laststand = { id = 12975, cd = 600, kind = "defensive", names = { "last stand", "ultima resistencia" } },
	bubble = { id = 642, cd = 300, kind = "defensive", names = { "divine shield", "escudo divino" } },
	bop = { id = 1022, cd = 180, kind = "defensive", names = { "blessing of protection", "bendicion de proteccion" } },
	divprot = { id = 498, cd = 300, kind = "defensive", names = { "divine protection", "proteccion divina" } },
	feign = { id = 5384, cd = 30, kind = "defensive", names = { "feign death", "fingir muerte" } },
	evasion = { id = 5277, cd = 300, kind = "defensive", names = { "evasion", "evasion" } },
	vanish = { id = 1856, cd = 300, kind = "defensive", names = { "vanish", "esfumarse" } },
	cloak = { id = 31224, cd = 60, kind = "defensive", names = { "cloak of shadows", "capa de las sombras" } },
	ward = { id = 6346, cd = 180, kind = "defensive", names = { "fear ward", "resguardo contra el miedo", "custodia de miedo" } },
	grounding = { id = 8177, cd = 15, kind = "defensive", names = { "grounding totem", "totem de toma de tierra", "totem derribador" } },
	iceblock = { id = 45438, cd = 300, kind = "defensive", names = { "ice block", "bloque de hielo" } },
	coldsnap = { id = 11958, cd = 600, kind = "defensive", names = { "cold snap", "chasquido de frio", "mordedura gelida" } },
	barkskin = { id = 22812, cd = 60, kind = "defensive", names = { "barkskin", "piel de corteza" } },
	recklessness = { id = 1719, cd = 1800, kind = "offensive", names = { "recklessness", "temeridad" } },
	deathwish = { id = 12292, cd = 180, kind = "offensive", names = { "death wish", "deseo de muerte" } },
	sweeping = { id = 12328, cd = 30, kind = "offensive", names = { "sweeping strikes", "golpes de barrido" } },
	rapidfire = { id = 3045, cd = 300, kind = "offensive", names = { "rapid fire", "disparo rapido" } },
	bestial = { id = 19574, cd = 120, kind = "offensive", names = { "bestial wrath", "colera de las bestias" } },
	adrenaline = { id = 13750, cd = 300, kind = "offensive", names = { "adrenaline rush", "subidon de adrenalina" } },
	bladeflurry = { id = 13877, cd = 120, kind = "offensive", names = { "blade flurry", "aluvion de acero" } },
	coldblood = { id = 14177, cd = 180, kind = "offensive", names = { "cold blood", "sangre fria" } },
	preparation = { id = 14185, cd = 600, kind = "offensive", names = { "preparation", "preparacion" } },
	arcanepower = { id = 12042, cd = 180, kind = "offensive", names = { "arcane power", "poder arcano" } },
	combustion = { id = 11129, cd = 180, kind = "offensive", names = { "combustion", "combustion" } },
	pom = { id = 12043, cd = 180, kind = "offensive", names = { "presence of mind", "presencia de mente" } },
	icyveins = { id = 12472, cd = 180, kind = "offensive", names = { "icy veins", "venas heladas" } },
	elemental = { id = 16166, cd = 180, kind = "offensive", names = { "elemental mastery", "maestria elemental" } },
	bloodlust = { id = 2825, cd = 600, kind = "offensive", names = { "bloodlust", "ansia de sangre" } },
	heroism = { id = 32182, cd = 600, kind = "offensive", names = { "heroism", "heroismo" } },
	infusion = { id = 10060, cd = 180, kind = "offensive", names = { "power infusion", "infusion de poder" } },
	innerfocus = { id = 14751, cd = 180, kind = "offensive", names = { "inner focus", "enfoque interno" } },
	wings = { id = 31884, cd = 180, kind = "offensive", names = { "avenging wrath", "colera vengativa" } },
	amplify = { id = 18288, cd = 180, kind = "offensive", names = { "amplify curse", "amplificar maldicion" } },
}

-- El corte principal es el que casi todas las especializaciones tienen.
-- El resto solo entra cuando se le ha visto usarlo, para no tapar LIBRE con un corte que no lleva.
local CLASS_SPELLS = {
	WARRIOR = { "pummel", "shout", "rage" },
	PALADIN = { "hoj", "bubble", "bop" },
	HUNTER = { "feign" },
	ROGUE = { "kick", "kidney", "evasion", "vanish" },
	PRIEST = { "scream", "ward" },
	SHAMAN = { "earthshock", "grounding" },
	MAGE = { "counterspell" },
	WARLOCK = { "spelllock", "fear" },
	DRUID = { "bash" },
}

local KIND_ORDER = { interrupt = 1, stun = 2, fear = 3, defensive = 4, offensive = 5 }

local SPELL_CLASS = {
	pummel = "WARRIOR", shieldbash = "WARRIOR", shout = "WARRIOR", rage = "WARRIOR",
	shieldwall = "WARRIOR", retaliation = "WARRIOR", laststand = "WARRIOR",
	recklessness = "WARRIOR", deathwish = "WARRIOR", sweeping = "WARRIOR",
	hoj = "PALADIN", bubble = "PALADIN", bop = "PALADIN", divprot = "PALADIN", wings = "PALADIN",
	feign = "HUNTER", rapidfire = "HUNTER", bestial = "HUNTER",
	kick = "ROGUE", kidney = "ROGUE", evasion = "ROGUE", vanish = "ROGUE",
	adrenaline = "ROGUE", bladeflurry = "ROGUE", coldblood = "ROGUE", preparation = "ROGUE",
	silence = "PRIEST", scream = "PRIEST", ward = "PRIEST", infusion = "PRIEST", innerfocus = "PRIEST",
	earthshock = "SHAMAN", windshear = "SHAMAN", grounding = "SHAMAN", elemental = "SHAMAN",
	bloodlust = "SHAMAN", heroism = "SHAMAN",
	counterspell = "MAGE", iceblock = "MAGE", coldsnap = "MAGE", arcanepower = "MAGE",
	combustion = "MAGE", pom = "MAGE", icyveins = "MAGE",
	spelllock = "WARLOCK", fear = "WARLOCK", howl = "WARLOCK", amplify = "WARLOCK",
	bash = "DRUID", barkskin = "DRUID",
}

local PRIMARY_KICK = {
	WARRIOR = "pummel",
	ROGUE = "kick",
	SHAMAN = "earthshock",
	MAGE = "counterspell",
	WARLOCK = "spelllock",
}

local byId, byName = {}, {}

local function Plain(text)
	text = tostring(text or ""):lower()
	text = text:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ü", "u"):gsub("ñ", "n")
	text = text:gsub("[^%w%s]", " ")
	text = text:gsub("%s+", " ")
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

for key, spell in pairs(SPELLS) do
	spell.key = key
	byId[spell.id] = spell
	for index = 1, #spell.names do
		byName[Plain(spell.names[index])] = spell
	end
end

local cds = {}
local seen = {}
local holders = {}

local function Now()
	return GetTime and GetTime() or 0
end

local function MatchSpell(spellId, spellName)
	local spell = byId[tonumber(spellId)]
	if spell then return spell end
	return byName[Plain(spellName)]
end

local function Remaining(guid, key)
	local untilTime = cds[guid] and cds[guid][key]
	if not untilTime then return 0 end
	local left = untilTime - Now()
	if left <= 0 then return 0 end
	return left
end

local function Remember(guid, spell)
	if not guid or not spell then return end
	seen[guid] = seen[guid] or {}
	seen[guid][spell.key] = true
	if spell.cd and spell.cd > 0 then
		cds[guid] = cds[guid] or {}
		cds[guid][spell.key] = Now() + spell.cd
	end
	if not cds[guid] then return end
	if spell.key == "coldsnap" then
		cds[guid].iceblock = nil
		cds[guid].icyveins = nil
	elseif spell.key == "preparation" then
		cds[guid].evasion = nil
		cds[guid].vanish = nil
		cds[guid].coldblood = nil
		cds[guid].bladeflurry = nil
	end
end

local function ListFor(class, guid)
	local list, have = {}, {}
	local base = class and CLASS_SPELLS[class]
	if base then
		for index = 1, #base do
			local key = base[index]
			if not have[key] then
				have[key] = true
				list[#list + 1] = SPELLS[key]
			end
		end
	end
	local extra = guid and seen[guid]
	if extra then
		for key in pairs(extra) do
			if SPELLS[key] and not have[key] then
				have[key] = true
				list[#list + 1] = SPELLS[key]
			end
		end
	end
	table.sort(list, function(a, b)
		return (KIND_ORDER[a.kind] or 9) < (KIND_ORDER[b.kind] or 9)
	end)
	return list
end

local function KickKeys(class, guid)
	local keys, have = {}, {}
	local primary = class and PRIMARY_KICK[class]
	if primary then
		keys[#keys + 1] = primary
		have[primary] = true
	end
	local extra = guid and seen[guid]
	if extra then
		for key in pairs(extra) do
			local spell = SPELLS[key]
			if spell and spell.kind == "interrupt" and not have[key] then
				have[key] = true
				keys[#keys + 1] = key
			end
		end
	end
	return keys
end

local function IsFreecast(class, guid)
	local keys = KickKeys(class, guid)
	if #keys == 0 then return true end
	for index = 1, #keys do
		if Remaining(guid, keys[index]) <= 0 then return false end
	end
	return true
end

local function SpellTexture(spell)
	local texture
	if C_Spell and C_Spell.GetSpellTexture then
		texture = C_Spell.GetSpellTexture(spell.id)
	end
	if not texture and GetSpellTexture then
		texture = GetSpellTexture(spell.id)
	end
	return texture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local ICON = 30
local GAP = 3

local function FormatLeft(left)
	left = math.ceil(left)
	if left < 60 then return tostring(left) end
	return string.format("%d:%02d", math.floor(left / 60), left % 60)
end

local function StyleNumber(text, seconds)
	local file = text:GetFont()
	local size = seconds >= 60 and 11 or 16
	if file then text:SetFont(file, size, "OUTLINE") end
	if seconds <= 5 then
		text:SetTextColor(1, 0.25, 0.25)
	else
		text:SetTextColor(1, 0.95, 0.2)
	end
end

local function ApplyIcon(icon, spell, guid)
	icon.spell = spell
	icon.texture:SetTexture(SpellTexture(spell))
	local left = guid and Remaining(guid, spell.key) or 0
	if left > 0 then
		if icon.texture.SetDesaturated then icon.texture:SetDesaturated(true) end
		icon.texture:SetVertexColor(0.45, 0.45, 0.45)
		icon.time:SetText(FormatLeft(left))
		StyleNumber(icon.time, left)
		icon.time:Show()
	else
		if icon.texture.SetDesaturated then icon.texture:SetDesaturated(false) end
		icon.texture:SetVertexColor(1, 1, 1)
		icon.time:Hide()
	end
	icon:Show()
end

local function EnsureIcon(holder, index)
	local icon = holder.icons[index]
	if icon then return icon end
	icon = CreateFrame("Frame", nil, holder)
	icon:SetSize(ICON, ICON)
	icon:EnableMouse(false)
	local texture = icon:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon.texture = texture
	local time = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	time:SetPoint("CENTER", 0, 0)
	icon.time = time
	holder.icons[index] = icon
	return icon
end

local function Layout(holder)
	local list = ListFor(holder.class, holder.guid)
	local shown = 0
	for index = 1, #list do
		local icon = EnsureIcon(holder, index)
		icon:ClearAllPoints()
		if index == 1 then
			icon:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
		else
			icon:SetPoint("LEFT", holder.icons[index - 1], "RIGHT", GAP, 0)
		end
		ApplyIcon(icon, list[index], holder.guid)
		shown = index
	end
	for index = shown + 1, #holder.icons do
		holder.icons[index]:Hide()
	end
	local free = IsFreecast(holder.class, holder.guid)
	holder.free:SetShown(free)
	local width = shown > 0 and (shown * ICON + (shown - 1) * GAP) or ICON
	holder:SetWidth(width)
	if free then
		holder.free:ClearAllPoints()
		holder.free:SetPoint("BOTTOM", holder, "TOP", 0, 1)
	end
	holder:SetShown(shown > 0 or free)
end

local function UsableString(value)
	if type(value) ~= "string" or value == "" then return nil end
	local ok = pcall(function()
		return value .. ""
	end)
	if ok then return value end
end

local people = {}

local function MakeHolder(guid)
	local holder = CreateFrame("Frame", nil, UIParent)
	holder:SetSize(ICON, ICON + 14)
	holder.icons = {}
	local name = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	name:SetPoint("BOTTOM", holder, "TOP", 0, 14)
	local file = name:GetFont()
	if file then name:SetFont(file, 12, "OUTLINE") end
	holder.name = name
	local free = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	free:SetText("LIBRE")
	free:SetTextColor(0.2, 1, 0.35)
	if file then free:SetFont(file, 12, "OUTLINE") end
	holder.free = free
	holders[guid] = holder
	return holder
end

local function StackRows()
	local shown = {}
	for _, holder in pairs(holders) do
		if holder:IsShown() then
			shown[#shown + 1] = holder
		end
	end
	table.sort(shown, function(a, b)
		return (a.sortName or "") < (b.sortName or "")
	end)
	for index = 1, #shown do
		local holder = shown[index]
		holder:ClearAllPoints()
		holder:SetPoint("TOP", UIParent, "TOP", 0, -120 - (index - 1) * (ICON + 32))
	end
end

local function PaintPerson(guid)
	local person = people[guid]
	if not person then return end
	local holder = holders[guid] or MakeHolder(guid)
	holder.guid = guid
	holder.class = person.class
	holder.sortName = person.name or guid
	if holder.name then holder.name:SetText(person.name or "") end
	Layout(holder)
end

local function RefreshPeople()
	local now = Now()
	for guid, person in pairs(people) do
		if now - person.at > 45 then
			people[guid] = nil
			if holders[guid] then
				holders[guid]:Hide()
				holders[guid].guid = nil
			end
		else
			PaintPerson(guid)
		end
	end
	StackRows()
end

local function SafeUnitName(unit)
	if not UnitName then return nil end
	local ok, name = pcall(UnitName, unit)
	if ok then return UsableString(name) end
end

local function SafeUnitClass(unit)
	if not UnitClass then return nil end
	local ok, _, token = pcall(UnitClass, unit)
	if ok then return UsableString(token) end
end

local function AllowedUnit(unit)
	if type(unit) ~= "string" or unit == "" or unit == "player" then return false end
	if unit:find("nameplate", 1, true) then return false end
	if unit == "target" or unit == "focus" or unit == "softenemy" or unit == "softfriend" then return true end
	if unit:find("^party") or unit:find("^raid") or unit:find("^boss") or unit:find("^arena") then return true end
	return false
end

local function NoteUnitCast(unit, spellId)
	if not AllowedUnit(unit) then return end
	local spell = MatchSpell(spellId, nil)
	if not spell then return end
	local name = SafeUnitName(unit)
	if not name then return end
	if not SHOW_ALLIES and UnitCanAttack then
		local ok, enemy = pcall(UnitCanAttack, "player", unit)
		if ok and not enemy then return end
	end
	local key = name
	Remember(key, spell)
	local person = people[key] or {}
	person.name = name
	person.class = SafeUnitClass(unit) or person.class or SPELL_CLASS[spell.key]
	person.at = Now()
	people[key] = person
	PaintPerson(key)
	StackRows()
end

local elapsed = 0
local told = false
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:SetScript("OnEvent", function(_, event, unit, _, spellId)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		if type(spellId) ~= "number" then return end
		NoteUnitCast(unit, spellId)
		return
	end
	for guid, holder in pairs(holders) do
		holder:Hide()
		holder.guid = nil
		people[guid] = nil
	end
	if not told and DEFAULT_CHAT_FRAME then
		told = true
		DEFAULT_CHAT_FRAME:AddMessage("|cff7ec8ffCDManager 1.2.8|r cargado. Sigue al objetivo, al grupo y a los jefes.")
	end
end)
watcher:SetScript("OnUpdate", function(_, delta)
	elapsed = elapsed + delta
	if elapsed < 0.2 then return end
	elapsed = 0
	RefreshPeople()
end)
