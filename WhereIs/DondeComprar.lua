local ADDON_NAME, DC = ...

local db
local names = {}
local zoneMaps = {}
local pins = {}
local markers = {}
local marksVisible = true
local resultVendors
local marksButton
local RefreshMarksButton
local tracked
local minimapPin
local frame
local searchBox
local statusText
local resultChild
local resultButtons = {}
local viewItemID
local gatherItemID
local showingNodes = false
local nodePinList
local nearPins = {}
local HighlightMerchantSearch
local matchIDs
local searchRetries = 0
local searchGeneration = 0

local ROW = 40

local function Print(message)
	print("|cffffd100WhereIs|r: " .. tostring(message))
end

local function Norm(text)
	if type(text) ~= "string" then
		return ""
	end
	text = text:lower()
	text = text:gsub("á", "a"):gsub("é", "e"):gsub("í", "i"):gsub("ó", "o"):gsub("ú", "u"):gsub("ü", "u"):gsub("ñ", "n")
	text = text:gsub("%s+", " ")
	return strtrim(text)
end

local function Plain(text)
	if type(text) ~= "string" then
		return ""
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|cn.-:", "")
	text = text:gsub("|r", "")
	text = text:gsub("|H.-|h(.-)|h", "%1")
	text = text:gsub("|h", "")
	text = text:gsub("[%[%]]", "")
	return strtrim(text)
end

local function EnsureDB()
	if type(DondeComprarDB) ~= "table" then
		DondeComprarDB = {}
	end
	if type(DondeComprarDB.learned) ~= "table" then
		DondeComprarDB.learned = {}
	end
	db = DondeComprarDB
end

local function ItemName(itemID)
	if names[itemID] then
		return names[itemID]
	end
	local name
	if C_Item and C_Item.GetItemNameByID then
		local ok, value = pcall(C_Item.GetItemNameByID, itemID)
		if ok and type(value) == "string" then
			name = value
		end
	end
	if type(name) ~= "string" and GetItemInfo then
		name = GetItemInfo(itemID)
	end
	if type(name) == "string" and name ~= "" then
		names[itemID] = name
		return name
	end
end

