--!strict
-- Ship camp service (design decisions D10 and D11). The camp between islands is the crew's ship:
--   * placeOnShip / getShip put a player on the deck of the ship for their ShipTier and let them walk.
--   * Every station model on every ship (found by its `Station` attribute) gets a ProximityPrompt:
--       ChartTable            -> VoyageService.openChart(player)
--       ReadyBell             -> toggles ready, VoyageService.setReady(player, ready)
--       Stash, CrewChest      -> opens the inventory panel; "Use" takes the item and applies its Heal / Resolve
--       CookFire, Galley      -> one meal per visit to the ship (the galley is the better meal)
--       Infirmary             -> one rest per visit, relieves a lot of Resolve
--       everything else       -> a parchment note saying what the station will do later
-- Talks to the client over the "ShipRemote" RemoteEvent (see ShipController).
--
-- Other services (ProfileService, CombatService, VoyageService) are required lazily and every call is wrapped in
-- pcall, so the ship keeps working while they are missing or incomplete.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ShipFolder = script.Parent.Parent:WaitForChild("Ship")
local StationInfo = require(ShipFolder:WaitForChild("StationInfo"))
local DeckSpots = require(ShipFolder:WaitForChild("DeckSpots"))
local ItemLookup = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ship"):WaitForChild("ItemLookup"))

type Station = {
	Kind: string,
	Title: string,
	Model: Model,
	Ship: Model,
	Position: Vector3, -- where its prompt sits
	Range: number,
}

type Visit = { Ate: boolean, Rested: boolean }

type SpotResult = { Spots: { Vector3 }, Focus: Vector3, Reliable: boolean }

local ShipService = {}

local REMOTE_NAME = "ShipRemote"
local PROMPT_SLACK = 6 -- extra studs allowed on top of a prompt's range when the server re-checks distance
local REQUEST_COOLDOWN = 0.25 -- seconds between station uses / item uses per player
local MAX_ITEM_ID_LENGTH = 64
local WALK_SPEED = 16
local JUMP_HEIGHT = 7.2
local JUMP_POWER = 50
local OVERBOARD_Y = 1.5 -- a character this low is in the water (decks are well above it)

local remote: RemoteEvent? = nil
local started = false

local shipsByTier: { [number]: Model } = {}
local spotsByShip: { [Model]: SpotResult } = {}
local slotByPlayer: { [Player]: number } = {}
local slotShip: { [Player]: Model } = {}

local placed: { [Player]: boolean } = {} -- true once placeOnShip has run and the player has not sailed since
local visits: { [Player]: Visit } = {}
local ready: { [Player]: boolean } = {}
local openStation: { [Player]: Station } = {} -- the chest whose inventory panel the player last opened
local lastRequest: { [Player]: number } = {}
local overboardCount: { [Player]: number } = {}

local warned: { [string]: boolean } = {}

-- ------------------------------------------------------------------ small helpers

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn(message)
	end
end

local function send(player: Player, ...: any)
	if remote and player.Parent == Players then
		remote:FireClient(player, ...)
	end
end

local function round(value: number): number
	return math.floor(value + 0.5)
end

local function numberAttribute(player: Player, name: string): number?
	local value = player:GetAttribute(name)
	if type(value) == "number" and value == value then
		return value
	end
	return nil
end

local function locationOf(player: Player): string?
	local value = player:GetAttribute("Location")
	if type(value) == "string" then
		return value
	end
	return nil
end

-- Stations only work while the player is at camp. A missing Location (VoyageService not running) counts as camp.
local function canUseStations(player: Player): boolean
	local location = locationOf(player)
	return location == nil or location == "Ship"
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function humanoidOf(character: Model?): Humanoid?
	if character then
		return character:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

local function isNear(player: Player, station: Station, slack: number): boolean
	local root = rootOf(player.Character)
	if not root then
		return false
	end
	return (root.Position - station.Position).Magnitude <= station.Range + slack
end

-- True if the player may make another request now (and records the request).
local function takeRequestSlot(player: Player): boolean
	local now = os.clock()
	local last = lastRequest[player]
	if last and now - last < REQUEST_COOLDOWN then
		return false
	end
	lastRequest[player] = now
	return true
end

-- ------------------------------------------------------------------ other services (lazy, guarded)

