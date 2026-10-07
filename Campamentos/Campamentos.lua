-- Checklist de los bufos de los campamentos de Forever.
-- El cliente los junta en un solo aura (Camp Benefits). El detalle sale en su tooltip.
-- Si ya tienes el bufo de clase equivalente, el del campamento no se acumula.

local CAMP_ID = 1229741
local SIT_IDS = { 1229739, 1289723 }
local NEAR_ID = 1283391
local REST_ID = 1229451

local BENEFITS = {
	{ key = "stats", name = "Estadísticas +8%", how = "Pecera de Pesca (20) en la hoguera.", class = "kings", icon = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings", words = { "8%", "fish bowl", "pecera", "cuenco de peces", "increased stats", "estadisticas aumentadas" } },
	{ key = "crit", name = "Crítico +2%", how = "Silla de Desuello (20) en la hoguera.", class = "crit", icon = "Interface\\Icons\\Ability_CriticalStrike", words = { "critical", "critico", "camp chair", "silla de campamento", "silla" } },
	{ key = "stamina", name = "Aguante", how = "Botiquín de Primeros auxilios (20) en la hoguera.", class = "fort", icon = "Interface\\Icons\\Spell_Holy_WordFortitude", words = { "stamina", "aguante", "first aid", "botiquin" } },
	{ key = "strength", name = "Fuerza", how = "Rueda de afilar de Herrería (20) en la hoguera.", class = "earth", icon = "Interface\\Icons\\Spell_Nature_Strength", words = { "strength", "fuerza", "sharpening", "afilar" } },
	{ key = "intellect", name = "Intelecto", how = "Vela de incienso de Herboristería (20) en la hoguera.", class = "intellect", icon = "Interface\\Icons\\Spell_Holy_MagicalSentry", words = { "intellect", "intelecto", "incense", "incienso" } },
	{ key = "ap", name = "Poder de ataque", how = "Piedra imán de Minería (20) en la hoguera.", class = "might", icon = "Interface\\Icons\\Spell_Holy_FistOfJustice", words = { "attack power", "poder de ataque", "lodestone", "piedra iman", "magnetita" } },
	{ key = "mana", name = "Maná cada 5 s", how = "Pozo de maná de Alquimia (20) en la hoguera.", class = "wisdom", icon = "Interface\\Icons\\Spell_Holy_SealOfWisdom", words = { "mana regen", "regeneracion de mana", "mana every", "mana well", "pozo de mana", "cada 5", "per 5" } },
	{ key = "spirit", name = "Espíritu", how = "Estandarte de tu facción, de Sastrería (20).", class = "spirit", icon = "Interface\\Icons\\Spell_Holy_DivineSpirit", words = { "spirit", "espiritu", "faction banner", "estandarte" } },
	{ key = "armor", name = "Armadura y resistencias", how = "Laúd encantado de Encantamiento (20) en la hoguera.", class = "motw", icon = "Interface\\Icons\\Spell_Nature_Regeneration", words = { "armor", "armadura", "resistance", "resistencia", "enchanted lute", "laud" } },
	{ key = "rest", name = "Descanso de tienda", how = "Tienda de Peletería (20). Una vez por hora.", icon = "Interface\\Icons\\Spell_Nature_Sleep", words = { "rested", "descanso", "camp tent", "tienda" } },
}

local CLASS_IDS = {
	kings = { 20217, 25898 },
	might = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 25782, 25916, 27140 },
	wisdom = { 19742, 19850, 19852, 19853, 19854, 25290, 25894, 25918, 27142 },
	intellect = { 1459, 1460, 1461, 10156, 10157, 27126, 23028, 27127 },
	fort = { 1243, 1244, 1245, 2791, 10937, 10938, 25389, 21562, 21564, 25392 },
	spirit = { 14752, 14818, 14819, 27841, 25312, 27681, 32999 },
	motw = { 1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990, 21849, 21850, 26991 },
	crit = { 24907, 17007 },
	earth = { 8075, 8160, 8161, 10442, 25361, 25528 },
}