local function ItemIcon(itemID)
	if C_Item and C_Item.GetItemIconByID then
		local icon = C_Item.GetItemIconByID(itemID)
		if icon then
			return icon
		end
	end
	return GetItemIcon and GetItemIcon(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function MarkerTexture(kind, itemID)
	if kind == "mob" then
		return "Interface\\Icons\\INV_Misc_MonsterClaw_04"
	end
	if kind == "herb" or kind == "ore" or kind == "fish" then
		local id = itemID or viewItemID
		if id then
			local icon = ItemIcon(id)
			if icon and icon ~= "Interface\\Icons\\INV_Misc_QuestionMark" then
				return icon
			end
			if C_Item and C_Item.RequestLoadItemDataByID then
				pcall(C_Item.RequestLoadItemDataByID, id)
			end
		end
		if kind == "herb" then
			return "Interface\\Icons\\INV_Misc_Flower_02"
		end
		if kind == "fish" then
			return "Interface\\Icons\\INV_Misc_Fish_02"
		end
		return "Interface\\Icons\\INV_Ore_Copper_01"
	end
	return "Interface\\Icons\\INV_Misc_Coin_01"
end

local FISH_WATER = {
	[6358] = {
		"También en agua abierta, con menos suerte:",
		"Poniente, Costa Oscura, Argénteos, Humedales, Trabalomas, Baldíos, Arathi, Tuercespina, Desolace, Revolcafango, Pantano de las Penas, Tanaris, Azshara, Feralas, Tierras Devastadas, Loch Modan y Un'Goro.",
	},
	[6359] = {
		"También en agua abierta, con menos suerte:",
		"Humedales, Trabalomas, Arathi, Tuercespina, Desolace, Revolcafango, Pantano de las Penas, Tanaris, Azshara, Feralas, Tierras Devastadas y Sierra Espolón.",
	},
	[21071] = {
		"También en agua abierta, en ríos y lagos:",
		"Vallefresno, Trabalomas, Loch Modan, Argénteos y Sierra Espolón.",
	},
	[21153] = {
		"También en agua abierta, en ríos y lagos:",
		"Alterac, ríos de Tuercespina, Tierras de la Peste, Un'Goro, lagos de Feralas, Tierras del Interior, interior de Revolcafango y Pantano de las Penas.",
	},
	[13422] = {
		"Fuera del banco es muy rara.",
		"Azshara, Feralas, Tanaris y el sur de Tuercespina.",
	},
	[6522] = {
		"Solo en el banco.",
		"Oasis de Los Baldíos y el agua de las Cuevas de los Lamentos. El agua abierta del oasis no lo da.",
	},
	[19807] = {
		"Solo en el banco.",
		"Costa de Tuercespina, y solo mientras dura el concurso.",
	},
}

local function AddFishLines(itemID)
	local lines = itemID and FISH_WATER[itemID]
	if not lines then
		return
	end
	for i = 1, #lines do
		if i == 1 then
			GameTooltip:AddLine(lines[i], 0.55, 0.8, 1, true)
		else
			GameTooltip:AddLine(lines[i], 0.85, 0.9, 1, true)
		end
	end
end

local function EachStoredDrop(visitor)
	local function Walk(spots)
		for i = 1, #(spots or {}) do
			local drops = spots[i].drops
			for n = 1, #(drops or {}) do
				visitor(drops[n])
			end
		end
	end
	Walk(DC.Mobs)
	if DC.SpawnKind then
		for id in pairs(DC.SpawnKind) do
			visitor(id)
		end
	end
	if DC.Disenchant then
		for id in pairs(DC.Disenchant) do
			visitor(id)
		end
	end
end

local function RequestNames()
	local ids = {}
	local seen = {}
	for _, list in pairs(DC.Stock or {}) do
		for i = 1, #list do
			local id = list[i]
			if not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
	end
	EachStoredDrop(function(id)
		if not seen[id] then
			seen[id] = true
			ids[#ids + 1] = id
		end
	end)
	if db and db.learned then
		for id in pairs(db.learned) do
			id = tonumber(id) or id
			if not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
	end
	for i = 1, #ids do
		local id = ids[i]
		if not ItemName(id) then
			if C_Item and C_Item.RequestLoadItemDataByID then
				pcall(C_Item.RequestLoadItemDataByID, id)
			elseif Item and Item.CreateFromItemID then
				local item = Item:CreateFromItemID(id)
				if item and item.ContinueOnItemLoad then
					item:ContinueOnItemLoad(function()
						local n = item.GetItemName and item:GetItemName()
						if n then
							names[id] = n
						end
					end)
				end
			end
		end
	end
end

local function MapNameMatches(infoName, alias)
	return Norm(infoName or "") == Norm(alias)
end

local function ConsiderZone(key, mapID, info, prefer)
	local current = zoneMaps[key]
	if not current then
		zoneMaps[key] = mapID
		return
	end
	local currentInfo = C_Map.GetMapInfo(current)
	local function Score(id, data, wanted)
		if not data then
			return 0
		end
		local score = 1
		if data.mapType == 3 then
			score = score + 5
		end
		if wanted then
			local n = Norm(data.name or "")
			for i = 1, #wanted do
				if n == Norm(wanted[i]) then
					score = score + 10
				end
			end
		end
		if data.mapType == 4 or data.mapType == 5 then
			score = score - 3
		end
		return score
	end
	if Score(mapID, info, prefer) > Score(current, currentInfo, prefer) then
		zoneMaps[key] = mapID
	end
end

local function ResolveZones()
	if not C_Map or not C_Map.GetMapInfo then
		zoneMaps = DC.FallbackMap or {}
		return
	end
	wipe(zoneMaps)
	for mapID = 1, 2500 do
		local info = C_Map.GetMapInfo(mapID)
		if info and info.name and info.mapType ~= 4 then
			local name = Norm(info.name)
			for key, aliases in pairs(DC.ZoneAliases or {}) do
				for i = 1, #aliases do
					if name == Norm(aliases[i]) then
						ConsiderZone(key, mapID, info, DC.ZonePrefer and DC.ZonePrefer[key])
					end
				end
			end
		end
	end
	for key, mapID in pairs(DC.FallbackMap or {}) do
		if not zoneMaps[key] then
			local info = C_Map.GetMapInfo(mapID)
			if info and info.name then
				local aliases = DC.ZoneAliases and DC.ZoneAliases[key]
				if aliases then
					for i = 1, #aliases do
						if MapNameMatches(info.name, aliases[i]) then
							zoneMaps[key] = mapID
							break
						end
					end
				end
			end
			if not zoneMaps[key] then
				zoneMaps[key] = mapID
			end
		end
	end
end

local function ZoneMap(zone)
	return zoneMaps[zone] or (DC.FallbackMap and DC.FallbackMap[zone])
end

local function ZoneLabel(mapID)
	if not mapID or not C_Map or not C_Map.GetMapInfo then
		return "Mapa desconocido"
	end
	local info = C_Map.GetMapInfo(mapID)
	return info and info.name or ("Mapa " .. tostring(mapID))
end

local function PlayerSide()
	local faction = UnitFactionGroup("player")
	if faction == "Alliance" then
		return "A"
	end
	if faction == "Horde" then
		return "H"
	end
	return "N"
end

local function SideOf(unit)
	local faction = UnitFactionGroup(unit)
	if faction == "Alliance" then
		return "A"
	end
	if faction == "Horde" then
		return "H"
	end
	return "N"
end

local function StaticVendorsFor(itemID)
	local found = {}
	for i = 1, #(DC.Vendors or {}) do
		local vendor = DC.Vendors[i]
		local sells = false
		for s = 1, #(vendor.sells or {}) do
			local stock = DC.Stock and DC.Stock[vendor.sells[s]]
			if stock then
				for n = 1, #stock do
					if stock[n] == itemID then
						sells = true
						break
					end
				end
			end
			if sells then
				break
			end
		end
		if sells then
			local mapID = ZoneMap(vendor.zone)
			if mapID then
				found[#found + 1] = {
					name = vendor.name,
					map = mapID,
					x = vendor.x,
					y = vendor.y,
					faction = vendor.faction or "N",
					source = "data",
				}
			end
		end
	end
	return found
end

local SKIN_ITEMS = {
	[783] = true,
	[2318] = true,
	[2319] = true,
	[4232] = true,
	[4234] = true,
	[4235] = true,
	[4304] = true,
	[5784] = true,
	[5785] = true,
	[6470] = true,
	[7286] = true,
	[7392] = true,
	[7428] = true,
	[8154] = true,
	[8165] = true,
	[8169] = true,
	[8170] = true,
	[8171] = true,
	[15412] = true,
	[15414] = true,
	[15415] = true,
	[15416] = true,
	[15417] = true,
	[15419] = true,
	[17012] = true,
}

local function DropPercent(itemID, action)
	local row = itemID and DC.DropRate and DC.DropRate[itemID]
	local value = row and action and row[action]
	if type(value) == "number" then
		return value
	end
end

local function AddDropLines(itemID, action)
	if action == "herb" then
		GameTooltip:AddLine("Al herborizarla: 100%", 0.4, 1, 0.5)
		return
	end
	if action == "ore" then
		GameTooltip:AddLine("Al minarla: 100%", 0.75, 0.75, 0.8)
		return
	end
	if action == "fish" then
		local row = itemID and DC.DropRate and DC.DropRate[itemID]
		if row and row.fish then
			GameTooltip:AddLine("En el banco, aprox. " .. row.fish .. "% de lo que pica", 0.45, 0.75, 1)
		end
		if row and row.open == 0 then
			GameTooltip:AddLine("En agua abierta no sale", 1, 0.55, 0.35)
		elseif row and row.open then
			GameTooltip:AddLine("En agua abierta, aprox. " .. row.open .. "%", 0.55, 0.8, 1)
		end
		return
	end
	local percent = DropPercent(itemID, action)
	if not percent then
		return
	end
	local verb = action == "skin" and "desollar" or "matar"
	GameTooltip:AddLine("Aprox. " .. percent .. "% al " .. verb, 1, 0.82, 0.4)
end

local function MobsFor(itemID)
	local found = {}
	local function Collect(spots)
		for i = 1, #(spots or {}) do
			local mob = spots[i]
			local drops = mob.drops
			local has = false
			for n = 1, #(drops or {}) do
				if drops[n] == itemID then
					has = true
					break
				end
			end
			if has then
				local mapID = ZoneMap(mob.zone)
				if mapID then
					local kind = mob.kind or "mob"
					local method = kind == "mob" and (SKIN_ITEMS[itemID] and "skin" or "loot") or nil
					found[#found + 1] = {
						name = mob.name,
						map = mapID,
						x = mob.x,
						y = mob.y,
						faction = "N",
						source = kind == "mob" and "bicho" or kind,
						kind = kind,
						method = method,
						chance = DropPercent(itemID, method),
					}
				end
			end
		end
	end
	Collect(DC.Mobs)
	return found
end

local function LearnedVendorsFor(itemID)
	local found = {}
	local bucket = db and (db.learned[itemID] or db.learned[tostring(itemID)])
	if type(bucket) ~= "table" then
		return found
	end
	for i = 1, #bucket do
		local vendor = bucket[i]
		if vendor and vendor.map and vendor.x and vendor.y and vendor.name then
			found[#found + 1] = {
				name = vendor.name,
				map = vendor.map,
				x = vendor.x,
				y = vendor.y,
				faction = vendor.faction or "N",
				source = "visto",
				cost = vendor.cost,
			}
		end
	end
	return found
end

local function MergeVendors(itemID)
	local merged = {}
	local index = {}
	local function Add(vendor)
		local key = Norm(vendor.name) .. "|" .. tostring(vendor.map)
		local existing = index[key]
		if not existing then
			index[key] = vendor
			merged[#merged + 1] = vendor
			return
		end
		if vendor.source == "visto" then
			existing.x = vendor.x
			existing.y = vendor.y
			existing.map = vendor.map
			existing.faction = vendor.faction or existing.faction
			existing.cost = vendor.cost or existing.cost
			existing.source = "visto"
		end
	end
	local learned = LearnedVendorsFor(itemID)
	for i = 1, #learned do
		Add(learned[i])
	end
	local static = StaticVendorsFor(itemID)
	for i = 1, #static do
		Add(static[i])
	end
	return merged
end

local function SameMapDistance(vendor)
	if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
		return nil
	end
	local okMap, playerMap = pcall(C_Map.GetBestMapForUnit, "player")
	if not okMap or playerMap ~= vendor.map then
		return nil
	end
	local okPos, pos = pcall(C_Map.GetPlayerMapPosition, vendor.map, "player")
	if not okPos or not pos or not pos.GetXY then
		return nil
	end
	local okXY, px, py = pcall(pos.GetXY, pos)
	if not okXY or not px or not py then
		return nil
	end
	local dx = px - vendor.x
	local dy = py - vendor.y
	return math.sqrt(dx * dx + dy * dy)
end

local function SortVendors(list)
	local side = PlayerSide()
	table.sort(list, function(a, b)
		local da = SameMapDistance(a)
		local dbDistance = SameMapDistance(b)
		if da and not dbDistance then
			return true
		end
		if dbDistance and not da then
			return false
		end
		if da and dbDistance and math.abs(da - dbDistance) > 0.0001 then
			return da < dbDistance
		end
		local aHome = a.faction == "N" or a.faction == side
		local bHome = b.faction == "N" or b.faction == side
		if aHome ~= bHome then
			return aHome
		end
		return Norm(a.name) < Norm(b.name)
	end)
end

local function SplitFaction(list)
	local side = PlayerSide()
	local home, enemy = {}, {}
	for i = 1, #list do
		local vendor = list[i]
		if vendor.faction == "N" or vendor.faction == side or side == "N" then
			home[#home + 1] = vendor
		else
			enemy[#enemy + 1] = vendor
		end
	end
	return home, enemy
end

local function Canvas()
	if not WorldMapFrame then
		return nil
	end
	if type(WorldMapFrame.GetCanvas) == "function" then
		local ok, canvas = pcall(WorldMapFrame.GetCanvas, WorldMapFrame)
		if ok and canvas then
			return canvas
		end
	end
	if WorldMapFrame.ScrollContainer then
		return WorldMapFrame.ScrollContainer.Child or WorldMapFrame.ScrollContainer
	end
end

local function CurrentMap()
	if WorldMapFrame and type(WorldMapFrame.GetMapID) == "function" then
		local ok, mapID = pcall(WorldMapFrame.GetMapID, WorldMapFrame)
		if ok then
			return mapID
		end
	end
end

local MINIMAP_YARDS = {
	indoors = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
	outdoors = { [0] = 466.67, [1] = 400, [2] = 333.33, [3] = 266.67, [4] = 200, [5] = 133.33 },
}

local function WorldXY(mapID, x, y)
	if not mapID or not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then
		return
	end
	local vec = CreateVector2D(x, y)
	if vec and vec.SetXY then
		vec:SetXY(x, y)
	end
	local ok, continent, world = pcall(C_Map.GetWorldPosFromMapPos, mapID, vec)
	if not ok or type(world) ~= "table" or not world.GetXY then
		return
	end
	local wx, wy = world:GetXY()
	if type(wx) ~= "number" or type(wy) ~= "number" then
		return
	end
	return continent, wx, wy
end

local function MapSize(mapID)
	if C_Map and C_Map.GetMapWorldSize then
		local ok, width, height = pcall(C_Map.GetMapWorldSize, mapID)
		if ok and type(width) == "number" and type(height) == "number" and width > 50 and height > 50 then
			return width, height
		end
	end
	local _, x0, y0 = WorldXY(mapID, 0, 0)
	local _, x1 = WorldXY(mapID, 1, 0)
	local _, _, y1 = WorldXY(mapID, 0, 1)
	if x0 and x1 and y0 and y1 then
		local width = math.abs(x1 - x0)
		local height = math.abs(y1 - y0)
		if width > 50 and height > 50 then
			return width, height
		end
	end
end

local function PlayerMapPosition()
	if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
		return
	end
	local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
	if not okMap or not mapID then
		return
	end
	local posOk, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
	if not posOk or not pos or not pos.GetXY then
		return
	end
	local xyOk, x, y = pcall(pos.GetXY, pos)
	if not xyOk or not x or not y then
		return
	end
	return mapID, x, y
end

local function ViewRadius()
	if C_Minimap and C_Minimap.GetViewRadius then
		local ok, radius = pcall(C_Minimap.GetViewRadius)
		if ok and type(radius) == "number" and radius > 5 and radius < 2000 then
			return radius
		end
	end
	local zoom = Minimap and Minimap.GetZoom and Minimap:GetZoom() or 0
	local indoors = IsIndoors and IsIndoors()
	local yards = indoors and MINIMAP_YARDS.indoors or MINIMAP_YARDS.outdoors
	return yards[zoom] or yards[0] or 200
end

local function OffsetYards(vendor)
	local playerMap, px, py = PlayerMapPosition()
	if not playerMap then
		return
	end
	if playerMap == vendor.map then
		local width, height = MapSize(playerMap)
		if not width then
			width, height = 2200, 2200
		end
		local dx = (vendor.x - px) * width
		local dy = (py - vendor.y) * height
		return dx, dy, math.sqrt(dx * dx + dy * dy)
	end
	local playerContinent, pwx, pwy = WorldXY(playerMap, px, py)
	local vendorContinent, vwx, vwy = WorldXY(vendor.map, vendor.x, vendor.y)
	if not pwx or not vwx or (playerContinent and vendorContinent and playerContinent ~= vendorContinent) then
		return
	end
	local _, _, top = WorldXY(playerMap, 0, 0)
	local _, _, bottom = WorldXY(playerMap, 0, 1)
	if top and bottom and math.abs(bottom - top) < 50 then
		return
	end
	local dx = vwx - pwx
	local dy = vwy - pwy
	if top and bottom and bottom > top then
		dy = -dy
	end
	return dx, dy, math.sqrt(dx * dx + dy * dy)
end

local function AnchorMinimap(pin, dx, dy, dist)
	local radius = (Minimap:GetWidth() / 2) - 8
	if not radius or radius < 8 then
		radius = 60
	end
	local view = ViewRadius()
	local shown = dist
	if dist > view then
		shown = view
	end
	local scale = radius / view
	local facing = 0
	if GetCVar and GetCVar("rotateMinimap") == "1" and GetPlayerFacing then
		local okFace, face = pcall(GetPlayerFacing)
		if okFace and type(face) == "number" then
			facing = face
		end
	end
	local angle = math.atan2(dx, dy) - facing
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", Minimap, "CENTER", math.sin(angle) * shown * scale, math.cos(angle) * shown * scale)
	pin.distance = dist
	pin.otherZone = false
	pin:Show()
end

local function UpdateMinimapPin(pin)
	local vendor = tracked
	if not vendor or not Minimap then
		pin:Hide()
		return
	end
	local dx, dy, dist = OffsetYards(vendor)
	if not dx then
		pin:ClearAllPoints()
		pin:SetPoint("CENTER", Minimap, "TOP", 0, -6)
		pin.otherZone = true
		pin.distance = nil
		pin:Show()
		return
	end
	AnchorMinimap(pin, dx, dy, dist)
end

local function HideNearPins()
	for i = 1, #nearPins do
		nearPins[i]:Hide()
	end
end

local function CreateNearPin(index)
	local pin = CreateFrame("Button", nil, Minimap)
	pin:SetSize(16, 16)
	pin:SetFrameStrata("MEDIUM")
	pin:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 6)
	local icon = pin:CreateTexture(nil, "OVERLAY")
	icon:SetAllPoints()
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pin.icon = icon
	pin:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(self.label or "Punto")
		if self.distance then
			GameTooltip:AddLine(string.format("A unos %d m", math.floor(self.distance + 0.5)), 1, 1, 1)
		end
		local kind = gatherItemID and DC.SpawnKind and DC.SpawnKind[gatherItemID]
		if kind == "fish" then
			GameTooltip:AddLine("Se pesca en este banco", 0.45, 0.75, 1)
			AddDropLines(gatherItemID, "fish")
			AddFishLines(gatherItemID)
		elseif kind == "herb" or kind == "ore" then
			AddDropLines(gatherItemID, kind)
		end
		GameTooltip:Show()
	end)
	pin:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	pin:Hide()
	nearPins[index] = pin
	return pin
end

local function NearRange()
	local view = ViewRadius()
	if view > 240 then
		return view * 1.15
	end
	return 240
end

local function RefreshNearby()
	if not gatherItemID or not Minimap or (Minimap.IsShown and not Minimap:IsShown()) then
		HideNearPins()
		return
	end
	local stored = DC.Spawns and DC.Spawns[gatherItemID]
	local mapID, px, py = PlayerMapPosition()
	local packed = stored and mapID and stored[mapID]
	if type(packed) ~= "table" or not px or not py then
		HideNearPins()
		return
	end
	local width, height = MapSize(mapID)
	if not width then
		width, height = 2200, 2200
	end
	local reach = NearRange()
	local near = {}
	for i = 1, #packed, 2 do
		local x = packed[i] / 10000
		local y = packed[i + 1] / 10000
		local dx = (x - px) * width
		local dy = (py - y) * height
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist <= reach then
			near[#near + 1] = { dx = dx, dy = dy, dist = dist }
		end
	end
	table.sort(near, function(a, b)
		return a.dist < b.dist
	end)
	local kind = DC.SpawnKind and DC.SpawnKind[gatherItemID] or "ore"
	local label = ItemName(gatherItemID) or (kind == "herb" and "Planta" or kind == "fish" and "Banco" or "Mena")
	local texture = MarkerTexture(kind, gatherItemID)
	local shown = math.min(#near, 18)
	for i = 1, shown do
		local pin = nearPins[i] or CreateNearPin(i)
		if pin.icon then
			pin.icon:SetTexture(texture)
		end
		pin.label = label
		AnchorMinimap(pin, near[i].dx, near[i].dy, near[i].dist)
	end
	for i = shown + 1, #nearPins do
		nearPins[i]:Hide()
	end
end

local routePoints
local routeMap
local routeLines = {}

local function HideRouteLines()
	for i = 1, #routeLines do
		routeLines[i]:Hide()
	end
end

local function ClearRoute()
	routePoints = nil
	routeMap = nil
	HideRouteLines()
end

local function RouteSpan(a, b, width, height)
	local dx = (a.x - b.x) * width
	local dy = (a.y - b.y) * height
	return dx * dx + dy * dy
end

local function ImproveRoute(order, nodes, width, height)
	local count = #order
	if count < 4 or count > 220 then
		return
	end
	local function span(i, j)
		return RouteSpan(nodes[order[i]], nodes[order[j]], width, height)
	end
	for _ = 1, 2 do
		local improved = false
		for i = 1, count - 1 do
			local nextI = i + 1
			for k = i + 2, count do
				local nextK = k == count and 1 or k + 1
				if nextK ~= i then
					local before = span(i, nextI) + span(k, nextK)
					local after = span(i, k) + span(nextI, nextK)
					if after + 1 < before then
						local left, right = nextI, k
						while left < right do
							order[left], order[right] = order[right], order[left]
							left = left + 1
							right = right - 1
						end
						improved = true
					end
				end
			end
		end
		if not improved then
			return
		end
	end
end

local function BuildRoute(nodes, mapID)
	routePoints = nil
	routeMap = nil
	local count = nodes and #nodes or 0
	if count < 2 or not mapID then
		HideRouteLines()
		return
	end
	local width, height = MapSize(mapID)
	if not width or not height or width < 50 or height < 50 then
		width, height = 1, 1
	end
	local startIndex = 1
	local playerMap, px, py = PlayerMapPosition()
	if playerMap == mapID and type(px) == "number" and type(py) == "number" then
		local best = 1e12
		for i = 1, count do
			local dx = nodes[i].x - px
			local dy = nodes[i].y - py
			local dist = dx * dx + dy * dy
			if dist < best then
				best = dist
				startIndex = i
			end
		end
	else
		local north = 2
		for i = 1, count do
			if nodes[i].y < north then
				north = nodes[i].y
				startIndex = i
			end
		end
	end
	local used = {}
	local order = {}
	local current = startIndex
	used[current] = true
	order[1] = current
	for _ = 2, count do
		local from = nodes[current]
		local bestIndex
		local best = 1e12
		for i = 1, count do
			if not used[i] then
				local dist = RouteSpan(from, nodes[i], width, height)
				if dist < best then
					best = dist
					bestIndex = i
				end
			end
		end
		if not bestIndex then
			break
		end
		used[bestIndex] = true
		order[#order + 1] = bestIndex
		current = bestIndex
	end
	ImproveRoute(order, nodes, width, height)
	local points = {}
	for i = 1, #order do
		local node = nodes[order[i]]
		points[i] = { x = node.x, y = node.y }
	end
	points[#points + 1] = points[1]
	routePoints = points
	routeMap = mapID
end

local function RouteFromPins()
	if not showingNodes then
		ClearRoute()
		return
	end
	local nodes = {}
	local mapID
	for i = 1, #pins do
		local pin = pins[i]
		if pin and (pin.kind == "herb" or pin.kind == "ore" or pin.kind == "fish") then
			if not mapID then
				mapID = pin.map
			end
			if pin.map == mapID then
				nodes[#nodes + 1] = pin
			end
		end
	end
	BuildRoute(nodes, mapID)
end

local function DrawRoute()
	local parent = Canvas()
	local mapID = CurrentMap()
	local shown = WorldMapFrame and WorldMapFrame:IsShown()
	if not shown or not parent or not marksVisible or not routePoints or routeMap ~= mapID then
		HideRouteLines()
		return
	end
	local width, height = parent:GetWidth(), parent:GetHeight()
	if not width or not height or width <= 1 or height <= 1 then
		HideRouteLines()
		return
	end
	local used = 0
	for i = 1, #routePoints - 1 do
		local a = routePoints[i]
		local b = routePoints[i + 1]
		local x1 = width * a.x
		local y1 = -height * a.y
		local x2 = width * b.x
		local y2 = -height * b.y
		local dx = x2 - x1
		local dy = y2 - y1
		local length = math.sqrt(dx * dx + dy * dy)
		used = used + 1
		local line = routeLines[used]
		if not line then
			line = parent:CreateTexture(nil, "ARTWORK")
			line:SetTexture("Interface\\Buttons\\WHITE8X8")
			line:SetVertexColor(0.95, 0.08, 0.06, 0.92)
			routeLines[used] = line
		elseif line:GetParent() ~= parent then
			line:SetParent(parent)
		end
		if length < 1 then
			line:Hide()
		else
			line:ClearAllPoints()
			line:SetSize(length, 4)
			line:SetPoint("CENTER", parent, "TOPLEFT", (x1 + x2) * 0.5, (y1 + y2) * 0.5)
			if line.SetRotation then
				line:SetRotation(math.atan2(dy, dx))
			end
			line:Show()
		end
	end
	for i = used + 1, #routeLines do
		routeLines[i]:Hide()
	end
end

local function ClearGather()
	gatherItemID = nil
	showingNodes = false
	nodePinList = nil
	ClearRoute()
	HideNearPins()
end

local function EnsureMinimapPin()
	if minimapPin or not Minimap then
		return minimapPin
	end
	local pin = CreateFrame("Button", nil, Minimap)
	pin:SetSize(20, 20)
	pin:SetFrameStrata("MEDIUM")
	pin:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
	pin:RegisterForClicks("RightButtonUp")
	pin:SetScript("OnUpdate", function(self)
		UpdateMinimapPin(self)
	end)
	local icon = pin:CreateTexture(nil, "OVERLAY")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	pin.icon = icon
	pin:SetScript("OnEnter", function(self)
		if not tracked then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(tracked.name)
		GameTooltip:AddLine(ZoneLabel(tracked.map), 1, 0.82, 0.2)
		if self.otherZone then
			GameTooltip:AddLine("Está en otra zona. Acércate y el punto orientará.", 1, 0.45, 0.35)
		elseif self.distance then
			GameTooltip:AddLine(string.format("A unos %d m", math.floor(self.distance + 0.5)), 1, 1, 1)
		end
		if tracked.chance then
			local verb = tracked.method == "skin" and "desollar" or "matar"
			GameTooltip:AddLine("Aprox. " .. tracked.chance .. "% al " .. verb, 1, 0.82, 0.4)
		end
		GameTooltip:AddLine("Clic derecho para quitar la marca", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	pin:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	pin:SetScript("OnClick", function(self)
		tracked = nil
		self:Hide()
		GameTooltip:Hide()
		Print("Marca del minimapa quitada.")
	end)
	pin:Hide()
	minimapPin = pin
	return pin
end

local function TrackVendor(vendor)
	if not vendor then
		return
	end
	tracked = {
		name = vendor.name,
		map = vendor.map,
		x = vendor.x,
		y = vendor.y,
		method = vendor.method,
		chance = vendor.chance,
	}
	local pin = EnsureMinimapPin()
	if pin then
		if pin.icon then
			pin.icon:SetTexture(MarkerTexture(vendor.kind, viewItemID))
		end
		pin:Show()
		UpdateMinimapPin(pin)
	end
	local where = ZoneLabel(vendor.map)
	Print("Camino hacia " .. vendor.name .. " (" .. where .. "). Clic derecho en el punto del minimapa para quitarlo.")
	if statusText then
		statusText:SetText("Minimapa marcado: " .. vendor.name .. " en " .. where .. ".")
	end
end

local function CreateMarker(index)
	local parent = Canvas()
	if not parent then
		return nil
	end
	local marker = CreateFrame("Button", nil, parent)
	marker:SetSize(26, 26)
	marker:SetFrameLevel(9000)
	marker:EnableMouse(true)
	marker:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local icon = marker:CreateTexture(nil, "OVERLAY")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	marker.icon = icon
	marker:SetScript("OnEnter", function(self)
		local vendor = self.vendor
		if not vendor then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(vendor.name)
		GameTooltip:AddLine(ZoneLabel(vendor.map), 1, 0.82, 0.2)
		if viewItemID then
			GameTooltip:AddLine(ItemName(viewItemID) or "Componente", 0.6, 0.85, 1)
		end
		if vendor.kind == "mob" then
			if vendor.method == "skin" then
				GameTooltip:AddLine("Se desuella al matarlo", 1, 0.55, 0.35)
			else
				GameTooltip:AddLine("Lo suelta al matarlo", 1, 0.55, 0.35)
			end
			AddDropLines(viewItemID, vendor.method)
		elseif vendor.kind == "herb" then
			GameTooltip:AddLine("Se herboriza", 0.4, 0.9, 0.4)
			AddDropLines(viewItemID, "herb")
		elseif vendor.kind == "ore" then
			GameTooltip:AddLine("Se mina", 0.75, 0.75, 0.8)
			AddDropLines(viewItemID, "ore")
		elseif vendor.kind == "fish" then
			GameTooltip:AddLine("Se pesca en este banco", 0.45, 0.75, 1)
			AddDropLines(viewItemID, "fish")
			AddFishLines(viewItemID)
		end
		if vendor.source == "visto" then
			GameTooltip:AddLine("Sitio guardado al visitarlo", 0.4, 1, 0.5)
		end
		if vendor.kind == "herb" or vendor.kind == "ore" or vendor.kind == "fish" then
			GameTooltip:AddLine("Si te acercas, sale en el minimapa", 0.4, 1, 0.5)
		else
			GameTooltip:AddLine("Clic para marcarlo en el minimapa", 0.4, 1, 0.5)
		end
		GameTooltip:AddLine("Clic derecho para quitar este punto", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	marker:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	marker:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			if self.vendor then
				for i = #pins, 1, -1 do
					if pins[i] == self.vendor then
						table.remove(pins, i)
					end
				end
			end
			self:Hide()
			GameTooltip:Hide()
			if showingNodes then
				RouteFromPins()
				DrawRoute()
			end
			if RefreshMarksButton then
				RefreshMarksButton()
			end
			return
		end
		if self.vendor and self.vendor.kind ~= "herb" and self.vendor.kind ~= "ore" and self.vendor.kind ~= "fish" then
			TrackVendor(self.vendor)
		end
	end)
	marker:Hide()
	markers[index] = marker
	return marker
end

local function PlaceMarker(marker, vendor, parent)
	if marker:GetParent() ~= parent then
		marker:SetParent(parent)
	end
	marker.vendor = vendor
	local base = (vendor.kind == "herb" or vendor.kind == "ore" or vendor.kind == "fish") and 16 or 26
	local scale = db and tonumber(db.iconScale) or 1
	if not scale or scale < 0.5 then
		scale = 0.5
	elseif scale > 2.5 then
		scale = 2.5
	end
	local size = math.floor(base * scale + 0.5)
	if size < 8 then
		size = 8
	end
	marker:SetSize(size, size)
	if marker.icon then
		marker.icon:SetTexture(MarkerTexture(vendor.kind, viewItemID))
	end
	local placed = false
	if WorldMapFrame and type(WorldMapFrame.SetPinPosition) == "function" then
		placed = pcall(WorldMapFrame.SetPinPosition, WorldMapFrame, marker, vendor.x, vendor.y)
	end
	if not placed then
		local width, height = parent:GetWidth(), parent:GetHeight()
		if not width or not height or width <= 1 or height <= 1 then
			return
		end
		marker:ClearAllPoints()
		marker:SetPoint("CENTER", parent, "TOPLEFT", width * vendor.x, -height * vendor.y)
	end
	marker:Show()
end

local function UpdatePins()
	local parent = Canvas()
	local mapID = CurrentMap()
	local shown = WorldMapFrame and WorldMapFrame:IsShown()
	local used = 0
	if shown and parent and mapID and marksVisible then
		for i = 1, #pins do
			local vendor = pins[i]
			if vendor.map == mapID then
				used = used + 1
				local marker = markers[used] or CreateMarker(used)
				if marker then
					PlaceMarker(marker, vendor, parent)
				end
			end
		end
	end
	for i = used + 1, #markers do
		markers[i]:Hide()
	end
	DrawRoute()
end

local function ClearPins()
	wipe(pins)
	ClearRoute()
	UpdatePins()
	if RefreshMarksButton then
		RefreshMarksButton()
	end
end

local function ClearTracked()
	tracked = nil
	if minimapPin then
		minimapPin:Hide()
	end
	if minimapPin and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(minimapPin) then
		GameTooltip:Hide()
	end
end

local function ClearMarksAfterPurchase()
	if showingNodes then
		return
	end
	local hadMarks = pins[1] ~= nil or tracked ~= nil
	resultVendors = nil
	ClearPins()
	ClearTracked()
	if hadMarks then
		if statusText then
			statusText:SetText("Marcas quitadas. Ya has cerrado el comercio.")
		end
		Print("Marcas quitadas al cerrar el comercio.")
	end
end

RefreshMarksButton = function()
	if not marksButton then
		return
	end
	if marksVisible and pins[1] then
		marksButton:SetText("Ocultar marcas")
	else
		marksButton:SetText("Mostrar marcas")
	end
end

local function ShowMap(mapID)
	if not WorldMapFrame then
		return
	end
	if not WorldMapFrame:IsShown() and ToggleWorldMap then
		ToggleWorldMap()
	end
	if mapID and type(WorldMapFrame.SetMapID) == "function" then
		pcall(WorldMapFrame.SetMapID, WorldMapFrame, mapID)
	elseif mapID and C_Map and C_Map.OpenWorldMap then
		pcall(C_Map.OpenWorldMap, mapID)
	end
	UpdatePins()
end

local function ShowVendorPin(vendor)
	if not vendor then
		return
	end
	marksVisible = true
	local present = false
	for i = 1, #pins do
		if pins[i] == vendor then
			present = true
			break
		end
	end
	if not present then
		if #pins >= 15 then
			table.remove(pins, 1)
		end
		pins[#pins + 1] = vendor
	end
	RefreshMarksButton()
	ShowMap(vendor.map)
end

local function ToggleMarks()
	if marksVisible and pins[1] then
		marksVisible = false
		UpdatePins()
		RefreshMarksButton()
		return
	end
	if not pins[1] and nodePinList and nodePinList[1] then
		for i = 1, #nodePinList do
			pins[i] = nodePinList[i]
		end
		RouteFromPins()
	elseif not pins[1] and resultVendors and resultVendors[1] then
		for i = 1, math.min(#resultVendors, 15) do
			pins[i] = resultVendors[i]
		end
	end
	marksVisible = pins[1] and true or false
	RefreshMarksButton()
	if marksVisible and pins[1] then
		ShowMap(pins[1].map)
	else
		UpdatePins()
	end
end

local function MarkVendors(list, focusMap)
	marksVisible = true
	ClearRoute()
	wipe(pins)
	for i = 1, math.min(#list, 15) do
		pins[i] = list[i]
	end
	if RefreshMarksButton then
		RefreshMarksButton()
	end
	if focusMap then
		ShowMap(focusMap)
	else
		UpdatePins()
	end
end

local function SetStatus(text)
	if statusText then
		statusText:SetText(text or "")
	end
end

local function FactionNote(vendor)
	local side = PlayerSide()
	if vendor.faction == "N" or vendor.faction == side or side == "N" then
		return nil
	end
	return "Otra facción"
end

local function HideRows()
	for i = 1, #resultButtons do
		resultButtons[i]:Hide()
	end
end

local function Row(index)
	local button = resultButtons[index]
	if button then
		return button
	end
	button = CreateFrame("Button", nil, resultChild)
	button:SetSize(410, ROW - 4)
	button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(28, 28)
	icon:SetPoint("LEFT", 6, 0)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon
	local title = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 8, -1)
	title:SetPoint("RIGHT", -8, 0)
	title:SetJustifyH("LEFT")
	button.title = title
	local detail = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	detail:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 8, 1)
	detail:SetPoint("RIGHT", -8, 0)
	detail:SetJustifyH("LEFT")
	button.detail = detail
	button:SetScript("OnClick", function(self)
		if self.onClick then
			self.onClick()
		end
	end)
	button:SetScript("OnEnter", function(self)
		if not self.tip then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tipTitle or (self.title and self.title:GetText()) or "")
		GameTooltip:AddLine(self.tip, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	resultButtons[index] = button
	return button
end

local function LayoutRows(count)
	HideRows()
	for i = 1, count do
		local button = Row(i)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", resultChild, "TOPLEFT", 4, -((i - 1) * ROW))
		button:Show()
	end
	resultChild:SetHeight(math.max(count * ROW, 1))
end

local function ShowFarm(itemID, typed)
	ClearGather()
	viewItemID = itemID
	resultVendors = nil
	ClearPins()
	local label = (itemID and ItemName(itemID)) or typed or "Ese objeto"
	LayoutRows(1)
	local button = Row(1)
	button.icon:SetTexture(itemID and ItemIcon(itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
	button.title:SetText(label)
	button.detail:SetText("Sin sitio conocido")
	button.tipTitle = label
	button.tip = "No tengo un sitio guardado. Farmealo, o cómpralo en la casa de subastas."
	button.onClick = nil
	SetStatus("No tengo vendedor, bicho, planta, mena, banco ni desencante para este objeto. Farmealo, o cómpralo en la casa de subastas.")
	if HighlightMerchantSearch then
		HighlightMerchantSearch()
	end
end

local function ShowVendors(itemID, list, otherFaction)
	ClearGather()
	viewItemID = itemID
	resultVendors = list
	SortVendors(list)
	local focus = list[1] and list[1].map
	MarkVendors(list, focus)
	LayoutRows(#list)
	for i = 1, #list do
		local vendor = list[i]
		local button = Row(i)
		button.icon:SetTexture(ItemIcon(itemID))
		button.title:SetText(vendor.name)
		local bits
		if vendor.kind == "mob" then
			bits = {
				"Bicho",
				ZoneLabel(vendor.map),
				string.format("%d, %d", math.floor(vendor.x * 100 + 0.5), math.floor(vendor.y * 100 + 0.5)),
				vendor.method == "skin" and "desuello" or "botín",
			}
			if vendor.chance then
				bits[#bits + 1] = "aprox. " .. vendor.chance .. "%"
			end
		elseif vendor.kind == "herb" or vendor.kind == "ore" or vendor.kind == "fish" then
			local nodeName = "Mena"
			if vendor.kind == "herb" then
				nodeName = "Planta"
			elseif vendor.kind == "fish" then
				nodeName = "Banco"
			end
			bits = {
				nodeName,
				ZoneLabel(vendor.map),
				string.format("%d, %d", math.floor(vendor.x * 100 + 0.5), math.floor(vendor.y * 100 + 0.5)),
			}
		else
			bits = {
				ZoneLabel(vendor.map),
				string.format("%d, %d", math.floor(vendor.x * 100 + 0.5), math.floor(vendor.y * 100 + 0.5)),
			}
			local enemy = FactionNote(vendor)
			if enemy then
				bits[#bits + 1] = enemy
			end
			if vendor.source == "visto" then
				bits[#bits + 1] = "visto por ti"
			end
		end
		if SameMapDistance(vendor) then
			bits[#bits + 1] = "en tu zona"
		end
		button.detail:SetText(table.concat(bits, " · "))
		button.tipTitle = vendor.name
		if vendor.kind == "mob" then
			button.tip = "Clic para seguir a este bicho en el minimapa."
		elseif vendor.kind == "herb" or vendor.kind == "ore" or vendor.kind == "fish" then
			button.tip = "Clic para centrar el mapa en este punto."
		else
			button.tip = "Clic para marcar a este vendedor en el mapa y seguirlo en el minimapa."
		end
		button.onClick = function()
			ShowVendorPin(vendor)
		end
	end
	local name = ItemName(itemID) or "Objeto"
	local vendorCount, mobCount, herbCount, oreCount = 0, 0, 0, 0
	for i = 1, #list do
		local kind = list[i].kind
		if kind == "mob" then
			mobCount = mobCount + 1
		elseif kind == "herb" then
			herbCount = herbCount + 1
		elseif kind == "ore" then
			oreCount = oreCount + 1
		else
			vendorCount = vendorCount + 1
		end
	end
	local parts = {}
	if vendorCount > 0 then
		parts[#parts + 1] = vendorCount .. (vendorCount == 1 and " vendedor" or " vendedores")
	end
	if mobCount > 0 then
		parts[#parts + 1] = mobCount .. (mobCount == 1 and " bicho" or " bichos")
	end
	if herbCount > 0 then
		parts[#parts + 1] = herbCount .. (herbCount == 1 and " planta" or " plantas")
	end
	if oreCount > 0 then
		parts[#parts + 1] = oreCount .. (oreCount == 1 and " mena" or " menas")
	end
	local summary = table.concat(parts, " y ")
	if otherFaction and vendorCount > 0 then
		summary = "La venta es de la otra facción. " .. summary
	end
	if #list > 15 then
		SetStatus(name .. ": marco los 15 primeros. En la lista hay " .. summary .. ".")
	else
		SetStatus(name .. ": " .. summary .. " en el mapa.")
	end
	if HighlightMerchantSearch then
		HighlightMerchantSearch()
	end
end

local function ShowMatches(ids, query)
	ClearGather()
	viewItemID = nil
	resultVendors = nil
	ClearPins()
	table.sort(ids, function(a, b)
		return Norm(ItemName(a) or "") < Norm(ItemName(b) or "")
	end)
	local count = math.min(#ids, 20)
	LayoutRows(count)
	for i = 1, count do
		local itemID = ids[i]
		local button = Row(i)
		button.icon:SetTexture(ItemIcon(itemID))
		button.title:SetText(ItemName(itemID) or ("Objeto " .. itemID))
		button.detail:SetText("Pulsa para ver dónde conseguirlo")
		button.tipTitle = ItemName(itemID) or ("Objeto " .. itemID)
		button.tip = "Clic para ver vendedores, bichos, nodos o el desencante de este objeto."
		button.onClick = function()
			DC.ShowItem(itemID)
		end
	end
	if #ids > 20 then
		SetStatus("Hay muchos objetos con «" .. query .. "». Afina el nombre.")
	else
		SetStatus("Varios objetos coinciden. Elige uno.")
	end
	if HighlightMerchantSearch then
		HighlightMerchantSearch()
	end
end

local function NodeWord(kind, count)
	if kind == "herb" then
		if count == 1 then
			return "1 planta"
		end
		return count .. " plantas"
	end
	if kind == "fish" then
		if count == 1 then
			return "1 banco"
		end
		return count .. " bancos"
	end
	if count == 1 then
		return "1 mena"
	end
	return count .. " menas"
end

local function ZonesFor(itemID)
	local stored = DC.Spawns and DC.Spawns[itemID]
	if type(stored) ~= "table" then
		return {}
	end
	local kind = DC.SpawnKind and DC.SpawnKind[itemID] or "ore"
	local list = {}
	for mapID, packed in pairs(stored) do
		if type(packed) == "table" and #packed >= 2 then
			list[#list + 1] = {
				map = mapID,
				count = math.floor(#packed / 2),
				kind = kind,
			}
		end
	end
	local playerMap = PlayerMapPosition()
	table.sort(list, function(a, b)
		local aHere = playerMap and a.map == playerMap
		local bHere = playerMap and b.map == playerMap
		if aHere ~= bHere then
			return aHere and true or false
		end
		if a.count ~= b.count then
			return a.count > b.count
		end
		return tostring(ZoneLabel(a.map)) < tostring(ZoneLabel(b.map))
	end)
	return list
end

local function NodePoints(itemID, mapID)
	local stored = DC.Spawns and DC.Spawns[itemID]
	local packed = stored and stored[mapID]
	local list = {}
	if type(packed) ~= "table" then
		return list
	end
	local kind = DC.SpawnKind and DC.SpawnKind[itemID] or "ore"
	local label = ItemName(itemID) or (kind == "herb" and "Planta" or kind == "fish" and "Banco" or "Mena")
	for i = 1, #packed, 2 do
		local x = packed[i]
		local y = packed[i + 1]
		if x and y then
			list[#list + 1] = {
				name = label,
				map = mapID,
				x = x / 10000,
				y = y / 10000,
				faction = "N",
				kind = kind,
				source = "nodo",
			}
		end
	end
	return list
end

local function MarkZone(itemID, mapID)
	local nodes = NodePoints(itemID, mapID)
	nodePinList = nodes
	marksVisible = true
	wipe(pins)
	for i = 1, #nodes do
		pins[i] = nodes[i]
	end
	if RefreshMarksButton then
		RefreshMarksButton()
	end
	BuildRoute(nodes, mapID)
	ShowMap(mapID)
end

local function ZoneStatus(itemID, zones, focusMap)
	local total = 0
	local focusCount = 0
	for i = 1, #zones do
		total = total + zones[i].count
		if zones[i].map == focusMap then
			focusCount = zones[i].count
		end
	end
	local kind = DC.SpawnKind and DC.SpawnKind[itemID] or "ore"
	local name = ItemName(itemID) or "Objeto"
	local zoneWord = #zones == 1 and "zona" or "zonas"
	local note = ""
	if focusCount >= 2 then
		note = " Línea roja: ruta recomendada."
	end
	if kind == "fish" then
		note = note .. " Pasa el ratón por un banco para ver el agua abierta."
	end
	SetStatus(name .. ": " .. NodeWord(kind, total) .. " en " .. #zones .. " " .. zoneWord .. ". Marco " .. NodeWord(kind, focusCount) .. " en " .. ZoneLabel(focusMap) .. ". Si te acercas, salen en el minimapa." .. note)
end

local function ShowZones(itemID, zones)
	viewItemID = itemID
	gatherItemID = itemID
	showingNodes = true
	resultVendors = nil
	local focus = zones[1].map
	MarkZone(itemID, focus)
	RefreshNearby()
	LayoutRows(#zones)
	local playerMap = PlayerMapPosition()
	for i = 1, #zones do
		local zone = zones[i]
		local button = Row(i)
		button.icon:SetTexture(ItemIcon(itemID))
		local here = playerMap == zone.map and " · estás aquí" or ""
		button.title:SetText(ZoneLabel(zone.map))
		button.detail:SetText(NodeWord(zone.kind, zone.count) .. here)
		button.tipTitle = ZoneLabel(zone.map)
		button.tip = "Clic para marcar todos los puntos de esta zona y la ruta roja."
		button.onClick = function()
			MarkZone(itemID, zone.map)
			ZoneStatus(itemID, zones, zone.map)
		end
	end
	ZoneStatus(itemID, zones, focus)
	if HighlightMerchantSearch then
		HighlightMerchantSearch()
	end
end

local function ShowDisenchant(itemID)
	ClearGather()
	viewItemID = itemID
	resultVendors = nil
	ClearPins()
	local rule = DC.Disenchant[itemID]
	local sources = rule.sources or {}
	local rows = #sources
	if rule.swap then
		rows = rows + 1
	end
	LayoutRows(rows)
	for i = 1, #sources do
		local source = sources[i]
		local button = Row(i)
		button.icon:SetTexture(ItemIcon(itemID))
		button.title:SetText(source.quality .. ", nivel de objeto " .. source.min .. "-" .. source.max)
		local detail = "Desencantar"
		if source.chance then
			detail = detail .. " · " .. source.chance .. "%"
		end
		button.detail:SetText(detail .. " · " .. source.amount .. " · " .. source.where)
		button.tipTitle = source.quality .. ", nivel " .. source.min .. "-" .. source.max
		button.tip = "Así se consigue al desencantar. Esta fila no marca el mapa."
		button.onClick = nil
	end
	if rule.swap then
		local button = Row(rows)
		button.icon:SetTexture(ItemIcon(rule.swap))
		local other = ItemName(rule.swap) or "la otra esencia"
		button.title:SetText("Convertir en el encantador")
		if rule.fromThree then
			button.detail:SetText("3 de " .. other .. " hacen 1 de este. 1 de este se parte en 3.")
		else
			button.detail:SetText("1 de " .. other .. " se parte en 3 de este. 3 de este hacen 1.")
		end
		button.tipTitle = "Convertir en el encantador"
		button.tip = "Clic para ver de dónde sale la otra esencia."
		button.onClick = function()
			DC.ShowItem(rule.swap)
		end
	end
	local name = ItemName(itemID) or "Material"
	SetStatus(name .. ": el porcentaje es la tirada al desencantar un arma o armadura de ese nivel de objeto, también anillos, collares y capas. Vale cualquiera. Un blanco, una bolsa o un objeto de misión no sirve.")
	if HighlightMerchantSearch then
		HighlightMerchantSearch()
	end
end

function DC.ShowItem(itemID)
	EnsureDB()
	RequestNames()
	local zones = ZonesFor(itemID)
	if zones[1] then
		ShowZones(itemID, zones)
		return
	end
	if DC.Disenchant and DC.Disenchant[itemID] then
		ShowDisenchant(itemID)
		return
	end
	ClearGather()
	local vendors = MergeVendors(itemID)
	local home, enemy = SplitFaction(vendors)
	local list = {}
	local otherFaction = false
	if #home > 0 then
		for i = 1, #home do
			list[#list + 1] = home[i]
		end
	elseif #enemy > 0 then
		otherFaction = true
		for i = 1, #enemy do
			list[#list + 1] = enemy[i]
		end
	end
	local mobs = MobsFor(itemID)
	for i = 1, #mobs do
		list[#list + 1] = mobs[i]
	end
	if #list > 0 then
		ShowVendors(itemID, list, otherFaction)
	else
		ShowFarm(itemID, ItemName(itemID))
	end
end

local function NamesReady()
	for _, list in pairs(DC.Stock or {}) do
		for i = 1, #list do
			if not names[list[i]] and not ItemName(list[i]) then
				return false
			end
		end
	end
	local ready = true
	EachStoredDrop(function(id)
		if not names[id] and not ItemName(id) then
			ready = false
		end
	end)
	return ready
end

local function Search(raw, generation)
	EnsureDB()
	RequestNames()
	if not generation then
		searchGeneration = searchGeneration + 1
		generation = searchGeneration
		searchRetries = 0
	end
	if generation ~= searchGeneration then
		return
	end
	local text = Plain(raw or "")
	if text == "" then
		SetStatus("Escribe el nombre del componente, o Mayús-clic en él.")
		return
	end
	local asID = tonumber(text)
	if asID then
		DC.ShowItem(asID)
		return
	end
	local query = Norm(text)
	if #query < 3 then
		SetStatus("Escribe al menos tres letras.")
		return
	end
	local exact, starts, contains = {}, {}, {}
	local seen = {}
	local function Consider(itemID)
		if seen[itemID] then
			return
		end
		local name = ItemName(itemID)
		if not name then
			return
		end
		seen[itemID] = true
		local n = Norm(name)
		if n == query then
			exact[#exact + 1] = itemID
		elseif n:sub(1, #query) == query then
			starts[#starts + 1] = itemID
		elseif n:find(query, 1, true) then
			contains[#contains + 1] = itemID
		end
	end
	for _, list in pairs(DC.Stock or {}) do
		for i = 1, #list do
			Consider(list[i])
		end
	end
	EachStoredDrop(Consider)
	if db and db.learned then
		for key in pairs(db.learned) do
			Consider(tonumber(key) or key)
		end
	end
	local ids = #exact > 0 and exact or (#starts > 0 and starts or contains)
	matchIDs = ids
	if #ids == 0 then
		if not NamesReady() and searchRetries < 8 then
			searchRetries = searchRetries + 1
			SetStatus("Cargando los nombres de los componentes...")
			C_Timer.After(0.4, function()
				Search(text, generation)
			end)
			return
		end
		searchRetries = 0
		ShowFarm(nil, text)
		return
	end
	searchRetries = 0
	if #ids == 1 then
		DC.ShowItem(ids[1])
		return
	end
	ShowMatches(ids, text)
end

local merchantGlows = {}
local merchantPaging = false
local merchantJumpedFor
local merchantGlowSuppressed = false

local function MerchantSlotItemID(index)
	if GetMerchantItemID then
		local ok, id = pcall(GetMerchantItemID, index)
		if ok and type(id) == "number" then
			return id
		end
	end
	if GetMerchantItemLink then
		local ok, link = pcall(GetMerchantItemLink, index)
		if ok and type(link) == "string" then
			return tonumber(link:match("item:(%d+)"))
		end
	end
end

local function MerchantPageSize()
	if type(MERCHANT_ITEMS_PER_PAGE) == "number" and MERCHANT_ITEMS_PER_PAGE > 0 then
		return MERCHANT_ITEMS_PER_PAGE
	end
	local count = 0
	for i = 1, 20 do
		if not _G["MerchantItem" .. i .. "ItemButton"] then
			break
		end
		count = i
	end
	if count > 0 then
		return count
	end
	return 10
end

local function HideMerchantGlows()
	for _, glow in pairs(merchantGlows) do
		glow:Hide()
		if glow.pulse then
			glow.pulse:Stop()
		end
	end
end

local function EnsureMerchantGlow(button)
	local glow = merchantGlows[button]
	if glow then
		return glow
	end
	glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(1, 0.86, 0.28, 1)
	glow:SetPoint("TOPLEFT", button, "TOPLEFT", -8, 8)
	glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 8, -8)
	glow:Hide()
	local okPulse, pulse = pcall(function()
		local group = glow:CreateAnimationGroup()
		group:SetLooping("BOUNCE")
		local fade = group:CreateAnimation("Alpha")
		fade:SetFromAlpha(0.3)
		fade:SetToAlpha(1)
		fade:SetDuration(0.55)
		if fade.SetSmoothing then
			fade:SetSmoothing("IN_OUT")
		end
		return group
	end)
	if okPulse then
		glow.pulse = pulse
	end
	merchantGlows[button] = glow
	return glow
end

local function ShowMerchantGlow(button)
	local glow = EnsureMerchantGlow(button)
	glow:SetAlpha(1)
	glow:Show()
	if glow.pulse and not glow.pulse:IsPlaying() then
		glow.pulse:Play()
	end
end

local function ForMerchantButtons(apply)
	local seen = false
	for i = 1, 20 do
		local button = _G["MerchantItem" .. i .. "ItemButton"]
		if not button then
			break
		end
		seen = true
		if button:IsShown() then
			apply(button, i)
		end
	end
	if seen then
		return
	end
	local box = MerchantFrame and MerchantFrame.ScrollBox
	if not box or not box.GetFrames then
		return
	end
	local ok, frames = pcall(box.GetFrames, box)
	if not ok or type(frames) ~= "table" then
		return
	end
	for _, row in ipairs(frames) do
		local button = row.ItemButton or row.itemButton
		if button and button:IsShown() then
			apply(button)
		end
	end
end

HighlightMerchantSearch = function()
	if merchantPaging then
		return
	end
	HideMerchantGlows()
	if merchantGlowSuppressed or not viewItemID or not MerchantFrame or not MerchantFrame:IsShown() then
		return
	end
	if MerchantFrame.selectedTab and MerchantFrame.selectedTab ~= 1 then
		return
	end
	local count = 0
	if GetMerchantNumItems then
		local ok, total = pcall(GetMerchantNumItems)
		if ok and type(total) == "number" then
			count = total
		end
	end
	if count <= 0 then
		return
	end
	local targets = {}
	for index = 1, count do
		if MerchantSlotItemID(index) == viewItemID then
			targets[#targets + 1] = index
		end
	end
	if not targets[1] then
		return
	end
	local perPage = MerchantPageSize()
	local page = MerchantFrame.page or 1
	local npc = ""
	if UnitName then
		local okName, name = pcall(UnitName, "npc")
		if okName and type(name) == "string" then
			npc = name
		end
	end
	local token = tostring(viewItemID) .. ":" .. npc
	if merchantJumpedFor ~= token and MerchantFrame.page and perPage > 0 then
		merchantJumpedFor = token
		local wanted = math.floor((targets[1] - 1) / perPage) + 1
		if MerchantFrame.page ~= wanted and type(MerchantFrame_Update) == "function" then
			merchantPaging = true
			MerchantFrame.page = wanted
			MerchantFrame_Update()
			merchantPaging = false
			page = wanted
		end
	end
	for i = 1, #targets do
		local index = targets[i]
		local itemPage = math.floor((index - 1) / perPage) + 1
		if itemPage == page then
			local slot = index - ((page - 1) * perPage)
			local slotButton = _G["MerchantItem" .. slot .. "ItemButton"]
			if slotButton and slotButton:IsShown() then
				ShowMerchantGlow(slotButton)
			end
		end
	end
	if not _G["MerchantItem1ItemButton"] then
		ForMerchantButtons(function(button)
			local index = button.GetID and button:GetID()
			if type(index) == "number" and MerchantSlotItemID(index) == viewItemID then
				ShowMerchantGlow(button)
			end
		end)
	end
end

if type(hooksecurefunc) == "function" then
	if type(MerchantFrame_Update) == "function" then
		hooksecurefunc("MerchantFrame_Update", HighlightMerchantSearch)
	elseif type(MerchantFrame_UpdateMerchantInfo) == "function" then
		hooksecurefunc("MerchantFrame_UpdateMerchantInfo", HighlightMerchantSearch)
	end
end

if MerchantFrame and MerchantFrame.HookScript then
	MerchantFrame:HookScript("OnHide", function()
		merchantGlowSuppressed = true
		HideMerchantGlows()
	end)
end

local function RememberMerchant()
	EnsureDB()
	if not MerchantFrame or not MerchantFrame:IsShown() then
		return
	end
	local okName, npc = pcall(UnitName, "npc")
	if not okName or type(npc) ~= "string" or npc == "" then
		return
	end
	if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
		return
	end
	local okMap, mapID = pcall(C_Map.GetBestMapForUnit, "player")
	if not okMap or not mapID then
		return
	end
	local okPos, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
	if not okPos or not pos or not pos.GetXY then
		return
	end
	local okXY, x, y = pcall(pos.GetXY, pos)
	if not okXY or not x or not y or x <= 0 or y <= 0 then
		return
	end
	local count = GetMerchantNumItems and GetMerchantNumItems() or 0
	if count <= 0 then
		return
	end
	local faction = SideOf("npc")
	local saved = 0
	for index = 1, count do
		local itemID = GetMerchantItemID and GetMerchantItemID(index)
		if not itemID and GetMerchantItemLink then
			local link = GetMerchantItemLink(index)
			itemID = link and tonumber(link:match("item:(%d+)"))
		end
		if itemID then
			ItemName(itemID)
			local key = itemID
			local bucket = db.learned[key]
			if not bucket then
				bucket = {}
				db.learned[key] = bucket
			end
			local cost
			if GetMerchantItemInfo then
				local okInfo, _, _, price = pcall(GetMerchantItemInfo, index)
				if okInfo and type(price) == "number" and price > 0 then
					cost = price
				end
			end
			local replaced = false
			for i = 1, #bucket do
				local vendor = bucket[i]
				if vendor and Norm(vendor.name or "") == Norm(npc) and vendor.map == mapID then
					vendor.x = x
					vendor.y = y
					vendor.faction = faction
					vendor.cost = cost or vendor.cost
					replaced = true
					break
				end
			end
			if not replaced then
				bucket[#bucket + 1] = {
					name = npc,
					map = mapID,
					x = x,
					y = y,
					faction = faction,
					cost = cost,
				}
			end
			saved = saved + 1
		end
	end
	if saved > 0 and not db.announcedLearn then
		db.announcedLearn = true
		Print("Cuando abras un vendedor, recuerdo lo que vende y el sitio exacto.")
	end
end

local function MakeBackdrop(parent)
	local bg = parent:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture("Interface\\Buttons\\WHITE8X8")
	bg:SetVertexColor(0.06, 0.06, 0.08, 0.94)
	local function Edge(point, relative, horizontal)
		local line = parent:CreateTexture(nil, "BORDER")
		line:SetTexture("Interface\\Buttons\\WHITE8X8")
		line:SetVertexColor(0.78, 0.62, 0.28, 1)
		line:SetPoint(point, parent, point, 0, 0)
		line:SetPoint(relative, parent, relative, 0, 0)
		if horizontal then
			line:SetHeight(1)
		else
			line:SetWidth(1)
		end
	end
	Edge("TOPLEFT", "TOPRIGHT", true)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
	Edge("TOPLEFT", "BOTTOMLEFT", false)
	Edge("TOPRIGHT", "BOTTOMRIGHT", false)
end

local scaleBar

local function UpdateScaleBar()
	if not db then
		return
	end
	if not scaleBar then
		local barOk, created = pcall(CreateFrame, "Frame", "WhereIsScaleBar", UIParent, "BackdropTemplate")
		local bar = barOk and created or CreateFrame("Frame", "WhereIsScaleBar", UIParent)
		bar:SetSize(260, 36)
		bar:SetFrameStrata("HIGH")
		bar:SetClampedToScreen(true)
		bar:SetMovable(true)
		bar:EnableMouse(true)
		bar:RegisterForDrag("LeftButton")
		if bar.SetBackdrop then
			local styled = pcall(bar.SetBackdrop, bar, {
				bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
				tile = true,
				tileSize = 256,
				edgeSize = 24,
				insets = { left = 4, right = 4, top = 4, bottom = 4 },
			})
			if not styled then
				MakeBackdrop(bar)
			end
		else
			MakeBackdrop(bar)
		end
		if db.scaleBar then
			bar:SetPoint(db.scaleBar[1], UIParent, db.scaleBar[2], db.scaleBar[3], db.scaleBar[4])
		else
			bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 160)
		end
		bar:SetScript("OnDragStart", function(self)
			self:StartMoving()
		end)
		bar:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local point, _, relative, x, y = self:GetPoint(1)
			db.scaleBar = { point, relative, x, y }
		end)
		bar:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText("Escala de los iconos del mapa")
			GameTooltip:AddLine("Arrastra la palabra Escala para mover la barra.", 1, 1, 1)
			GameTooltip:Show()
		end)
		bar:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)

		local label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		label:SetPoint("LEFT", 10, 0)
		label:SetText("Escala")

		local valueText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		valueText:SetPoint("RIGHT", -10, 0)
		valueText:SetWidth(42)
		valueText:SetJustifyH("RIGHT")

		local slider = CreateFrame("Slider", nil, bar)
		slider:SetPoint("LEFT", label, "RIGHT", 10, 0)
		slider:SetPoint("RIGHT", valueText, "LEFT", -8, 0)
		slider:SetHeight(16)
		slider:SetOrientation("HORIZONTAL")
		slider:SetMinMaxValues(50, 250)
		slider:SetValueStep(5)
		if slider.SetObeyStepOnDrag then
			slider:SetObeyStepOnDrag(true)
		end
		local track = slider:CreateTexture(nil, "BACKGROUND")
		track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
		track:SetPoint("LEFT")
		track:SetPoint("RIGHT")
		track:SetHeight(8)
		slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
		local thumb = slider:GetThumbTexture()
		if thumb then
			thumb:SetSize(24, 24)
		end
		slider:SetScript("OnValueChanged", function(_, value)
			local percent = math.floor((tonumber(value) or 100) / 5 + 0.5) * 5
			if percent < 50 then
				percent = 50
			elseif percent > 250 then
				percent = 250
			end
			valueText:SetText(percent .. "%")
			db.iconScale = percent / 100
			UpdatePins()
		end)
		local start = math.floor(((tonumber(db.iconScale) or 1) * 100) / 5 + 0.5) * 5
		if start < 50 then
			start = 50
		elseif start > 250 then
			start = 250
		end
		slider:SetValue(start)
		bar:Hide()
		scaleBar = bar
	end
	local mapOpen = WorldMapFrame and WorldMapFrame:IsShown()
	local addonOpen = frame and frame:IsShown()
	if mapOpen or addonOpen then
		scaleBar:Show()
	else
		scaleBar:Hide()
	end
end

local function ButtonTip(widget, title, line)
	if not widget then
		return
	end
	local function ShowTip(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local name = type(title) == "function" and title(self) or title
		local text = type(line) == "function" and line(self) or line
		GameTooltip:SetText(name or "")
		if text and text ~= "" then
			GameTooltip:AddLine(text, 1, 1, 1, true)
		end
		GameTooltip:Show()
	end
	local function HideTip()
		GameTooltip:Hide()
	end
	if widget:GetScript("OnEnter") and widget.HookScript then
		widget:HookScript("OnEnter", ShowTip)
		widget:HookScript("OnLeave", HideTip)
	else
		widget:SetScript("OnEnter", ShowTip)
		widget:SetScript("OnLeave", HideTip)
	end
end

local HELP_TEXT = table.concat({
	"Escribe un componente, o haz Mayús-clic en él dentro de la mochila.",
	"",
	"|cffffd100Qué busca|r",
	"Vendedores, bichos, plantas, menas, bancos de pesca y desencantar.",
	"Si no hay sitio, te dice que lo farmees o lo compres en la casa de subastas.",
	"",
	"|cffffd100Mapa|r",
	"Cada resultado se marca en el mapa de la zona. En plantas, menas y bancos marca todos los puntos y pinta una línea roja con la ruta recomendada.",
	"Clic izquierdo en un vendedor o un bicho lo sigue en el minimapa. Clic derecho en ese punto lo quita.",
	"Clic derecho en un punto del mapa quita solo ese punto.",
	"Si te acercas a una planta, mena o banco, el icono sale también en el minimapa.",
	"",
	"|cffffd100Porcentajes|r",
	"Al desencantar, el porcentaje es la tirada fija de ese nivel de objeto.",
	"Al matar, desollar o pescar, es una tasa habitual redondeada. Cambia de un bicho a otro.",
	"Herborizar o minar ese nodo es el 100%.",
	"",
	"|cffffd100Ventana|r",
	"Quitar marcas borra los puntos. Ocultar marcas los esconde sin perderlos.",
	"La barra Escala, que sale con el mapa o con esta ventana, cambia el tamaño de los iconos. Arrástrala por la palabra Escala.",
	"El catalejo del minimapa abre el addon. Arrástralo por el borde para moverlo.",
	"",
	"|cffffd100Órdenes|r",
	"/whereis o /where abre y cierra. /whereis cobre busca ese objeto. /whereis limpiar quita las marcas. /donde sigue valiendo.",
}, "\n")

local helpFrame

local function EnsureHelpFrame()
	if helpFrame then
		return helpFrame
	end
	local portraitOk, created = pcall(CreateFrame, "Frame", "WhereIsHelpFrame", UIParent, "PortraitFrameTemplate")
	local popup = portraitOk and created or CreateFrame("Frame", "WhereIsHelpFrame", UIParent, "BackdropTemplate")
	if not portraitOk then
		if popup.SetBackdrop then
			popup:SetBackdrop({
				bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
				tile = true,
				tileSize = 256,
				edgeSize = 32,
				insets = { left = 8, right = 8, top = 8, bottom = 8 },
			})
		end
	end
	popup:SetSize(440, 520)
	popup:SetFrameStrata("HIGH")
	popup:SetClampedToScreen(true)
	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:Hide()
	if popup.SetTitle then
		pcall(popup.SetTitle, popup, "Cómo funciona")
	elseif popup.TitleText then
		popup.TitleText:SetText("Cómo funciona")
	end
	local portraitIcon = "Interface\\Icons\\INV_Misc_Spyglass_02"
	local portraitSet = false
	if popup.SetPortraitToAsset then
		portraitSet = pcall(popup.SetPortraitToAsset, popup, portraitIcon)
	end
	if not portraitSet then
		local portrait = popup.portrait or (popup.PortraitContainer and popup.PortraitContainer.portrait)
		if portrait and SetPortraitToTexture then
			SetPortraitToTexture(portrait, portraitIcon)
		end
	end
	local drag = CreateFrame("Frame", nil, popup)
	drag:SetPoint("TOPLEFT", 62, -1)
	drag:SetPoint("TOPRIGHT", -36, -1)
	drag:SetHeight(30)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function()
		popup:StartMoving()
	end)
	drag:SetScript("OnDragStop", function()
		popup:StopMovingOrSizing()
	end)
	if not popup.CloseButton then
		local closeButton = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
		closeButton:SetPoint("TOPRIGHT", -2, -2)
		closeButton:SetScript("OnClick", function()
			popup:Hide()
		end)
		popup.CloseButton = closeButton
	end
	ButtonTip(popup.CloseButton, "Cerrar", "Cierra esta ayuda.")
	tinsert(UISpecialFrames, "WhereIsHelpFrame")
	local scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 22, -68)
	scroll:SetPoint("BOTTOMRIGHT", -32, 18)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(360, 400)
	scroll:SetScrollChild(child)
	local body = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	body:SetPoint("TOPLEFT", 2, -2)
	body:SetWidth(350)
	body:SetJustifyH("LEFT")
	body:SetJustifyV("TOP")
	body:SetSpacing(3)
	body:SetText(HELP_TEXT)
	local textHeight = body:GetStringHeight()
	if not textHeight or textHeight < 40 then
		textHeight = 640
	end
	child:SetHeight(textHeight + 24)
	helpFrame = popup
	return popup
end

local function BuildFrame()
	if frame then
		return frame
	end
	local portraitOk, created = pcall(CreateFrame, "Frame", "WhereIsFrame", UIParent, "PortraitFrameTemplate")
	if portraitOk and created then
		frame = created
	else
		frame = CreateFrame("Frame", "WhereIsFrame", UIParent, "BackdropTemplate")
		if frame.SetBackdrop then
			frame:SetBackdrop({
				bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
				tile = true,
				tileSize = 256,
				edgeSize = 32,
				insets = { left = 8, right = 8, top = 8, bottom = 8 },
			})
		else
			MakeBackdrop(frame)
		end
	end
	frame:SetSize(480, 540)
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetToplevel(true)
	frame:Hide()
	if db and db.point then
		frame:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
	else
		frame:SetPoint("CENTER")
	end

	local titled = false
	if frame.SetTitle then
		titled = pcall(frame.SetTitle, frame, "WhereIs")
	end
	if not titled and frame.TitleText then
		frame.TitleText:SetText("WhereIs")
		titled = true
	end
	local portraitIcon = "Interface\\Icons\\INV_Misc_Spyglass_02"
	local portraitSet = false
	if frame.SetPortraitToAsset then
		portraitSet = pcall(frame.SetPortraitToAsset, frame, portraitIcon)
	end
	if not portraitSet then
		local portrait = frame.portrait or (frame.PortraitContainer and frame.PortraitContainer.portrait)
		if portrait and SetPortraitToTexture then
			SetPortraitToTexture(portrait, portraitIcon)
		end
	end

	local drag = CreateFrame("Frame", nil, frame)
	drag:SetPoint("TOPLEFT", 62, -1)
	drag:SetPoint("TOPRIGHT", -36, -1)
	drag:SetHeight(30)
	drag:EnableMouse(true)
	drag:RegisterForDrag("LeftButton")
	drag:SetScript("OnDragStart", function()
		frame:StartMoving()
	end)
	drag:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relative, x, y = frame:GetPoint(1)
		db.point = { point, relative, x, y }
	end)
	if not titled then
		local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", 0, -8)
		title:SetText("WhereIs")
	end
	if not frame.CloseButton then
		local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
		closeButton:SetPoint("TOPRIGHT", -2, -2)
		closeButton:SetScript("OnClick", function()
			frame:Hide()
		end)
		frame.CloseButton = closeButton
	end
	ButtonTip(frame.CloseButton, "Cerrar", "Cierra WhereIs. También vale Escape.")

	local helpButton = CreateFrame("Button", nil, frame)
	helpButton:SetSize(26, 26)
	helpButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -36)
	helpButton:SetFrameLevel(frame:GetFrameLevel() + 40)
	helpButton:SetNormalTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	helpButton:SetPushedTexture("Interface\\Icons\\INV_Misc_QuestionMark")
	helpButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	local helpPushed = helpButton:GetPushedTexture()
	if helpPushed then
		helpPushed:SetVertexColor(0.7, 0.7, 0.7)
	end
	ButtonTip(helpButton, "Ayuda", "Abre, al lado, cómo funciona el addon. Otro clic lo cierra.")
	helpButton:SetScript("OnClick", function()
		local popup = EnsureHelpFrame()
		if popup:IsShown() then
			popup:Hide()
		else
			popup:ClearAllPoints()
			popup:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
			popup:Show()
		end
	end)

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", 24, -68)
	hint:SetPoint("RIGHT", -24, 0)
	hint:SetJustifyH("LEFT")
	hint:SetText("Escribe el componente. Vendedores, bichos, plantas, menas y desencantar.")

	searchBox = CreateFrame("EditBox", "WhereIsSearch", frame, "InputBoxTemplate")
	searchBox:SetSize(310, 22)
	searchBox:SetPoint("TOPLEFT", 28, -96)
	searchBox:SetAutoFocus(false)
	searchBox:SetMaxLetters(80)
	searchBox:SetScript("OnEnterPressed", function(self)
		Search(self:GetText())
		self:ClearFocus()
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)

	local searchButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	searchButton:SetSize(100, 22)
	searchButton:SetPoint("LEFT", searchBox, "RIGHT", 8, 0)
	searchButton:SetText("Buscar")
	searchButton:SetScript("OnClick", function()
		Search(searchBox:GetText())
	end)
	ButtonTip(searchButton, "Buscar", "Busca el nombre escrito en la caja. También vale pulsar Intro.")

	local scroll = CreateFrame("ScrollFrame", "WhereIsScroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 20, -132)
	scroll:SetPoint("BOTTOMRIGHT", -32, 78)
	local insetOk, listInset = pcall(CreateFrame, "Frame", nil, frame, "InsetFrameTemplate")
	if insetOk and listInset then
		listInset:SetPoint("TOPLEFT", scroll, "TOPLEFT", -6, 4)
		listInset:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 26, -6)
		listInset:SetFrameLevel(math.max(frame:GetFrameLevel(), 1))
		scroll:SetFrameLevel(listInset:GetFrameLevel() + 2)
	end
	resultChild = CreateFrame("Frame", nil, scroll)
	resultChild:SetSize(410, 1)
	scroll:SetScrollChild(resultChild)

	statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("BOTTOMLEFT", 24, 48)
	statusText:SetPoint("RIGHT", -24, 0)
	statusText:SetJustifyH("LEFT")
	statusText:SetWordWrap(true)
	statusText:SetText("Mayús-clic en un objeto de la mochila, o escribe su nombre.")

	local clearButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	clearButton:SetSize(130, 22)
	clearButton:SetPoint("BOTTOMLEFT", 20, 16)
	clearButton:SetText("Quitar marcas")
	clearButton:SetScript("OnClick", ClearPins)
	ButtonTip(clearButton, "Quitar marcas", "Borra los puntos del mapa y la línea roja. El vendedor que sigues en el minimapa se queda.")

	marksButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	marksButton:SetSize(140, 22)
	marksButton:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
	marksButton:SetText("Ocultar marcas")
	marksButton:SetScript("OnClick", ToggleMarks)
	ButtonTip(marksButton, function()
		if marksVisible and pins[1] then
			return "Ocultar marcas"
		end
		return "Mostrar marcas"
	end, function()
		if marksVisible and pins[1] then
			return "Esconde los puntos del mapa sin borrarlos."
		end
		return "Vuelve a pintar los puntos de la última búsqueda."
	end)
	RefreshMarksButton()

	frame:SetScript("OnShow", function()
		searchBox:SetFocus()
		UpdateScaleBar()
	end)
	frame:SetScript("OnHide", function()
		UpdateScaleBar()
		if helpFrame then
			helpFrame:Hide()
		end
	end)
	tinsert(UISpecialFrames, "WhereIsFrame")
	return frame
end

function DC.Toggle()
	EnsureDB()
	local window = BuildFrame()
	if window:IsShown() then
		window:Hide()
	else
		window:Show()
	end
end

function DC.OpenSearch(text)
	EnsureDB()
	local window = BuildFrame()
	window:Show()
	if text and text ~= "" then
		searchBox:SetText(text)
		Search(text)
	end
end

local lastPickedLink
local lastPickedAt = 0

local function UseItemLink(text)
	if not frame or not frame:IsShown() or not searchBox then
		return
	end
	if type(text) ~= "string" or not text:find("item:", 1, true) then
		return
	end
	local now = GetTime()
	if text == lastPickedLink and (now - lastPickedAt) < 0.25 then
		return
	end
	lastPickedLink = text
	lastPickedAt = now
	searchBox:SetText(text)
	Search(text)
end

local function ShiftClicking()
	return IsModifiedClick and IsModifiedClick("CHATLINK")
end

if type(HandleModifiedItemClick) == "function" then
	hooksecurefunc("HandleModifiedItemClick", function(link)
		if ShiftClicking() then
			UseItemLink(link)
		end
	end)
end

if type(ChatEdit_InsertLink) == "function" then
	hooksecurefunc("ChatEdit_InsertLink", function(text)
		if ShiftClicking() or (searchBox and searchBox:HasFocus()) then
			UseItemLink(text)
		end
	end)
end

if type(ContainerFrameItemButton_OnModifiedClick) == "function" then
	hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(button)
		if not ShiftClicking() or not button then
			return
		end
		local bag = button.GetBagID and button:GetBagID()
		if not bag and button.GetParent then
			local parent = button:GetParent()
			bag = parent and parent.GetID and parent:GetID()
		end
		local slot = button.GetID and button:GetID()
		if not bag or not slot then
			return
		end
		local link
		if C_Container and C_Container.GetContainerItemLink then
			link = C_Container.GetContainerItemLink(bag, slot)
		elseif GetContainerItemLink then
			link = GetContainerItemLink(bag, slot)
		end
		UseItemLink(link)
	end)
end

SLASH_DONDECOMPRAR1 = "/whereis"
SLASH_DONDECOMPRAR2 = "/where"
SLASH_DONDECOMPRAR3 = "/donde"
SLASH_DONDECOMPRAR4 = "/compra"
SlashCmdList.DONDECOMPRAR = function(raw)
	EnsureDB()
	local text = strtrim(raw or "")
	local cmd = Norm(text)
	if cmd == "" then
		DC.Toggle()
		return
	end
	if cmd == "limpiar" or cmd == "clear" then
		ClearPins()
		Print("Marcas quitadas.")
		return
	end
	if cmd == "ayuda" or cmd == "help" then
		Print("Escribe /whereis y el nombre del objeto. Ejemplo: /whereis hilo burdo")
		Print("/whereis limpiar quita los puntos del mapa.")
		return
	end
	DC.OpenSearch(text)
end

function WhereIs_OnClick()
	DC.Toggle()
end

function DondeComprar_OnClick()
	DC.Toggle()
end

local function PlaceMinimapButton(button, angle)
	local radius = (Minimap:GetWidth() / 2)
	if not radius or radius < 20 then
		radius = 80
	end
	local rad = math.rad(angle)
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function EnsureMinimapButton()
	if _G.WhereIsMinimapButton or _G.DondeComprarMinimapButton or not Minimap then
		return
	end
	EnsureDB()
	local button = CreateFrame("Button", "WhereIsMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 12)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_02")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("CENTER", 1, 0)

	local angle = tonumber(db.minimapAngle) or 220
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
			if not mx or not my or not cx or not cy then
				return
			end
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
		if downX and cx and ((cx - downX) ^ 2 + (cy - downY) ^ 2) >= 64 then
			return
		end
		DC.Toggle()
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("WhereIs")
		GameTooltip:AddLine("Clic para abrir", 1, 1, 1)
		GameTooltip:AddLine("Arrastra por el borde para moverlo", 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("MERCHANT_SHOW")
events:RegisterEvent("MERCHANT_UPDATE")
events:RegisterEvent("MERCHANT_CLOSED")
events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
events:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= ADDON_NAME then
			return
		end
		EnsureDB()
		EnsureMinimapButton()
		if not db.seenTip then
			db.seenTip = true
			Print("Escribe /whereis y el componente. Si se compra, se farmea o se desencanta, te digo dónde.")
		end
		return
	end
	if event == "PLAYER_LOGIN" then
		EnsureDB()
		EnsureMinimapButton()
		ResolveZones()
		RequestNames()
		return
	end
	if event == "GET_ITEM_INFO_RECEIVED" then
		local id = tonumber(arg1)
		if id then
			ItemName(id)
			if id == viewItemID or id == gatherItemID then
				UpdatePins()
				RefreshNearby()
			end
		end
		return
	end
	if event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then
		if event == "MERCHANT_SHOW" then
			merchantGlowSuppressed = false
		end
		RememberMerchant()
		HighlightMerchantSearch()
		return
	end
	if event == "MERCHANT_CLOSED" then
		merchantGlowSuppressed = true
		HideMerchantGlows()
		ClearMarksAfterPurchase()
	end
end)

C_Timer.NewTicker(0.5, function()
	if pins[1] then
		UpdatePins()
	end
	UpdateScaleBar()
end)

local nearElapsed = 0
local nearDriver = CreateFrame("Frame")
nearDriver:SetScript("OnUpdate", function(_, elapsed)
	if not gatherItemID then
		return
	end
	nearElapsed = nearElapsed + elapsed
	if nearElapsed < 0.2 then
		return
	end
	nearElapsed = 0
	RefreshNearby()
end)
