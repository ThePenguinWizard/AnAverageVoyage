--!strict
-- CombatService: turn-based battles on Workspace.BattleIsland.BattleArena. The API is in design/architecture.md.
--
-- One battle per player. Each round the player picks a move (or braces) and plays its attack minigame; then every
-- enemy still standing attacks in turn and the player dodges on the parchment card. The enemy models, the minigames,
-- the dodge box and the close-ups all run on that player's client (Client.Controllers.CombatController), so two
-- players can fight different encounters on the same arena without seeing each other's enemies.
--
-- Player attributes this service owns: HP, MaxHP, Resolve, and Condition (the id of the current affliction or
-- virtue, a key of Moves.Conditions, or "" for none).
--
-- PROTOTYPE SHORTCUT (known): the server still trusts the client's minigame grade and its count of hits taken in the
-- dodge box. It checks their types, the phase they arrive in and how early they arrive, and clamps hits to what the
-- pattern allows, but a cheating client can still claim Perfect attacks and clean dodges. The real game must grade
-- inputs and replay dodges on the server (decisions D3 and D6) before combat results can be trusted.
--
-- CombatRemote, server to client: (event: string, state: table?, detail: table?)
--   state  = { hp, maxHp, resolve, condition, enemies = { hp... }, phase, round }
--   events = Begin, PlayerTurn, AttackResult, Braced, EnemyAttack, DodgeResult, CloseUp, End, Close
-- CombatRemote, client to server:
--   "Ready"                          the controller is listening
--   "Attack", moveId, target, grade  during PlayerTurn
--   "Brace"                          during PlayerTurn
--   "Dodged", hits                   after an EnemyAttack's dodge has played out

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Moves = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Combat"):WaitForChild("Moves"))

local CombatService = {}

local TURN_TIMEOUT = 90 -- seconds to pick a move and play its minigame before the character braces by itself
local DODGE_GRACE = 8 -- extra seconds to wait for a dodge report before counting every hit
local READY_TIMEOUT = 20 -- seconds to wait for the client's controller before starting anyway
local MAX_ENEMIES = 6
local DEV_ENCOUNTER = { Kind = "Battle", Enemies = { "Deckhand", "Swordsman", "Gunner" } }

type EnemyState = { id: string, name: string, hp: number, maxHp: number, cf: CFrame?, lastMove: string? }
type Input = { action: string, move: string?, target: number?, grade: string?, hits: number? }
type Session = {
	kind: string,
	enemies: { EnemyState },
	phase: string, -- "Intro", "Player", "Dodge", "Resolve" or "Over"
	phaseStart: number,
	minDelay: number, -- messages that arrive sooner than this after phaseStart are ignored
	maxHits: number, -- most hits the current enemy move can land
	round: number,
	braced: boolean,
	input: Input?,
	offered: { string }, -- move ids the player may use this battle
	closeUps: number, -- fail close-ups played this round
	lastTrigger: string,
	lastTriggerRound: number,
}
type Result = { Won: boolean, Kind: string }

local sessions: { [Player]: Session } = {}
local ready: { [Player]: boolean } = {}
local callbacks: { (player: Player, result: Result) -> () } = {}
local remote: RemoteEvent? = nil

local function fire(player: Player, event: string, state: any, detail: any)
	if remote and player.Parent ~= nil then
		remote:FireClient(player, event, state, detail)
	end
end

local arenaLoaded = false
local cameraCFrame: CFrame? = nil
-- Each side stands in two lines of three (decision D9): rank 1 is the front line, rank 2 the back line. Slot 1 is
-- nearest the camera; slots fill middle first so a lone fighter stands in the centre.
local RANKS = 2
local SLOT_ORDER = { 2, 1, 3 }
local crewSlots: { CFrame } = {}
local enemySlots: { [string]: CFrame } = {} -- "rank:slot" -> where that enemy stands

------------------------------------------------------------------------------------------------------------------
-- Player attributes
------------------------------------------------------------------------------------------------------------------