local function getService(name: string): any
	local module = script.Parent:FindFirstChild(name)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		return result
	end
	if not ok then
		warnOnce("load:" .. name, ("[ShipService] could not load %s: %s"):format(name, tostring(result)))
	end
	return nil
end

-- Calls Service.functionName(...). Returns false if the service or function is missing or the call errored.
local function callService(serviceName: string, functionName: string, ...: any): (boolean, any)
	local service = getService(serviceName)
	local fn = service and service[functionName]
	if type(fn) ~= "function" then
		warnOnce(
			serviceName .. "." .. functionName,
			("[ShipService] %s.%s is not available yet"):format(serviceName, functionName)
		)
		return false, nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(("[ShipService] %s.%s failed: %s"):format(serviceName, functionName, tostring(result)))
	end
	return ok, result
end

-- Applies a heal and/or a Resolve change through CombatService. Returns whether anything was applied and a short
-- description of what changed, for example "+12 HP, Resolve -10".
local function applyEffects(player: Player, heal: number, resolve: number): (boolean, string)
	local combat = getService("CombatService")
	if not combat then
		return false, ""
	end
	if heal > 0 and type(combat.heal) ~= "function" then
		return false, ""
	end
	if resolve ~= 0 and type(combat.addResolve) ~= "function" then
		return false, ""
	end
	local applied = false
	local parts: { string } = {}
	if heal > 0 then
		local before = numberAttribute(player, "HP")
		local ok, err = pcall(combat.heal, player, heal)
		if ok then
			applied = true
			local after = numberAttribute(player, "HP")
			local gained = if before and after then math.max(0, after - before) else heal
			table.insert(parts, ("+%d HP"):format(round(gained)))
		else
			warn(("[ShipService] CombatService.heal failed: %s"):format(tostring(err)))
		end
	end
	if resolve ~= 0 then
		local before = numberAttribute(player, "Resolve")
		local ok, err = pcall(combat.addResolve, player, resolve)
		if ok then
			applied = true
			local after = numberAttribute(player, "Resolve")
			local change = if before and after then after - before else resolve
			if change <= 0 then
				table.insert(parts, ("Resolve -%d"):format(round(-change)))
			else
				table.insert(parts, ("Resolve +%d"):format(round(change)))
			end
		else
			warn(("[ShipService] CombatService.addResolve failed: %s"):format(tostring(err)))
		end
	end
	return applied, table.concat(parts, ", ")
end

local function combatReady(needHeal: boolean, needResolve: boolean): boolean
	local combat = getService("CombatService")
	if not combat then
		return false
	end
	if needHeal and type(combat.heal) ~= "function" then
		return false
	end
	if needResolve and type(combat.addResolve) ~= "function" then
		return false
	end
	return true
end

-- ------------------------------------------------------------------ ships and standing spots

local function findShip(tier: number): Model?
	local cached = shipsByTier[tier]
	if cached and cached:IsDescendantOf(Workspace) then
		return cached
	end
	local folder = Workspace:FindFirstChild("Ships")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("ShipTier") == tier then
			shipsByTier[tier] = child
			return child
		end
	end
	return nil
end

local function anyShip(): Model?
	local folder = Workspace:FindFirstChild("Ships")
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("Model") then
				return child
			end
		end
	end
	return nil
end