local db
local frame
local classNames = {}
local watchNames = {}

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

local function SafeNumber(value)
	if type(value) ~= "number" then return nil end
	local ok, number = pcall(function()
		return value + 0
	end)
	if ok and type(number) == "number" then return number end
end

local function SpellName(spellId)
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellId)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, spellId)
		if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
			return info.name
		end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, spellId)
		if ok and type(name) == "string" and name ~= "" then return name end
	end
end

local function RememberSpell(bucket, spellId, key)
	local name = SpellName(spellId)
	local plain = Plain(name)
	if plain ~= "" then
		bucket[plain] = key
	end
end

local function BuildNames()
	classNames = {}
	watchNames = {}
	for key, ids in pairs(CLASS_IDS) do
		for index = 1, #ids do
			RememberSpell(classNames, ids[index], key)
		end
	end
	RememberSpell(watchNames, CAMP_ID, "benefits")
	RememberSpell(watchNames, NEAR_ID, "nearby")
	RememberSpell(watchNames, REST_ID, "rest")
	for index = 1, #SIT_IDS do
		RememberSpell(watchNames, SIT_IDS[index], "sit")
	end
	watchNames["camp benefits"] = "benefits"
	watchNames["beneficios del campamento"] = "benefits"
	watchNames["beneficios de campamento"] = "benefits"
	watchNames["welcoming campfire"] = "sit"
	watchNames["hoguera acogedora"] = "sit"
	watchNames["campfire nearby"] = "nearby"
	watchNames["hoguera cercana"] = "nearby"
	watchNames["boosted rest"] = "rest"
	watchNames["descanso potenciado"] = "rest"
end

local function TimeLeft(expiration)
	expiration = SafeNumber(expiration)
	if not expiration or not GetTime then return nil end
	local ok, left = pcall(function()
		return expiration - GetTime()
	end)
	if not ok or type(left) ~= "number" or left <= 0 then return nil end
	left = math.floor(left + 0.5)
	if left >= 3600 then
		return string.format("%d:%02d:%02d", math.floor(left / 3600), math.floor(left / 60) % 60, left % 60)
	end
	return string.format("%d:%02d", math.floor(left / 60), left % 60)
end

local tip
local function ScanTip()
	if tip then return tip end
	tip = CreateFrame("GameTooltip", "CampamentosScanTip", nil, "GameTooltipTemplate")
	tip:SetOwner(UIParent, "ANCHOR_NONE")
	return tip
end

