--!strict
-- Picks enemy line-ups and loot from the shared data other features own. Both modules are read when needed and
-- with care, because they are being extended by other work and may not have the shape expected here:
--   Shared.Combat.Moves.Encounters = { Battle = { {ids}, ... }, Elite = { {ids}, ... }, Boss = { Sea1 = ..., ... } }
--   Shared.Data.Items (Items.Order, Items.get(id) -> { Name, Price, ... })

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loot = {}

-- Used when Moves.Encounters is missing or has nothing usable for the fight.
local FALLBACK_ENEMIES = { "Deckhand", "Swordsman", "Gunner" }

-- Item price bands for each loot quality: 1 common, 2 good, 3 fine.
local PRICE_BANDS = { { 0, 12 }, { 8, 40 }, { 18, math.huge } }

local function loadShared(folderName: string, moduleName: string): any?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local folder = if shared then shared:FindFirstChild(folderName) else nil
	local module = if folder then folder:FindFirstChild(moduleName) else nil
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			return result
		end
	end
	return nil
end

-- Turns whatever is stored for an encounter into a list of enemy ids. Accepts a list of ids, a list of such
-- lists (one is picked at random), or a table with an Enemies field.
-- Lists of encounters are ordered easiest to hardest, so the sea decides which part of the list is drawn from:
-- sea 1 the first third, sea 2 the middle, sea 3 the hardest (with some overlap).
local function enemyList(value: any, rng: Random, depth: number, seaIndex: number): { string }?
	if type(value) ~= "table" or depth > 3 then
		return nil
	end
	if type(value.Enemies) == "table" then
		value = value.Enemies
	end
	local count = #value
	if count == 0 then
		return nil
	end
	if type(value[1]) == "table" then
		local sea = math.clamp(seaIndex, 1, 3)
		local low = math.clamp(1 + math.floor((sea - 1) * count / 4), 1, count)
		local high = math.clamp(math.ceil(sea * count / 3), low, count)
		return enemyList(value[rng:NextInteger(low, high)], rng, depth + 1, seaIndex)
	end
	local list: { string } = {}
	for index = 1, count do
		local id = value[index]
		if type(id) == "string" then
			table.insert(list, id)
		end
	end
	return if #list > 0 then list else nil
end

local function enemyExists(moves: any, id: string): boolean
	local enemies = moves.Enemies
	if type(enemies) ~= "table" then
		return false
	end
	for key, def in enemies do
		if key == id or (type(def) == "table" and def.Id == id) then
			return true
		end
	end
	return false
end

-- Enemy ids for a fight. `wanted` is a line-up an event asked for; it is used only if every id still exists.
function Loot.encounter(rng: Random, kind: string, seaIndex: number, wanted: { string }?): { string }
	local moves = loadShared("Combat", "Moves")
	if moves and wanted and #wanted > 0 then
		local allKnown = true
		for _, id in wanted do
			if not enemyExists(moves, id) then
				allKnown = false
				break
			end
		end
		if allKnown then
			return table.clone(wanted)
		end
	end

	local encounters = if moves then moves.Encounters else nil
	if type(encounters) == "table" then
		local source = encounters[kind]
		if kind == "Boss" and type(source) == "table" and source["Sea" .. seaIndex] ~= nil then
			source = source["Sea" .. seaIndex]
		end
		local ok, list = pcall(enemyList, source, rng, 1, seaIndex)
		if ok and list then
			return list
		end
	end
	return table.clone(FALLBACK_ENEMIES)
end

-- A random item of the given loot quality. Returns its id and display name, or nil if there is no item data.
function Loot.item(rng: Random, quality: number): (string?, string?)
	local items = loadShared("Data", "Items")
	if not items then
		return nil, nil
	end

	local function definition(id: string): any?
		local ok, def = pcall(function()
			if type(items.get) == "function" then
				return items.get(id)
			end
			return items[id]
		end)
		return if ok and type(def) == "table" then def else nil
	end

	local ids: { string } = {}
	if type(items.Order) == "table" then
		for _, id in items.Order do
			if type(id) == "string" and definition(id) then
				table.insert(ids, id)
			end
		end
	else
		pcall(function()
			for id, def in items do
				if type(id) == "string" and type(def) == "table" and type(def.Name) == "string" then
					table.insert(ids, id)
				end
			end
		end)
		table.sort(ids)
	end
	if #ids == 0 then
		return nil, nil
	end

	local band = PRICE_BANDS[math.clamp(math.round(quality), 1, #PRICE_BANDS)]
	local pool: { string } = {}
	for _, id in ids do
		local def = definition(id)
		local price = if def and type(def.Price) == "number" then def.Price else 0
		if price >= band[1] and price <= band[2] then
			table.insert(pool, id)
		end
	end
	if #pool == 0 then
		pool = ids
	end

	local id = pool[rng:NextInteger(1, #pool)]
	local def = definition(id)
	local name = if def and type(def.Name) == "string" then def.Name else id
	return id, name
end

return Loot