local function characterList(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(list, character)
		end
	end
	return list
end

local function spotsFor(ship: Model): SpotResult
	local cached = spotsByShip[ship]
	if cached then
		return cached
	end
	local ok, result = pcall(DeckSpots.find, ship, characterList())
	if ok and type(result) == "table" and #result.Spots > 0 then
		if result.Reliable then
			spotsByShip[ship] = result
		end
		return result
	end
	if not ok then
		warn(("[ShipService] could not work out deck spots for %s: %s"):format(ship.Name, tostring(result)))
	end
	local pivot = ship:GetPivot().Position
	local spot = Vector3.new(pivot.X, 6, pivot.Z)
	return { Spots = { spot }, Focus = spot + Vector3.new(0, 0, -10), Reliable = false }
end

-- Each player on a ship gets their own numbered slot, so several players don't land on the same spot.
local function slotFor(player: Player, ship: Model): number
	local current = slotByPlayer[player]
	if current and slotShip[player] == ship then
		return current
	end
	local used: { [number]: boolean } = {}
	for other, slot in slotByPlayer do
		if other ~= player and slotShip[other] == ship then
			used[slot] = true
		end
	end
	local slot = 1
	while used[slot] do
		slot += 1
	end
	slotByPlayer[player] = slot
	slotShip[player] = ship
	return slot
end

local function standHeight(humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 3 -- R6: legs (2) plus half the root part (1)
end

local function isCharacterReady(character: Model): boolean
	return character:IsDescendantOf(Workspace) and rootOf(character) ~= nil and humanoidOf(character) ~= nil
end

-- Moves the character to its deck spot and gives back normal movement. Returns false if it could not.
local function placeCharacter(player: Player, character: Model): boolean
	local root = rootOf(character)
	local humanoid = humanoidOf(character)
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local ship = ShipService.getShip(player)
	if not ship then
		warnOnce("noship", "[ShipService] no ship models found under Workspace.Ships")
		return false
	end

	local result = spotsFor(ship)
	local slot = slotFor(player, ship)
	local count = #result.Spots
	local spot = result.Spots[(slot - 1) % count + 1]
	local lap = (slot - 1) // count
	if lap > 0 then
		-- More players than spots: fan the extra ones out around the spot they share.
		local angle = slot * 2.4
		spot += Vector3.new(math.cos(angle), 0, math.sin(angle)) * 2.5
	end

	local position = spot + Vector3.new(0, standHeight(humanoid, root) + 0.25, 0)
	local focus = Vector3.new(result.Focus.X, position.Y, result.Focus.Z)
	local target = if (focus - position).Magnitude > 0.5 then CFrame.lookAt(position, focus) else CFrame.new(position)

	-- Combat may have frozen the character; undo that before moving it.
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
	end
	humanoid.Sit = false
	humanoid.PlatformStand = false
	root.CFrame = target
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	humanoid.WalkSpeed = WALK_SPEED
	humanoid.JumpHeight = JUMP_HEIGHT
	humanoid.JumpPower = JUMP_POWER
	humanoid.AutoRotate = true
	overboardCount[player] = nil
	return true
end

-- Should a (re)spawning character be put on the ship?
local function shouldBeOnShip(player: Player): boolean
	if placed[player] then
		return true
	end
	local location = locationOf(player)
	return location == "Ship" or location == "Chart"
end

-- Waits (in its own thread) for the character to finish spawning, then places it. Used when the character is not
-- ready yet and after a respawn, where the engine moves the character to a SpawnLocation first.
local function placeWhenReady(player: Player, character: Model)
	task.spawn(function()
		local deadline = os.clock() + 15
		repeat
			task.wait(0.1)
			if player.Character ~= character or player.Parent ~= Players then
				return
			end
		until isCharacterReady(character) or os.clock() > deadline
		if isCharacterReady(character) and shouldBeOnShip(player) then
			placeCharacter(player, character)
		end
	end)
end

-- ------------------------------------------------------------------ ready bell

-- The players who sail together with this one: the Members of their voyage if VoyageService can say, otherwise
-- everyone in the server.
local function crewOf(player: Player): { Player }
	local ok, voyage = callService("VoyageService", "getVoyage", player)
	if ok and type(voyage) == "table" and type(voyage.Members) == "table" and #voyage.Members > 0 then
		return voyage.Members
	end
	return Players:GetPlayers()
end

-- Tells every player their own ready state and how many of their crew are ready.
local function broadcastReady()
	for _, player in Players:GetPlayers() do
		local crew = crewOf(player)
		local count = 0
		for _, member in crew do
			if ready[member] then
				count += 1
			end
		end
		send(player, "Ready", ready[player] == true, count, #crew)
	end
end

local function note(player: Player, station: Station?, title: string, body: string)
	if station then
		send(player, "Note", title, body, station.Position, station.Range)
	else
		send(player, "Note", title, body)
	end
end

local function toggleReady(player: Player, station: Station)
	local want = not ready[player]
	ready[player] = want
	-- If this makes the whole crew ready, VoyageService may sail straight away; the Location listener below then
	-- clears the ready flags, so read the table again afterwards instead of trusting `want`.
	local ok = callService("VoyageService", "setReady", player, want)
	if not ok then
		ready[player] = false
		note(player, station, station.Title, "The bell rings out over the water, but there is no voyage to sail yet. Try again soon.")
	end
	broadcastReady()
end

-- ------------------------------------------------------------------ cooking and the infirmary

local function visitOf(player: Player): Visit
	local visit = visits[player]
	if not visit then
		visit = { Ate = false, Rested = false }
		visits[player] = visit
	end
	return visit
end

local function cookMeal(player: Player, station: Station)
	local meal = StationInfo.Meals[station.Kind]
	if not meal then
		return
	end
	local visit = visitOf(player)
	if visit.Ate then
		note(player, station, station.Title, "You have already eaten on this stop. There will be another meal after the next island.")
		return
	end
	if not combatReady(true, true) then
		note(player, station, station.Title, "The pot is empty for now. Come back once the ship is stocked.")
		return
	end
	local hp = numberAttribute(player, "HP")
	local maxHp = numberAttribute(player, "MaxHP")
	local resolve = numberAttribute(player, "Resolve")
	if hp and maxHp and hp >= maxHp and (resolve or 0) <= 0 then
		note(player, station, station.Title, "You are in fine shape: full health and steady nerves. Save the meal for when you need it.")
		return
	end
	local heal = math.max(1, round((maxHp or 100) * meal.HealShare))
	local applied, summary = applyEffects(player, heal, meal.Resolve)
	if not applied then
		note(player, station, station.Title, "The meal didn't sit right. Try again in a moment.")
		return
	end
	visit.Ate = true
	note(player, station, station.Title, ("%s\n%s."):format(meal.Text, summary))
end

local function restInInfirmary(player: Player, station: Station)
	local visit = visitOf(player)
	if visit.Rested then
		note(player, station, station.Title, "You have already rested here on this stop. The cots will be free again after the next island.")
		return
	end
	if not combatReady(false, true) then
		note(player, station, station.Title, "The infirmary isn't set up yet. Come back soon.")
		return
	end
	local resolve = numberAttribute(player, "Resolve")
	if resolve and resolve <= 0 then
		note(player, station, station.Title, "Your nerves are steady. Leave the cot for someone who needs it.")
		return
	end
	local applied, summary = applyEffects(player, 0, StationInfo.InfirmaryResolve)
	if not applied then
		note(player, station, station.Title, "You can't settle. Try again in a moment.")
		return
	end
	visit.Rested = true
	note(player, station, station.Title, ("You lie down a while and let the day go.\n%s."):format(summary))
end

-- ------------------------------------------------------------------ inventory

local function useItem(player: Player, requested: unknown)
	if type(requested) ~= "string" then
		return
	end
	local itemId: string = requested
	if #itemId == 0 or #itemId > MAX_ITEM_ID_LENGTH then
		return
	end
	if not takeRequestSlot(player) then
		return
	end
	local station = openStation[player]
	if not canUseStations(player) or not station or not isNear(player, station, PROMPT_SLACK + 2) then
		send(player, "ItemResult", false, "Step up to a chest on the ship first.")
		return
	end

	local name = ItemLookup.name(itemId)
	local heal, resolve = ItemLookup.effects(itemId)
	if heal <= 0 and resolve == 0 then
		send(player, "ItemResult", false, ("%s can't be used here."):format(name))
		return
	end

	local hp = numberAttribute(player, "HP")
	local maxHp = numberAttribute(player, "MaxHP")
	local currentResolve = numberAttribute(player, "Resolve")
	local healHelps = heal > 0 and not (hp ~= nil and maxHp ~= nil and hp >= maxHp)
	local resolveHelps = resolve < 0 and not (currentResolve ~= nil and currentResolve <= 0)
	if not healHelps and not resolveHelps then
		send(player, "ItemResult", false, "You don't need that right now.")
		return
	end
	if not combatReady(heal > 0, resolve ~= 0) then
		send(player, "ItemResult", false, "You can't use that right now.")
		return
	end

	local called, took = callService("ProfileService", "takeItem", player, itemId, 1)
	if not called then
		send(player, "ItemResult", false, "Your pack isn't ready yet.")
		return
	end
	if took ~= true then
		send(player, "ItemResult", false, ("You have no %s left."):format(name))
		return
	end

	local applied, summary = applyEffects(player, heal, resolve)
	if not applied then
		-- Nothing happened, so hand the item back.
		callService("ProfileService", "giveItem", player, itemId, 1)
		send(player, "ItemResult", false, "That didn't work. The item is back in your chest.")
		return
	end
	send(player, "ItemResult", true, ("Used %s: %s."):format(name, summary))
end

-- ------------------------------------------------------------------ stations

local function onStationUsed(player: Player, station: Station)
	if not canUseStations(player) or not isNear(player, station, PROMPT_SLACK) then
		return
	end
	if not takeRequestSlot(player) then
		return
	end
	local kind = station.Kind
	if kind == "ChartTable" then
		local ok = callService("VoyageService", "openChart", player)
		if not ok then
			note(player, station, station.Title, "The chart is still being drawn. Check back soon to pick the next island.")
		end
	elseif kind == "ReadyBell" then
		toggleReady(player, station)
	elseif kind == "Stash" or kind == "CrewChest" then
		openStation[player] = station
		send(player, "OpenInventory", station.Title, station.Position, station.Range)
	elseif kind == "CookFire" or kind == "Galley" then
		cookMeal(player, station)
	elseif kind == "Infirmary" then
		restInInfirmary(player, station)
	else
		local info = StationInfo.Stations[kind]
		local body = if info and info.Note then info.Note else "Nothing to do here yet."
		note(player, station, station.Title, body)
	end
end

-- World-axis bounds of every part in a model (station models have no PrimaryPart).
local function worldBounds(model: Model): (Vector3?, Vector3?)
	local low: Vector3? = nil
	local high: Vector3? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local cf = descendant.CFrame
			local half = descendant.Size / 2
			local right, up, look = cf.RightVector, cf.UpVector, cf.LookVector
			local extent = Vector3.new(
				math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(look.X) * half.Z,
				math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(look.Y) * half.Z,
				math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(look.Z) * half.Z
			)
			local partLow = cf.Position - extent
			local partHigh = cf.Position + extent
			low = if low then low:Min(partLow) else partLow
			high = if high then high:Max(partHigh) else partHigh
		end
	end
	return low, high
end

local function addPrompt(station: Station, action: string)
	-- Station models have no PrimaryPart, so the prompt hangs on a small invisible part inside the station.
	local anchor = Instance.new("Part")
	anchor.Name = "StationPrompt"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.CFrame = CFrame.new(station.Position)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	prompt.ObjectText = station.Title
	prompt.ActionText = action
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = station.Range
	prompt.RequiresLineOfSight = false -- the anchor sits inside the station's own parts
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = anchor

	prompt.Triggered:Connect(function(player: Player)
		onStationUsed(player, station)
	end)

	anchor.Parent = station.Model
end

local function setUpStation(ship: Model, model: Model)
	local kind = model:GetAttribute("Station")
	if type(kind) ~= "string" or model:FindFirstChild("StationPrompt") then
		return
	end
	local low, high = worldBounds(model)
	if not low or not high then
		return
	end
	local info = StationInfo.Stations[kind]
	local title = if info then info.Name else kind
	local action = if info then info.Action else "Look"
	local range = if info then info.Range else 8
	if kind == "CrewChest" then
		local slot = model:GetAttribute("Slot")
		if type(slot) == "number" then
			title = ("%s %d"):format(title, round(slot))
		end
	end

	-- The prompt sits over the middle of the station, about chest height above its base.
	local centre = (low + high) / 2
	local height = high.Y - low.Y
	local position = Vector3.new(centre.X, low.Y + math.min(height / 2, 3), centre.Z)
	addPrompt({ Kind = kind, Title = title, Model = model, Ship = ship, Position = position, Range = range }, action)

	if kind == "CrowsNest" then
		-- The nest model runs from the deck (the foot of its ladder) up to the platform: add a second prompt up top.
		local floorTop: number? = nil
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name == "Floor" then
				local y = descendant.Position.Y + descendant.Size.Y / 2
				if floorTop == nil or y > floorTop then
					floorTop = y
				end
			end
		end
		local topY = if floorTop then floorTop + 3 else high.Y - 1
		if topY - position.Y > range then
			local top = Vector3.new(centre.X, topY, centre.Z)
			addPrompt({ Kind = kind, Title = title, Model = model, Ship = ship, Position = top, Range = range }, action)
		end
	end
end

local function setUpShips()
	local folder = Workspace:WaitForChild("Ships", 30)
	if not folder then
		warn("[ShipService] Workspace.Ships was not found; no stations were set up")
		return
	end
	local total = 0
	for _, ship in folder:GetChildren() do
		if ship:IsA("Model") then
			-- Collect first: adding prompt parts while walking the descendants would change the list.
			local models: { Model } = {}
			for _, descendant in ship:GetDescendants() do
				if descendant:IsA("Model") and descendant:GetAttribute("Station") ~= nil then
					table.insert(models, descendant)
				end
			end
			for _, model in models do
				local ok, err = pcall(setUpStation, ship, model)
				if ok then
					total += 1
				else
					warn(("[ShipService] station %s on %s failed: %s"):format(model.Name, ship.Name, tostring(err)))
				end
			end
		end
	end
	print(("[ShipService] %d stations ready"):format(total))
end

-- Anyone who should be on deck but has ended up in the sea is put back, so jumping overboard is not a dead end.
local function rescueLoop()
	while true do
		task.wait(1)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = rootOf(character)
			if character and root and placed[player] and canUseStations(player) and root.Position.Y < OVERBOARD_Y then
				local count = (overboardCount[player] or 0) + 1
				overboardCount[player] = count
				if count >= 2 then
					placeCharacter(player, character)
				end
			else
				overboardCount[player] = nil
			end
		end
	end
end

-- ------------------------------------------------------------------ players

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		if shouldBeOnShip(player) then
			placeWhenReady(player, character)
		end
	end)
	player:GetAttributeChangedSignal("Location"):Connect(function()
		local location = locationOf(player)
		if location ~= nil and location ~= "Ship" then
			openStation[player] = nil
		end
		if location == "Battle" or location == "Event" then
			-- The crew has sailed: the camp visit is over.
			placed[player] = nil
			if ready[player] then
				ready[player] = false
				broadcastReady()
			end
		end
	end)
	broadcastReady()
end

local function onPlayerRemoving(player: Player)
	placed[player] = nil
	visits[player] = nil
	ready[player] = nil
	openStation[player] = nil
	lastRequest[player] = nil
	overboardCount[player] = nil
	slotByPlayer[player] = nil
	slotShip[player] = nil
	task.defer(broadcastReady)
end

-- ------------------------------------------------------------------ public API (design/architecture.md)

-- The ship model the player is using: the one for their ShipTier (a missing tier counts as 1).
function ShipService.getShip(player: Player): Model?
	local tier = 1
	if typeof(player) == "Instance" and player:IsA("Player") then
		local value = player:GetAttribute("ShipTier")
		if type(value) == "number" and value == value then
			tier = math.clamp(round(value), 1, 3)
		end
	end
	return findShip(tier) or findShip(1) or anyShip()
end

-- Moves the player's character onto the main deck of their ship and lets them walk. Starts a new camp visit (the
-- meal and the infirmary rest become available again). Does not yield; if the character is still spawning, it is
-- placed as soon as it is ready.
function ShipService.placeOnShip(player: Player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return
	end
	placed[player] = true
	visits[player] = { Ate = false, Rested = false }
	openStation[player] = nil
	ready[player] = false
	broadcastReady()

	local character = player.Character
	if not character then
		return -- CharacterAdded will place them
	end
	if not (isCharacterReady(character) and placeCharacter(player, character)) then
		placeWhenReady(player, character)
	end
end

function ShipService.init()
	local existing = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	if existing and existing:IsA("RemoteEvent") then
		remote = existing
	else
		local created = Instance.new("RemoteEvent")
		created.Name = REMOTE_NAME
		created.Parent = ReplicatedStorage
		remote = created
	end

	local event = remote :: RemoteEvent
	event.OnServerEvent:Connect(function(player: Player, action: unknown, argument: unknown)
		if action == "UseItem" then
			useItem(player, argument)
		elseif action == "ClosePanel" then
			openStation[player] = nil
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function ShipService.start()
	if started then
		return
	end
	started = true
	setUpShips()
	rescueLoop()
end

return ShipService
