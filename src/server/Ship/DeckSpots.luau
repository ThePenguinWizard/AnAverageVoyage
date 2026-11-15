--!strict
-- Works out safe places to stand on a ship's main deck from the ship's own geometry.
--
-- How a spot is chosen:
--   1. Start from the stash chest (every tier has one on the open main deck). If there is none, use the middle of
--      the ship's Decks model.
--   2. Try the points of a 3.5-stud grid around it, nearest first (out to 16 studs).
--   3. For each point, cast straight down against the Decks model only, to get the height of the main deck there.
--   4. Keep the point if a character-sized box above the deck touches nothing solid (chests, masts, stairs, hull,
--      cannons) and there is open sky above it (so nobody lands inside a cabin or under the quarterdeck).
-- If nothing passes, fall back to the ship's CrewSpawn, then the middle of the deck.

local Workspace = game:GetService("Workspace")

export type Result = {
	Spots: { Vector3 }, -- points on the deck surface, nearest to the focus first
	Focus: Vector3, -- what a placed character should face (the stash chest)
	Reliable: boolean, -- false if a fallback was used, so the caller can try again later
}

local DeckSpots = {}

local GRID_STEP = 3.5 -- studs between neighbouring spots
local GRID_REACH = 4 -- grid steps tried each way from the anchor
local MIN_DISTANCE = 4 -- keep clear of the stash chest itself
local MAX_DISTANCE = 16
local MAX_SPOTS = 12
local CHARACTER_BOX = Vector3.new(3.2, 5.4, 3.2)
local HEADROOM = 16 -- studs of open air needed above a spot
-- Deck planks have hairline gaps between them; probing three nearby points and taking the highest avoids the gaps.
local PROBES = { Vector3.new(0, 0, 0), Vector3.new(0.45, 0, 0.2), Vector3.new(-0.2, 0, 0.45) }

local function findStation(ship: Model, kind: string): Model?
	for _, descendant in ship:GetDescendants() do
		if descendant:IsA("Model") and descendant:GetAttribute("Station") == kind then
			return descendant
		end
	end
	return nil
end

local function deckHeight(decks: Instance, x: number, z: number, top: number, bottom: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { decks }
	local best: number? = nil
	for _, probe in PROBES do
		local origin = Vector3.new(x + probe.X, top, z + probe.Z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, bottom - top, 0), params)
		if hit and hit.Normal.Y > 0.9 then
			if best == nil or hit.Position.Y > best then
				best = hit.Position.Y
			end
		end
	end
	return best
end

local function isClear(spot: Vector3, ignore: { Instance }): boolean
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = ignore
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	local centre = CFrame.new(spot.X, spot.Y + 0.4 + CHARACTER_BOX.Y / 2, spot.Z)
	if #Workspace:GetPartBoundsInBox(centre, CHARACTER_BOX, overlap) > 0 then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	local roof = Workspace:Raycast(spot + Vector3.new(0, 1, 0), Vector3.new(0, HEADROOM, 0), params)
	return roof == nil
end

local function fallback(ship: Model, decks: Instance?, focus: Vector3?): Result
	local crewSpawn = ship:FindFirstChild("CrewSpawn")
	if crewSpawn and crewSpawn:IsA("BasePart") then
		local spot = crewSpawn.Position - Vector3.new(0, crewSpawn.Size.Y / 2, 0)
		return { Spots = { spot }, Focus = focus or (spot + Vector3.new(0, 0, -10)), Reliable = false }
	end
	if decks and decks:IsA("Model") then
		local cf, size = decks:GetBoundingBox()
		if size.Magnitude > 0 then
			local spot = cf.Position + Vector3.new(4, size.Y / 2, 4)
			return { Spots = { spot }, Focus = focus or (spot + Vector3.new(0, 0, -10)), Reliable = false }
		end
	end
	local pivot = ship:GetPivot().Position
	local spot = Vector3.new(pivot.X, 6, pivot.Z)
	return { Spots = { spot }, Focus = focus or (spot + Vector3.new(0, 0, -10)), Reliable = false }
end

-- `ignore` should list anything that must not count as an obstacle (player characters).
function DeckSpots.find(ship: Model, ignore: { Instance }): Result
	local decks = ship:FindFirstChild("Decks")
	if not decks or not decks:IsA("Model") then
		return fallback(ship, decks, nil)
	end
	local decksCf, decksSize = decks:GetBoundingBox()
	if decksSize.Magnitude <= 0 then
		return fallback(ship, decks, nil)
	end
	local top = decksCf.Position.Y + decksSize.Y / 2 + 20
	local bottom = decksCf.Position.Y - decksSize.Y / 2 - 20

	local anchor = decksCf.Position
	local stash = findStation(ship, "Stash")
	if stash then
		local stashCf, stashSize = stash:GetBoundingBox()
		if stashSize.Magnitude > 0 then
			anchor = stashCf.Position
		end
	end

	local exclude: { Instance } = { decks }
	for _, instance in ignore do
		table.insert(exclude, instance)
	end

	-- Grid points around the anchor, nearest first.
	local candidates: { { X: number, Z: number, Distance: number } } = {}
	for i = -GRID_REACH, GRID_REACH do
		for j = -GRID_REACH, GRID_REACH do
			local dx, dz = i * GRID_STEP, j * GRID_STEP
			local distance = math.sqrt(dx * dx + dz * dz)
			if distance >= MIN_DISTANCE and distance <= MAX_DISTANCE then
				table.insert(candidates, { X = anchor.X + dx, Z = anchor.Z + dz, Distance = distance })
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.Distance ~= b.Distance then
			return a.Distance < b.Distance
		end
		if a.Z ~= b.Z then
			return a.Z < b.Z
		end
		return a.X < b.X
	end)

	local spots: { Vector3 } = {}
	for _, candidate in candidates do
		local y = deckHeight(decks, candidate.X, candidate.Z, top, bottom)
		if y then
			local spot = Vector3.new(candidate.X, y, candidate.Z)
			if isClear(spot, exclude) then
				table.insert(spots, spot)
				if #spots >= MAX_SPOTS then
					break
				end
			end
		end
	end

	if #spots == 0 then
		return fallback(ship, decks, anchor)
	end
	return { Spots = spots, Focus = anchor, Reliable = true }
end

return DeckSpots