local function isPlayer(player: any): boolean
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent ~= nil
end

local function isNumber(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

local function ensureAttributes(player: Player)
	if type(player:GetAttribute("MaxHP")) ~= "number" then
		player:SetAttribute("MaxHP", Moves.PlayerMaxHP)
	end
	if type(player:GetAttribute("HP")) ~= "number" then
		player:SetAttribute("HP", player:GetAttribute("MaxHP"))
	end
	if type(player:GetAttribute("Resolve")) ~= "number" then
		player:SetAttribute("Resolve", 0)
	end
	if type(player:GetAttribute("Condition")) ~= "string" then
		player:SetAttribute("Condition", "")
	end
end

local function getNumber(player: Player, name: string, default: number): number
	local value = player:GetAttribute(name)
	if type(value) == "number" then
		return value
	end
	return default
end

local function getMaxHP(player: Player): number
	return math.max(1, getNumber(player, "MaxHP", Moves.PlayerMaxHP))
end

local function getHP(player: Player): number
	return getNumber(player, "HP", getMaxHP(player))
end

local function setHP(player: Player, value: number)
	player:SetAttribute("HP", math.clamp(math.floor(value + 0.5), 0, getMaxHP(player)))
end

-- The player's affliction or virtue (an entry of Moves.Conditions), or nil.
local function conditionOf(player: Player): any
	local id = player:GetAttribute("Condition")
	if type(id) == "string" and id ~= "" then
		return (Moves.Conditions :: any)[id]
	end
	return nil
end

local function canBrace(player: Player): boolean
	local condition = conditionOf(player)
	return not (condition and condition.NoBrace)
end

-- Adds to Resolve (negative relieves it) and returns the value before and after. A condition clears once Resolve
-- drops below the Clear line.
local function changeResolve(player: Player, amount: number): (number, number)
	local rules = Moves.Resolve
	local before = getNumber(player, "Resolve", 0)
	if amount < 0 then
		local condition = conditionOf(player)
		if condition and condition.ResolveRelief then
			amount *= condition.ResolveRelief
		end
	end
	local after = math.clamp(math.floor(before + amount + 0.5), 0, rules.Max)
	player:SetAttribute("Resolve", after)
	if after < rules.Clear and player:GetAttribute("Condition") ~= "" then
		player:SetAttribute("Condition", "")
	end
	return before, after
end

local function needsBreak(player: Player): boolean
	return getNumber(player, "Resolve", 0) >= Moves.Resolve.Break and conditionOf(player) == nil
end

-- The breaking point: rolls a Virtue or an Affliction, applies it, and returns the close-up to show.
local function rollBreak(player: Player): { [string]: any }
	local isVirtue = math.random() < Moves.Resolve.VirtueChance
	local pool = if isVirtue then Moves.Virtues else Moves.Afflictions
	local id = pool[math.random(1, #pool)]
	local condition = (Moves.Conditions :: any)[id]
	player:SetAttribute("Condition", id)
	return {
		kind = "Break",
		condition = id,
		virtue = isVirtue,
		stamp = string.upper(condition.Name),
		caption = condition.Line,
		summary = condition.Summary,
		duration = Moves.CloseUps.BreakDuration,
	}
end

------------------------------------------------------------------------------------------------------------------
-- Arena and character
------------------------------------------------------------------------------------------------------------------

local function loadArena()
	if arenaLoaded then
		return
	end
	local island = workspace:FindFirstChild("BattleIsland")
	local arena = island and island:FindFirstChild("BattleArena")
	if not arena then
		warn("[CombatService] Workspace.BattleIsland.BattleArena not found; battles will run without the arena")
		return
	end
	arenaLoaded = true
	local camPart = arena:FindFirstChild("BattleCamera", true)
	if camPart and camPart:IsA("BasePart") then
		cameraCFrame = camPart.CFrame
	end
	local crew: { [string]: CFrame } = {}
	for _, part in arena:GetDescendants() do
		if part:IsA("BasePart") then
			local side = part:GetAttribute("Side")
			local rank = part:GetAttribute("Rank")
			local slot = part:GetAttribute("Slot")
			if type(side) == "string" and type(rank) == "number" and type(slot) == "number" then
				local pos = part.Position + Vector3.new(0, 0.1, 0)
				if side == "Crew" then
					crew[rank .. ":" .. slot] = CFrame.lookAt(pos, pos + Vector3.new(1, 0, 0))
				elseif side == "Enemy" then
					enemySlots[rank .. ":" .. slot] = CFrame.lookAt(pos, pos + Vector3.new(-1, 0, 0))
				end
			end
		end
	end
	-- The crew fills the front line first, middle slot first, then the back line.
	for rank = 1, RANKS do
		for _, slot in SLOT_ORDER do
			local cf = crew[rank .. ":" .. slot]
			if cf then
				table.insert(crewSlots, cf)
			end
		end
	end
end

local function crewSlotFor(player: Player): CFrame?
	if #crewSlots == 0 then
		return nil
	end
	local index = 1
	for i, other in Players:GetPlayers() do
		if other == player then
			index = i
		end
	end
	return crewSlots[(index - 1) % #crewSlots + 1]
end

-- Stands the character on a crew slot and stops it walking for the length of the battle.
local function freezeCharacter(player: Player, s: Session, spawned: Model?)
	local character = spawned or player.Character
	if not character then
		return
	end
	character:WaitForChild("Humanoid", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or sessions[player] ~= s then
		return
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false
	local cf = crewSlotFor(player)
	if not cf then
		return
	end
	task.wait(0.2)
	if sessions[player] ~= s or character.Parent == nil then
		return
	end
	character:PivotTo(cf * CFrame.new(0, humanoid.HipHeight + 3, 0))
end

-- Undoes freezeCharacter's Humanoid changes. Where the character goes next is another service's job.
local function releaseCharacter(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
		humanoid.AutoRotate = true
	end
end

-- Turns a list of enemy ids into enemy states, each on its own slot (its preferred rank if there is room).
local function buildEnemies(ids: { any }): { EnemyState }
	local taken: { [string]: boolean } = {}
	local list: { EnemyState } = {}
	for _, id in ids do
		local info = if type(id) == "string" then (Moves.Enemies :: any)[id] else nil
		if not info then
			warn(("[CombatService] unknown enemy id %s; skipped"):format(tostring(id)))
			continue
		end
		if #list >= MAX_ENEMIES then
			warn("[CombatService] an encounter holds at most six enemies; the rest were skipped")
			break
		end
		local cf: CFrame? = nil
		for _, rank in { info.Rank, 1, 2 } do
			for _, slot in SLOT_ORDER do
				local key = rank .. ":" .. slot
				if enemySlots[key] and not taken[key] then
					taken[key] = true
					cf = enemySlots[key]
					break
				end
			end
			if cf then
				break
			end
		end
		table.insert(list, { id = id, name = info.Name, hp = info.MaxHP, maxHp = info.MaxHP, cf = cf, lastMove = nil })
	end
	return list
end

------------------------------------------------------------------------------------------------------------------
-- Battle flow
------------------------------------------------------------------------------------------------------------------

local function snapshot(player: Player, s: Session): { [string]: any }
	local hps = {}
	for i, enemy in s.enemies do
		hps[i] = enemy.hp
	end
	return {
		hp = getHP(player),
		maxHp = getMaxHP(player),
		resolve = getNumber(player, "Resolve", 0),
		condition = player:GetAttribute("Condition"),
		enemies = hps,
		phase = s.phase,
		round = s.round,
	}
end

local function send(player: Player, s: Session, event: string, detail: { [string]: any }?)
	fire(player, event, snapshot(player, s), detail)
end

local function alive(player: Player, s: Session): boolean
	return sessions[player] == s and player.Parent ~= nil
end

-- Opens a phase in which the client may answer, then waits for a valid answer. Returns nil on a timeout or if the
-- battle is gone.
local function awaitInput(player: Player, s: Session, timeout: number): Input?
	local deadline = os.clock() + timeout
	while alive(player, s) and s.input == nil and os.clock() < deadline do
		task.wait(0.05)
	end
	local input = s.input
	s.input = nil
	return input
end

local function firstStanding(s: Session): number?
	for i, enemy in s.enemies do
		if enemy.hp > 0 then
			return i
		end
	end
	return nil
end

local function pick(list: { string }): string
	return list[math.random(1, #list)]
end

-- D4's limits: at most two fail close-ups a round, and the same trigger (a failed attack, a bad dodge) never plays
-- in back-to-back rounds or twice in one round. Returns true, and counts it, if a close-up may play.
local function claimCloseUp(s: Session, trigger: string): boolean
	if s.closeUps >= Moves.CloseUps.MaxPerRound then
		return false
	end
	if s.lastTrigger == trigger and s.round - s.lastTriggerRound <= 1 then
		return false
	end
	s.closeUps += 1
	s.lastTrigger = trigger
	s.lastTriggerRound = s.round
	return true
end

-- Plays a fail close-up on the client and waits for it. Returns false if the battle is gone.
local function playFailCloseUp(player: Player, s: Session, trigger: string, text: any, before: number, after: number): boolean
	local duration = Moves.CloseUps.FailDuration
	send(player, s, "CloseUp", {
		kind = "Fail",
		trigger = trigger,
		stamp = pick(text.Stamps),
		caption = pick(text.Lines),
		duration = duration,
		resolveFrom = before,
		resolveTo = after,
	})
	task.wait(duration + 0.25)
	return alive(player, s)
end

-- Plays the breaking point if Resolve has reached it. Returns false if the battle is gone.
local function playBreakIfDue(player: Player, s: Session): boolean
	if needsBreak(player) then
		local detail = rollBreak(player)
		send(player, s, "CloseUp", detail)
		task.wait(detail.duration + 0.25)
	end
	return alive(player, s)
end

local function fireFinished(player: Player, result: Result)
	for _, callback in callbacks do
		task.spawn(function()
			local ok, err = pcall(callback, player, result)
			if not ok then
				warn(("[CombatService] an onFinished callback failed: %s"):format(tostring(err)))
			end
		end)
	end
end

local function devAutoSpar(): boolean
	return workspace:GetAttribute("DevAutoSpar") == true
end

-- Ends the battle: frees the character, tells the client to pack up, and reports the result.
local function closeBattle(player: Player, s: Session, won: boolean)
	if sessions[player] ~= s then
		return
	end
	sessions[player] = nil
	s.phase = "Over"
	if player.Parent == nil then
		return
	end
	releaseCharacter(player)
	fire(player, "Close", nil, nil)
	fireFinished(player, { Won = won, Kind = s.kind })
	if devAutoSpar() then
		-- Standalone testing: patch the player up after a loss and spar again.
		task.delay(2, function()
			if player.Parent ~= nil and sessions[player] == nil and devAutoSpar() then
				if not won then
					CombatService.restoreAll(player)
				end
				CombatService.startBattle(player, DEV_ENCOUNTER)
			end
		end)
	end
end

local function finish(player: Player, s: Session, won: boolean)
	s.phase = "Over"
	s.input = nil
	send(player, s, "End", { won = won, kind = s.kind })
	task.wait(2.2)
	closeBattle(player, s, won)
end

-- The player's attack. Returns false if the battle is gone.
local function resolveAttack(player: Player, s: Session, input: Input): boolean
	local move = (Moves.Player :: any)[input.move]
	local grade = input.grade or "Fail"
	local target = input.target
	if not target or not s.enemies[target] or s.enemies[target].hp <= 0 then
		target = firstStanding(s)
	end
	if not move or not target then
		return alive(player, s)
	end
	local enemy = s.enemies[target]
	local condition = conditionOf(player)
	local multiplier = ((Moves.GradeMultiplier :: any)[grade] or 0) * (if condition and condition.DamageDealt then condition.DamageDealt else 1)
	local damage = math.floor(move.Damage * multiplier + 0.5)
	enemy.hp = math.max(0, enemy.hp - damage)

	local failed = grade == "Fail"
	local before, after = 0, 0
	local closeUp = false
	if failed then
		before, after = changeResolve(player, Moves.Resolve.FailAttack)
		closeUp = claimCloseUp(s, "Attack")
	end
	send(player, s, "AttackResult", {
		move = input.move,
		target = target,
		damage = damage,
		grade = grade,
		down = enemy.hp == 0,
		closeUp = closeUp,
	})
	if closeUp then
		task.wait(0.9)
		if not alive(player, s) then
			return false
		end
		local text = (Moves.CloseUps.Attack :: any)[move.Weapon] or Moves.CloseUps.Attack.Sword
		return playFailCloseUp(player, s, "Attack", text, before, after)
	end
	task.wait(1.3)
	return alive(player, s)
end

-- One enemy's attack and the player's dodge. Returns false if the battle is over or gone.
local function resolveEnemyAttack(player: Player, s: Session, index: number): boolean
	local enemy = s.enemies[index]
	local info = (Moves.Enemies :: any)[enemy.id]
	local options: { string } = {}
	for _, id in info.Moves do
		if (Moves.Enemy :: any)[id] and (id ~= enemy.lastMove or #info.Moves == 1) then
			table.insert(options, id)
		end
	end
	if #options == 0 then
		return true
	end
	local moveId = pick(options)
	enemy.lastMove = moveId
	local move = (Moves.Enemy :: any)[moveId]
	local duration = Moves.patternDuration(move)

	s.maxHits = Moves.maxHits(move)
	s.input = nil
	s.phase = "Dodge"
	s.phaseStart = os.clock()
	s.minDelay = duration - 0.3
	send(player, s, "EnemyAttack", { enemy = index, move = moveId, seed = math.random(1, 1000000), braced = s.braced })
	local input = awaitInput(player, s, duration + DODGE_GRACE)
	if not alive(player, s) then
		return false
	end
	s.phase = "Resolve"

	-- No report in time: the soul stood still and took everything (D6).
	local hits = if input and input.hits then input.hits else s.maxHits
	local condition = conditionOf(player)
	local multiplier = (if s.braced then Moves.BraceMultiplier else 1) * (if condition and condition.DamageTaken then condition.DamageTaken else 1)
	local damage = 0
	if hits > 0 then
		damage = math.max(1, math.floor(hits * move.Damage * multiplier + 0.5))
	end
	local maxHp = getMaxHP(player)
	setHP(player, getHP(player) - damage)
	local knockedOut = getHP(player) <= 0
	local bad = damage >= maxHp * Moves.BadDodgeFraction

	local rules = Moves.Resolve
	local gain = rules.CleanDodge
	if hits > 0 then
		gain = math.min(hits * rules.PerHit, rules.PerAttackCap) + (if bad then rules.BadDodge else 0)
	end
	local before, after = changeResolve(player, gain)

	local closeUp = false
	if knockedOut then
		closeUp = true -- always shown: it is the end of the fight
	elseif bad then
		closeUp = claimCloseUp(s, "Dodge")
	end
	send(player, s, "DodgeResult", {
		enemy = index,
		hits = hits,
		damage = damage,
		braced = s.braced,
		knockedOut = knockedOut,
		closeUp = closeUp,
	})
	task.wait(1.1)
	if not alive(player, s) then
		return false
	end
	if closeUp then
		local text = if knockedOut then Moves.CloseUps.Down else Moves.CloseUps.Dodge
		if not playFailCloseUp(player, s, "Dodge", text, before, after) then
			return false
		end
	end
	if knockedOut then
		finish(player, s, false)
		return false
	end
	return true
end

local function runBattle(player: Player, s: Session)
	-- Wait for the client's controller, so the first messages are not missed.
	local waited = 0
	while alive(player, s) and not ready[player] and waited < READY_TIMEOUT do
		waited += task.wait(0.1)
	end
	if not alive(player, s) then
		return
	end

	local list = {}
	for i, enemy in s.enemies do
		list[i] = { id = enemy.id, name = enemy.name, hp = enemy.hp, maxHp = enemy.maxHp, cf = enemy.cf }
	end
	send(player, s, "Begin", { kind = s.kind, enemies = list, camera = cameraCFrame })
	task.wait(1.6)

	while alive(player, s) do
		s.round += 1
		s.closeUps = 0
		s.braced = false

		-- The player's turn.
		s.input = nil
		s.phase = "Player"
		s.phaseStart = os.clock()
		s.minDelay = 0.3
		send(player, s, "PlayerTurn", { moves = s.offered, canBrace = canBrace(player) })
		local input = awaitInput(player, s, TURN_TIMEOUT)
		if not alive(player, s) then
			return
		end
		s.phase = "Resolve"
		if input and input.action == "Attack" then
			if not resolveAttack(player, s, input) then
				return
			end
		else
			-- Brace, or no answer in time: an idle character braces by itself (D2) if it is able to.
			s.braced = canBrace(player)
			send(player, s, "Braced", { braced = s.braced, auto = input == nil })
			task.wait(1)
			if not alive(player, s) then
				return
			end
		end

		if firstStanding(s) == nil then
			if not playBreakIfDue(player, s) then
				return
			end
			finish(player, s, true)
			return
		end

		-- Every enemy still standing attacks in turn.
		for index, enemy in s.enemies do
			if enemy.hp > 0 then
				if not resolveEnemyAttack(player, s, index) then
					return
				end
			end
		end

		-- End of the round: breaking points play (D6).
		if not playBreakIfDue(player, s) then
			return
		end
	end
end

------------------------------------------------------------------------------------------------------------------
-- Remote
------------------------------------------------------------------------------------------------------------------

local function onRemote(player: Player, action: any, a1: any, a2: any, a3: any)
	if type(action) ~= "string" then
		return
	end
	if action == "Ready" then
		ready[player] = true
		return
	end
	local s = sessions[player]
	if not s or s.input ~= nil then
		return
	end
	-- Out-of-phase and too-early messages are ignored.
	if os.clock() - s.phaseStart < s.minDelay then
		return
	end
	if action == "Attack" then
		if s.phase ~= "Player" then
			return
		end
		if type(a1) ~= "string" or not table.find(s.offered, a1) then
			return
		end
		if type(a3) ~= "string" or (Moves.GradeMultiplier :: any)[a3] == nil then
			return
		end
		local target: number? = nil
		if isNumber(a2) and a2 == math.floor(a2) and a2 >= 1 and a2 <= #s.enemies then
			target = a2
		end
		s.input = { action = "Attack", move = a1, target = target, grade = a3 }
	elseif action == "Brace" then
		if s.phase ~= "Player" or not canBrace(player) then
			return
		end
		s.input = { action = "Brace" }
	elseif action == "Dodged" then
		if s.phase ~= "Dodge" or not isNumber(a1) then
			return
		end
		s.input = { action = "Dodged", hits = math.clamp(math.floor(a1), 0, s.maxHits) }
	end
end

local function onPlayerAdded(player: Player)
	ensureAttributes(player)
	player.CharacterAdded:Connect(function(character)
		local s = sessions[player]
		if s then
			freezeCharacter(player, s, character)
		end
	end)
	if devAutoSpar() then
		CombatService.startBattle(player, DEV_ENCOUNTER)
	end
end

------------------------------------------------------------------------------------------------------------------
-- API
------------------------------------------------------------------------------------------------------------------

-- Starts a battle for this player. It does not yield; the result arrives through onFinished.
function CombatService.startBattle(player: Player, encounter: { Kind: string, Enemies: { string } })
	if not isPlayer(player) or type(encounter) ~= "table" then
		warn("[CombatService] startBattle needs a player and an encounter table")
		return
	end
	if sessions[player] then
		warn(("[CombatService] %s is already in a battle; startBattle ignored"):format(player.Name))
		return
	end
	ensureAttributes(player)
	loadArena()

	local kind = encounter.Kind
	if kind ~= "Battle" and kind ~= "Elite" and kind ~= "Boss" then
		kind = "Battle"
	end
	local enemies = buildEnemies(if type(encounter.Enemies) == "table" then encounter.Enemies else {})
	if #enemies == 0 then
		warn("[CombatService] startBattle was given no valid enemies; the battle counts as won")
		task.defer(fireFinished, player, { Won = true, Kind = kind })
		return
	end
	if getHP(player) <= 0 then
		setHP(player, 1)
	end

	local s: Session = {
		kind = kind,
		enemies = enemies,
		phase = "Intro",
		phaseStart = os.clock(),
		minDelay = 0,
		maxHits = 0,
		round = 0,
		braced = false,
		input = nil,
		offered = Moves.movesFor(player:GetAttribute("Weapon")),
		closeUps = 0,
		lastTrigger = "",
		lastTriggerRound = -10,
	}
	sessions[player] = s

	task.spawn(freezeCharacter, player, s)
	task.spawn(function()
		local slot = crewSlotFor(player)
		if slot then
			-- Make sure the arena is streamed in around the player. Harmless if streaming is off.
			pcall(function()
				player:RequestStreamAroundAsync(slot.Position, 4)
			end)
		end
		local ok, err = pcall(runBattle, player, s)
		if not ok then
			warn(("[CombatService] the battle for %s stopped on an error: %s"):format(player.Name, tostring(err)))
			-- Do not leave the player stuck, and do not punish them for a bug.
			closeBattle(player, s, true)
		end
	end)
end

function CombatService.isInBattle(player: Player): boolean
	return sessions[player] ~= nil
end

-- The callback runs after every battle, won or lost: callback(player, { Won = boolean, Kind = string }).
function CombatService.onFinished(callback: (player: Player, result: Result) -> ())
	if type(callback) == "function" then
		table.insert(callbacks, callback)
	end
end

-- Heals the player, up to MaxHP. A negative amount hurts, but never below 1 HP.
function CombatService.heal(player: Player, amount: number)
	if not isPlayer(player) or not isNumber(amount) then
		return
	end
	ensureAttributes(player)
	local hp = getHP(player)
	if amount > 0 then
		local condition = conditionOf(player)
		if condition and condition.HealTaken then
			amount *= condition.HealTaken
		end
		setHP(player, hp + amount)
	elseif amount < 0 then
		setHP(player, math.max(math.min(hp, 1), hp + amount))
	end
end

-- Adds Resolve (stress); a negative amount relieves it. Clamps to 0..200.
function CombatService.addResolve(player: Player, amount: number)
	if not isPlayer(player) or not isNumber(amount) then
		return
	end
	ensureAttributes(player)
	changeResolve(player, amount)
	-- In a battle the breaking point plays at the end of the round. Outside one it plays straight away.
	if not sessions[player] and needsBreak(player) then
		fire(player, "CloseUp", nil, rollBreak(player))
	end
end

-- Full HP, Resolve 0, no affliction or virtue (the start of a voyage).
function CombatService.restoreAll(player: Player)
	if not isPlayer(player) then
		return
	end
	ensureAttributes(player)
	player:SetAttribute("HP", getMaxHP(player))
	player:SetAttribute("Resolve", 0)
	player:SetAttribute("Condition", "")
end

function CombatService.init()
	local event = Instance.new("RemoteEvent")
	event.Name = "CombatRemote"
	event.Parent = ReplicatedStorage
	event.OnServerEvent:Connect(onRemote)
	remote = event

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		ready[player] = nil
	end)
end

return CombatService
