--!strict
-- Sea chart generation. A voyage is three seas; each sea is a small branching map of islands.
-- Everything random comes from one Random.new(seed), so the same seed always gives the same chart.
--
-- Shape of a sea (7 rows, sailed left to right):
--   rows 1-5  two to four islands each, joined to the next row by lanes
--   row 6     one Port (every route passes through it)
--   row 7     the Boss
-- Rules (after Slay the Spire's map rules, see reports/One Piece campaign game design.md):
--   * row 1 is always Battle
--   * exactly one Treasure island sits mid-sea (row 3 or 4)
--   * no Elite or Rest in rows 1-2, and no Rest in row 5 (the Port is next)
--   * an Elite never leads straight to an Elite, nor a Rest to a Rest
--   * an island with two onward lanes leads to two different kinds
--   * lanes only join neighbouring rows and never cross
-- Chart.validate checks all of these; generate() falls back to a fixed layout if a roll ever fails them.

local Chart = {}

export type Node = {
	Id: number, -- index into Sea.Nodes
	Row: number,
	Col: number, -- 1 = top of the row
	Kind: string, -- Battle | Elite | Event | Rest | Treasure | Port | Boss
	Next: { number }, -- ids of the islands this one leads to, top to bottom
	X: number, -- position on the chart, 0-1 from the left
	Y: number, -- position on the chart, 0-1 from the top
}

export type Sea = {
	Index: number,
	Preset: string, -- value for Workspace's SeaPreset attribute
	Name: string,
	RowCount: number,
	Rows: { { number } }, -- node ids in each row
	Nodes: { Node },
	Start: { number }, -- the islands the ship can reach from the edge of the sea (row 1)
	BossId: number,
}

export type Map = { Seed: number, Seas: { Sea } }

type Weight = { Kind: string, Weight: number }

Chart.SeaCount = 3

local FREE_ROWS = 5
local PORT_ROW = 6
local BOSS_ROW = 7
local ROW_COUNT = 7
local TREASURE_ROWS = { 3, 4 }
local FIRST_ELITE_ROW = 3 -- no Elite or Rest before this row
local MAX_ATTEMPTS = 20

local SEA_NAMES = { "Calm Blues", "Golden Route", "Storm Sea" }

-- Smallest and largest number of islands in rows 1-5. A row may be at most twice as wide as the one before it,
-- because an island has at most two onward lanes.
local WIDTHS: { { { number } } } = {
	{ { 2, 3 }, { 3, 4 }, { 3, 4 }, { 3, 4 }, { 2, 3 } }, -- sea 1: an open, branching chart
	{ { 2, 2 }, { 2, 3 }, { 2, 3 }, { 2, 3 }, { 2, 2 } }, -- sea 2: narrower, fewer forks
	{ { 3, 3 }, { 3, 4 }, { 3, 4 }, { 3, 4 }, { 3, 3 } }, -- sea 3: wide all the way
}

-- Kinds that may not directly follow themselves along a route.
local NO_REPEAT: { [string]: boolean } = { Elite = true, Rest = true }

local function seaName(index: number): string
	local name = SEA_NAMES[index] or ("Sea " .. index)
	-- Use the preset's display name when Shared.World.SeaPresets is there, so the chart and the sky agree.
	local shared = (script.Parent :: Instance).Parent
	local world = if shared then shared:FindFirstChild("World") else nil
	local module = if world then world:FindFirstChild("SeaPresets") else nil
	if module and module:IsA("ModuleScript") then
		local ok, presets = pcall(require, module)
		if ok and type(presets) == "table" then
			local preset = (presets :: any)["Sea" .. index]
			if type(preset) == "table" and type(preset.DisplayName) == "string" then
				name = preset.DisplayName
			end
		end
	end
	return name
end

-- Lanes between a row of `a` islands and the next row of `b` islands, as { fromCol, toCol } pairs.
-- It walks from the top pair (1, 1) to the bottom pair (a, b), each step moving down one island on the left side,
-- the right side, or both. Lanes made this way reach every island and can never cross. An island gets at most two
-- onward lanes.
local function linkRows(rng: Random, a: number, b: number): { { number } }
	local edges: { { number } } = { { 1, 1 } }
	local i, j = 1, 1
	local forked = false -- island i already has two onward lanes
	local guard = 0
	while (i < a or j < b) and guard < 64 do
		guard += 1
		-- A step is allowed only if the islands still unreached on the right can be covered afterwards:
		-- every later island on the left can add two lanes, the current one can add one if it has not forked.
		local options: { string } = {}
		if i < a and j < b and (b - j - 1) <= 2 * (a - i - 1) + 1 then
			table.insert(options, "Both")
			table.insert(options, "Both")
		end
		if i < a and (b - j) <= 2 * (a - i - 1) + 1 then
			table.insert(options, "Merge")
		end
		if j < b and not forked and (b - j - 1) <= 2 * (a - i) then
			table.insert(options, "Fork")
		end

		local step = if #options > 0 then options[rng:NextInteger(1, #options)] elseif i < a then "Merge" else "Fork"
		if step == "Both" then
			i += 1
			j += 1
			forked = false
		elseif step == "Merge" then
			i += 1
			forked = false
		else
			j += 1
			forked = true
		end
		table.insert(edges, { i, j })
	end
	return edges
end

local function weightsFor(seaIndex: number, row: number): { Weight }
	if row < FIRST_ELITE_ROW then
		return { { Kind = "Battle", Weight = 5 }, { Kind = "Event", Weight = 5 } }
	end
	local elite = 1 + seaIndex -- later seas have more bounty targets
	if row >= FREE_ROWS then
		return { { Kind = "Battle", Weight = 4 }, { Kind = "Event", Weight = 3 }, { Kind = "Elite", Weight = elite + 1 } }
	end
	return {
		{ Kind = "Battle", Weight = 4 },
		{ Kind = "Event", Weight = 4 },
		{ Kind = "Elite", Weight = elite },
		{ Kind = "Rest", Weight = 2.5 },
	}
end

local function pickKind(rng: Random, weights: { Weight }, banned: { [string]: boolean }): string
	local total = 0
	for _, entry in weights do
		if not banned[entry.Kind] then
			total += entry.Weight
		end
	end
	if total <= 0 then
		return "Battle"
	end
	local roll = rng:NextNumber() * total
	local last = "Battle"
	for _, entry in weights do
		if not banned[entry.Kind] then
			last = entry.Kind
			roll -= entry.Weight
			if roll <= 0 then
				return entry.Kind
			end
		end
	end
	return last
end

-- parents[id] = ids of the islands that lead to island `id`.
local function parentsOf(nodes: { Node }): { { number } }
	local parents: { { number } } = {}
	for id = 1, #nodes do
		parents[id] = {}
	end
	for _, node in nodes do
		for _, nextId in node.Next do
			if parents[nextId] then
				table.insert(parents[nextId], node.Id)
			end
		end
	end
	return parents
end

local function newSea(index: number, widths: { number }): Sea
	local nodes: { Node } = {}
	local rows: { { number } } = {}
	for row = 1, ROW_COUNT do
		rows[row] = {}
		for col = 1, widths[row] do
			local id = #nodes + 1
			nodes[id] = { Id = id, Row = row, Col = col, Kind = "", Next = {}, X = 0, Y = 0 }
			rows[row][col] = id
		end
	end
	return {
		Index = index,
		Preset = "Sea" .. index,
		Name = seaName(index),
		RowCount = ROW_COUNT,
		Rows = rows,
		Nodes = nodes,
		Start = table.clone(rows[1]),
		BossId = rows[BOSS_ROW][1],
	}
end

-- Chart positions: rows run left to right, islands in a row are spread top to bottom, with a little wobble so
-- the chart looks hand-drawn. The wobble is far smaller than the gap between islands, so order never changes.
local function placeNodes(sea: Sea, rng: Random?)
	for _, node in sea.Nodes do
		local width = #sea.Rows[node.Row]
		local x = 0.1 + 0.82 * (node.Row - 1) / (ROW_COUNT - 1)
		local y = 0.1 + 0.8 * (node.Col - 0.5) / width
		if rng and node.Row < PORT_ROW then
			x += (rng:NextNumber() - 0.5) * 0.03
			y += (rng:NextNumber() - 0.5) * 0.05
		end
		node.X = x
		node.Y = y
	end
end

local function buildSea(rng: Random, index: number): Sea
	local plan = WIDTHS[index] or WIDTHS[1]
	local widths: { number } = {}
	for row = 1, FREE_ROWS do
		widths[row] = rng:NextInteger(plan[row][1], plan[row][2])
	end
	widths[PORT_ROW] = 1
	widths[BOSS_ROW] = 1

	local sea = newSea(index, widths)
	local nodes, rows = sea.Nodes, sea.Rows

	for row = 1, ROW_COUNT - 1 do
		for _, edge in linkRows(rng, widths[row], widths[row + 1]) do
			local from = nodes[rows[row][edge[1]]]
			local toId = rows[row + 1][edge[2]]
			if not table.find(from.Next, toId) then
				table.insert(from.Next, toId)
			end
		end
	end

	-- Fixed islands first.
	for _, id in rows[1] do
		nodes[id].Kind = "Battle"
	end
	nodes[rows[PORT_ROW][1]].Kind = "Port"
	nodes[rows[BOSS_ROW][1]].Kind = "Boss"
	local treasureRow = TREASURE_ROWS[rng:NextInteger(1, #TREASURE_ROWS)]
	local treasureWidth = widths[treasureRow]
	local treasureCol = math.ceil(treasureWidth / 2)
	if treasureWidth % 2 == 0 and rng:NextInteger(1, 2) == 2 then
		treasureCol += 1
	end
	nodes[rows[treasureRow][treasureCol]].Kind = "Treasure"

	-- Then the rest, row by row and top to bottom. An island may not copy a sibling (another island reached from
	-- the same fork), and may not repeat an Elite or Rest it is reached from.
	local parents = parentsOf(nodes)
	for row = 2, FREE_ROWS do
		for _, id in rows[row] do
			local node = nodes[id]
			if node.Kind == "" then
				local banned: { [string]: boolean } = {}
				for _, parentId in parents[id] do
					local parent = nodes[parentId]
					if NO_REPEAT[parent.Kind] then
						banned[parent.Kind] = true
					end
					for _, siblingId in parent.Next do
						local siblingKind = nodes[siblingId].Kind
						if siblingId ~= id and siblingKind ~= "" then
							banned[siblingKind] = true
						end
					end
				end
				node.Kind = pickKind(rng, weightsFor(index, row), banned)
			end
		end
	end

	placeNodes(sea, rng)
	return sea
end

-- A plain two-lane sea that satisfies every rule. Only used if random generation fails validation.
local FALLBACK_KINDS = {
	{ "Battle", "Battle" },
	{ "Event", "Battle" },
	{ "Battle", "Treasure" },
	{ "Rest", "Event" },
	{ "Battle", "Elite" },
}

local function fallbackSea(index: number): Sea
	local widths = { 2, 2, 2, 2, 2, 1, 1 }
	local sea = newSea(index, widths)
	local nodes, rows = sea.Nodes, sea.Rows
	for row = 1, FREE_ROWS do
		for col = 1, 2 do
			local node = nodes[rows[row][col]]
			node.Kind = FALLBACK_KINDS[row][col]
			local nextRow = rows[row + 1]
			table.insert(node.Next, nextRow[math.min(col, #nextRow)])
		end
	end
	local port = nodes[rows[PORT_ROW][1]]
	port.Kind = "Port"
	table.insert(port.Next, rows[BOSS_ROW][1])
	nodes[rows[BOSS_ROW][1]].Kind = "Boss"
	placeNodes(sea, nil)
	return sea
end

-- Checks a sea against every chart rule. Returns true, or false and the first rule it breaks.
function Chart.validate(sea: Sea): (boolean, string?)
	local nodes, rows = sea.Nodes, sea.Rows
	if #rows ~= sea.RowCount or sea.RowCount < 4 then
		return false, "wrong number of rows"
	end
	local portRow, bossRow = sea.RowCount - 1, sea.RowCount
	if #rows[portRow] ~= 1 or nodes[rows[portRow][1]].Kind ~= "Port" then
		return false, "the row before the boss must be a single Port"
	end
	if #rows[bossRow] ~= 1 or nodes[rows[bossRow][1]].Kind ~= "Boss" or sea.BossId ~= rows[bossRow][1] then
		return false, "the last row must be a single Boss"
	end

	local parents = parentsOf(nodes)
	local treasures = 0
	for id, node in nodes do
		if node.Id ~= id or rows[node.Row] == nil or rows[node.Row][node.Col] ~= id then
			return false, "island ids and rows do not match"
		end
		local kind = node.Kind
		if node.Row == 1 and kind ~= "Battle" then
			return false, "row 1 must be all Battle"
		end
		if node.Row > 1 and #parents[id] == 0 then
			return false, "an island cannot be reached"
		end
		if node.Row < bossRow and #node.Next == 0 then
			return false, "an island leads nowhere"
		end
		if node.Row == bossRow and #node.Next ~= 0 then
			return false, "the boss must be the end of the sea"
		end
		if (kind == "Port" and node.Row ~= portRow) or (kind == "Boss" and node.Row ~= bossRow) then
			return false, "Port or Boss out of place"
		end
		if kind == "Treasure" then
			treasures += 1
			if not table.find(TREASURE_ROWS, node.Row) then
				return false, "Treasure must sit mid-sea"
			end
		end
		if (kind == "Elite" or kind == "Rest") and node.Row < FIRST_ELITE_ROW then
			return false, "Elite or Rest too early"
		end
		if kind == "Rest" and node.Row == portRow - 1 then
			return false, "Rest directly before the Port"
		end
		if kind ~= "Battle" and kind ~= "Elite" and kind ~= "Event" and kind ~= "Rest" and kind ~= "Treasure" and kind ~= "Port" and kind ~= "Boss" then
			return false, "unknown island kind"
		end
		if #node.Next > 2 then
			return false, "more than two onward lanes"
		end
		for index, nextId in node.Next do
			local nextNode = nodes[nextId]
			if not nextNode or nextNode.Row ~= node.Row + 1 then
				return false, "a lane must lead to the next row"
			end
			if NO_REPEAT[kind] and nextNode.Kind == kind then
				return false, "Elite or Rest twice in a row"
			end
			for other = 1, index - 1 do
				local otherNode = nodes[node.Next[other]]
				if otherNode and otherNode.Kind == nextNode.Kind then
					return false, "a fork leads to two islands of the same kind"
				end
			end
		end
	end
	if treasures ~= 1 then
		return false, "there must be exactly one Treasure"
	end

	-- Lanes between two rows cross if one starts above another but ends below it.
	for row = 1, sea.RowCount - 1 do
		local lanes: { { number } } = {}
		for _, id in rows[row] do
			for _, nextId in nodes[id].Next do
				table.insert(lanes, { nodes[id].Col, nodes[nextId].Col })
			end
		end
		for _, a in lanes do
			for _, b in lanes do
				if a[1] < b[1] and a[2] > b[2] then
					return false, "lanes cross"
				end
			end
		end
	end

	if #sea.Start ~= #rows[1] then
		return false, "the start must reach all of row 1"
	end
	return true, nil
end

-- The chart for one voyage.
function Chart.generate(seed: number): Map
	local rng = Random.new(seed)
	local seas: { Sea } = {}
	for index = 1, Chart.SeaCount do
		local sea: Sea? = nil
		for _ = 1, MAX_ATTEMPTS do
			local candidate = buildSea(rng, index)
			if Chart.validate(candidate) then
				sea = candidate
				break
			end
		end
		seas[index] = sea or fallbackSea(index)
	end
	return { Seed = seed, Seas = seas }
end

-- The islands the ship can sail to next. `nodeId` 0 means the ship is at the edge of the sea.
function Chart.reachable(sea: Sea, nodeId: number): { number }
	if nodeId == 0 then
		return sea.Start
	end
	local node = sea.Nodes[nodeId]
	return if node then node.Next else {}
end

-- The row the ship is in; 0 at the edge of the sea.
function Chart.rowOf(sea: Sea, nodeId: number): number
	local node = sea.Nodes[nodeId]
	return if node then node.Row else 0
end

return Chart