local function TooltipLines(index, filter)
	local lines = {}
	if C_TooltipInfo and C_TooltipInfo.GetUnitAura then
		local ok, data = pcall(C_TooltipInfo.GetUnitAura, "player", index, filter)
		if ok and type(data) == "table" and type(data.lines) == "table" then
			for lineIndex = 1, #data.lines do
				local line = data.lines[lineIndex]
				local text = type(line) == "table" and (line.leftText or line.left) or nil
				if type(text) == "string" and text ~= "" then
					lines[#lines + 1] = text
				end
			end
		end
	end
	if #lines > 0 then return lines end
	local scanner = ScanTip()
	scanner:ClearLines()
	local ok = pcall(scanner.SetUnitAura, scanner, "player", index, filter)
	if not ok then return lines end
	for lineIndex = 1, 30 do
		local left = _G["CampamentosScanTipTextLeft" .. lineIndex]
		local text = left and left.GetText and left:GetText()
		if type(text) == "string" and text ~= "" then
			lines[#lines + 1] = text
		end
	end
	scanner:Hide()
	return lines
end

local function ReadAuras(filter, found, classUp)
	local index = 1
	while index < 80 do
		local aura
		if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
			local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, filter)
			if not ok or not data then break end
			aura = data
		elseif UnitAura then
			local ok, name, _, _, _, _, expiration, _, _, _, spellId = pcall(UnitAura, "player", index, filter)
			if not ok or type(name) ~= "string" then break end
			aura = { name = name, expirationTime = expiration, spellId = spellId }
		else
			break
		end
		local name = type(aura.name) == "string" and aura.name or ""
		local plain = Plain(name)
		local spellId = SafeNumber(aura.spellId)
		local role = spellId == CAMP_ID and "benefits" or nil
		if not role and spellId == NEAR_ID then role = "nearby" end
		if not role and spellId == REST_ID then role = "rest" end
		if not role then
			for sitIndex = 1, #SIT_IDS do
				if spellId == SIT_IDS[sitIndex] then role = "sit" end
			end
		end
		if not role and plain ~= "" then
			role = watchNames[plain]
		end
		if role and not found[role] then
			found[role] = {
				index = index,
				filter = filter,
				name = name,
				expiration = aura.expirationTime,
			}
		end
		local classKey = plain ~= "" and classNames[plain] or nil
		if classKey and name ~= "" and not classUp[classKey] then
			classUp[classKey] = name
		end
		index = index + 1
	end
end

local function Hits(lines)
	local have = {}
	local extra = {}
	for index = 1, #lines do
		local plain = Plain(lines[index])
		if plain ~= "" and not plain:find("remaining", 1, true) and not plain:find("restante", 1, true) then
			local used = false
			for benefitIndex = 1, #BENEFITS do
				local benefit = BENEFITS[benefitIndex]
				if not have[benefit.key] then
					for wordIndex = 1, #benefit.words do
						if plain:find(benefit.words[wordIndex], 1, true) then
							have[benefit.key] = true
							used = true
							break
						end
					end
				end
			end
			if not used then
				extra[#extra + 1] = lines[index]
			end
		end
	end
	return have, extra
end

local function Refresh()
	if not frame then return end
	local found = {}
	local classUp = {}
	ReadAuras("HELPFUL", found, classUp)
	ReadAuras("HARMFUL", found, classUp)
	local have, extra = {}, {}
	local benefits = found.benefits
	if benefits then
		local lines = TooltipLines(benefits.index, benefits.filter)
		have, extra = Hits(lines)
	end
	if found.rest then
		have.rest = true
	end

	local owned = 0
	for index = 1, #BENEFITS do
		local benefit = BENEFITS[index]
		if benefit.key ~= "rest" and have[benefit.key] then
			owned = owned + 1
		end
		local row = frame.rows[index]
		local covered = benefit.class and classUp[benefit.class]
		if have[benefit.key] then
			row.status:SetText("Tienes")
			row.status:SetTextColor(0.35, 1, 0.45)
		elseif covered then
			row.status:SetText("Lo cubre " .. covered)
			row.status:SetTextColor(1, 0.82, 0.3)
		else
			row.status:SetText("Te falta")
			row.status:SetTextColor(1, 0.35, 0.35)
		end
	end

	local timer = benefits and TimeLeft(benefits.expiration)
	local sitTimer = found.sit and TimeLeft(found.sit.expiration)
	local headline
	if benefits then
		headline = "Tienes " .. owned .. " de 9"
		if timer then headline = headline .. "  ·  " .. timer end
		if owned == 0 and #extra > 0 then
			headline = "Tienes el bufo, pero no distingo los efectos"
		end
	elseif found.sit then
		headline = "Sentado junto al fuego"
		if sitTimer then headline = headline .. "  ·  " .. sitTimer end
	elseif found.nearby then
		headline = "Hay una hoguera cerca. Siéntate un minuto."
	else
		headline = "No tienes bufos de campamento."
	end
	frame.info:SetText(headline)
	if benefits and owned == 0 and #extra > 0 then
		frame.extra:SetText(table.concat(extra, "\n"))
	else
		frame.extra:SetText("")
	end
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
	frame = CreateFrame("Frame", "CampamentosFrame", UIParent)
	frame:SetSize(460, 620)
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
	tinsert(UISpecialFrames, "CampamentosFrame")

	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.07, 0.92)

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -12)
	title:SetText("Campamentos")

	local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)

	local info = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	info:SetPoint("TOPLEFT", 16, -40)
	info:SetPoint("TOPRIGHT", -16, -40)
	info:SetJustifyH("LEFT")
	info:SetHeight(32)
	frame.info = info

	frame.rows = {}
	for index = 1, #BENEFITS do
		local benefit = BENEFITS[index]
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(428, 42)
		row:SetPoint("TOPLEFT", 16, -74 - (index - 1) * 44)
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(22, 22)
		icon:SetPoint("LEFT", 0, 6)
		icon:SetTexture(benefit.icon)
		icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, 2)
		name:SetJustifyH("LEFT")
		name:SetText(benefit.name)
		local how = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		how:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
		how:SetWidth(280)
		how:SetJustifyH("LEFT")
		how:SetText(benefit.how)
		local status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		status:SetPoint("RIGHT", 0, 6)
		status:SetJustifyH("RIGHT")
		status:SetText("Te falta")
		row.status = status
		frame.rows[index] = row
	end

	local extra = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	extra:SetPoint("BOTTOMLEFT", 16, 28)
	extra:SetPoint("BOTTOMRIGHT", -16, 28)
	extra:SetJustifyH("LEFT")
	extra:SetHeight(36)
	frame.extra = extra

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOMLEFT", 16, 10)
	hint:SetPoint("BOTTOMRIGHT", -16, 10)
	hint:SetJustifyH("LEFT")
	hint:SetText("Siéntate un minuto en la hoguera. La tienda basta con medio. Verde: lo tienes. Amarillo: lo cubre tu clase.")

	frame.ready = false
	frame:SetScript("OnShow", function(self)
		if self.ready then db.open = true end
		Refresh()
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
		Refresh()
	end
end

local function PrintAuras()
	local function Dump(filter)
		local index = 1
		while index < 80 do
			local name, spellId
			if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
				local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, filter)
				if not ok or not data then break end
				name = data.name
				spellId = data.spellId
			elseif UnitAura then
				local ok, auraName, _, _, _, _, _, _, _, _, auraSpell = pcall(UnitAura, "player", index, filter)
				if not ok or type(auraName) ~= "string" then break end
				name = auraName
				spellId = auraSpell
			else
				break
			end
			if type(name) == "string" then
				print("|cffffd100Campamentos|r: " .. filter .. " " .. name .. "  " .. tostring(SafeNumber(spellId) or "?"))
			end
			index = index + 1
		end
	end
	Dump("HELPFUL")
	Dump("HARMFUL")
end

SLASH_CAMPAMENTOS1 = "/campamentos"
SLASH_CAMPAMENTOS2 = "/camp"
SlashCmdList.CAMPAMENTOS = function(message)
	message = Plain(message or "")
	if message == "auras" then
		PrintAuras()
		return
	end
	Toggle()
end

local told = false
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("UNIT_AURA")
watcher:SetScript("OnEvent", function(_, event, arg)
	if event == "ADDON_LOADED" and arg ~= "Campamentos" then return end
	if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then
		CampamentosDB = CampamentosDB or {}
		db = CampamentosDB
		BuildNames()
		if not frame then MakeFrame() end
		if event == "PLAYER_LOGIN" and not told and DEFAULT_CHAT_FRAME then
			told = true
			DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Campamentos|r cargado. /campamentos muestra los bufos que tienes y los que te faltan.")
			if db.open ~= false then frame:Show() end
		end
		return
	end
	if event == "UNIT_AURA" and arg ~= "player" then return end
	Refresh()
end)
watcher:SetScript("OnUpdate", function(_, delta)
	watcher.elapsed = (watcher.elapsed or 0) + delta
	if watcher.elapsed < 1 then return end
	watcher.elapsed = 0
	if frame and frame:IsShown() then Refresh() end
end)
