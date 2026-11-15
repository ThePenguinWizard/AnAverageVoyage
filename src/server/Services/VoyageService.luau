--!strict
-- VoyageService: the sea chart and the run loop (design/architecture.md, "The loop these make together").
--
-- A voyage belongs to a crew: a list of players sharing one chart. For now every player is their own crew of one,
-- but everything below works on the crew (votes, the ready bell, prompts), so bigger crews only need a way to
-- form them.
--
-- The loop: join -> ship (Location "Ship") -> chart (Location "Chart") -> pick an island and ring the ready bell
-- -> the island (Location "Battle" or "Event") -> back on the ship, until a boss is beaten (next sea), the third
-- boss is beaten (voyage complete) or a fight is lost (voyage over). Then a summary sheet, Renown, a fresh voyage.
--
-- Client messages on ReplicatedStorage.VoyageRemote (see VoyageController):
--   server -> client  "ChartOpen" view | "ChartUpdate" view | "ChartClose" | "Event" card | "EventResult" result
--                     | "Summary" data | "Notice" text
--   client -> server  "OpenChart" | "CloseChart" | "PickNode" id | "Ready" boolean | "EventChoice" index
--                     | "EventContinue" | "SummaryContinue"
-- The client only states what the player wants; everything is checked and decided here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VoyageShared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Voyage")
local Chart = require(VoyageShared:WaitForChild("Chart"))
local Config = require(VoyageShared:WaitForChild("VoyageConfig"))

local serverRoot = (script.Parent :: Instance).Parent :: Instance
local Private = serverRoot:WaitForChild("Voyage")
local Bridge = require(Private:WaitForChild("Bridge"))
local Events = require(Private:WaitForChild("Events"))
local Loot = require(Private:WaitForChild("Loot"))

-- A question the crew is being asked: an event choice (a vote when the crew is bigger than one) or a
-- "continue" button.
type Prompt = {
	Kind: string, -- "Choice" | "Continue"
	Tag: string, -- "Event" | "Summary": which sheet the answer must come from
	Count: number, -- number of options
	Answers: { [Player]: number },
	FirstAt: number?, -- when the first answer came in (starts the vote timer)
	Check: ((Player, number) -> boolean)?, -- extra validation of an answer
}

export type Voyage = {
	Id: number,
	Members: { Player },
	Alive: boolean, -- false once every member has left
	Map: Chart.Map,
	Sea: number, -- index into Map.Seas
	Node: number, -- id of the island the ship is at; 0 at the edge of the sea
	Path: { number }, -- islands visited in this sea, in order
	Phase: string, -- "Camp" | "Sailing" | "Island" | "Summary"
	Pick: number?, -- the island the crew has settled on
	Votes: { [Player]: number },
	VoteEndsAt: number?,
	VoteToken: number,
	Ready: { [Player]: boolean },
	ChartOpen: { [Player]: boolean },
	Prompt: Prompt?,
	InBattle: boolean,
	BattleResults: { [Player]: boolean },
	SeasCleared: number,
	IslandsInSea: number, -- islands cleared in the current sea
	IslandsCleared: number, -- islands cleared in the whole voyage
	UsedEvents: { [string]: boolean },
	Rng: Random,
}

local VoyageService = {}

local REMOTE_NAME = "VoyageRemote"
local MAX_MESSAGES_PER_SECOND = 20
local SAIL_SECONDS = 1 -- a short beat between leaving the ship and arriving
local STUB_BATTLE_SECONDS = 2 -- how long a fight "takes" while CombatService cannot run it
local EVENT_CHOICE_TIMEOUT = 180 -- seconds before an unanswered event takes its safe (last) choice
local CONTINUE_TIMEOUT = 90
local SUMMARY_TIMEOUT = 120
local DEFAULT_MAX_HP = 20
local SEA_GOLD_BONUS = 0.25 -- battle and treasure gold grows by this share per sea after the first

-- Gold for winning a fight { least, most } and the quality of the item that comes with it (0 = none).
local BATTLE_GOLD: { [string]: { number } } = { Battle = { 10, 18 }, Elite = { 28, 40 }, Boss = { 55, 75 } }
local BATTLE_ITEM: { [string]: number } = { Battle = 0, Elite = 2, Boss = 3 }

local remote: RemoteEvent? = nil
local started = false
local combatHooked = false
local nextCrewId = 0
local seedRng = Random.new()

local crewOf: { [Player]: Voyage } = {}
local messageWindow: { [Player]: { Start: number, Count: number } } = {}

-- ------------------------------------------------------------------ small helpers

local function sendTo(player: Player, ...: any)
	local event = remote
	if event and player.Parent ~= nil then
		event:FireClient(player, ...)
	end
end

local function notify(crew: Voyage, text: string)
	for _, member in crew.Members do
		sendTo(member, "Notice", text)
	end
end

local function setLocation(player: Player, location: string)
	if player.Parent ~= nil then
		player:SetAttribute("Location", location)
	end
end

-- A whole number between low and high from an untrusted value, or nil.
local function wholeNumber(value: any, low: number, high: number): number?
	if type(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < low or value > high then
		return nil
	end
	return value
end

local function allowMessage(player: Player): boolean
	local now = os.clock()
	local window = messageWindow[player]
	if not window or now - window.Start >= 1 then
		messageWindow[player] = { Start = now, Count = 1 }
		return true
	end
	window.Count += 1
	return window.Count <= MAX_MESSAGES_PER_SECOND
end

local function currentSea(crew: Voyage): Chart.Sea
	return crew.Map.Seas[crew.Sea]
end

local function newMap(): Chart.Map
	return Chart.generate(seedRng:NextInteger(1, 2147483646))
end

local function seaGold(crew: Voyage, range: { number }): number
	local amount = crew.Rng:NextInteger(range[1], range[2])
	return math.round(amount * (1 + SEA_GOLD_BONUS * (crew.Sea - 1)))
end

-- ------------------------------------------------------------------ rewards and effects (through other services)

-- Each of these applies one effect to every crew member and returns the line to show for it (or nil).

local function giveGold(crew: Voyage, amount: number): string?
	amount = math.round(amount)
	if amount == 0 then
		return nil
	end
	for _, member in crew.Members do
		Bridge.call("ProfileService", "addGold", member, amount)
	end
	return if amount > 0 then ("+%d gold"):format(amount) else ("-%d gold"):format(-amount)
end

local function giveItem(crew: Voyage, quality: number): string?
	local itemId, name = Loot.item(crew.Rng, quality)
	if not itemId then
		return nil
	end
	for _, member in crew.Members do
		Bridge.call("ProfileService", "giveItem", member, itemId, 1)
	end
	return "Found: " .. (name or itemId)
end

local function healShare(crew: Voyage, share: number): string?
	if share <= 0 then
		return nil
	end
	for _, member in crew.Members do
		local maxHp = member:GetAttribute("MaxHP")
		local amount = math.max(1, math.ceil((if type(maxHp) == "number" then maxHp else DEFAULT_MAX_HP) * share))
		Bridge.call("CombatService", "heal", member, amount)
	end
	return ("Wounds mended: %d%% of your health"):format(math.round(share * 100))
end

local function changeResolve(crew: Voyage, amount: number): string?
	amount = math.round(amount)
	if amount == 0 then
		return nil
	end
	for _, member in crew.Members do
		Bridge.call("CombatService", "addResolve", member, amount)
	end
	return if amount < 0 then ("Nerves steadied: Resolve -%d"):format(-amount) else ("Nerves frayed: Resolve +%d"):format(amount)
end

local function restoreCrew(crew: Voyage)
	for _, member in crew.Members do
		local ok = Bridge.call("CombatService", "restoreAll", member)
		if not ok then
			-- No restoreAll: get as close as the smaller calls allow.
			local maxHp = member:GetAttribute("MaxHP")
			Bridge.call("CombatService", "heal", member, if type(maxHp) == "number" then maxHp else DEFAULT_MAX_HP)
			Bridge.call("CombatService", "addResolve", member, -200)
		end
	end
end

local function addLine(lines: { string }, line: string?)
	if line then
		table.insert(lines, line)
	end
end

-- ------------------------------------------------------------------ the chart: view, picks and votes

-- What one player is told about the chart. Islands in the fog keep their place and lanes but not their kind.
local function buildView(crew: Voyage, player: Player): { [string]: any }
	local sea = currentSea(crew)
	local shipRow = Chart.rowOf(sea, crew.Node)
	local nodes = {}
	for id, node in sea.Nodes do
		local hidden = node.Kind ~= "Boss" and node.Row > shipRow + Config.FogRows
		nodes[id] = {
			Id = node.Id,
			Row = node.Row,
			Col = node.Col,
			X = node.X,
			Y = node.Y,
			Kind = if hidden then "Fog" else node.Kind,
			Next = node.Next,
		}
	end

	local reachable = Chart.reachable(sea, crew.Node)
	local voteCounts = {}
	for index, id in reachable do
		local count = 0
		for _, member in crew.Members do
			if crew.Votes[member] == id then
				count += 1
			end
		end
		voteCounts[index] = count
	end

	local readyCount = 0
	for _, member in crew.Members do
		if crew.Ready[member] then
			readyCount += 1
		end
	end

	local endsAt = crew.VoteEndsAt
	return {
		Sea = crew.Sea,
		SeaCount = #crew.Map.Seas,
		SeaName = sea.Name,
		RowCount = sea.RowCount,
		Node = crew.Node,
		Path = crew.Path,
		Nodes = nodes,
		Reachable = reachable,
		VoteCounts = voteCounts,
		Pick = crew.Pick or 0,
		MyVote = crew.Votes[player] or 0,
		VoteSecondsLeft = if endsAt then math.max(0, endsAt - os.clock()) else -1,
		Ready = crew.Ready[player] == true,
		ReadyCount = readyCount,
		CrewSize = #crew.Members,
		CanPick = crew.Phase == "Camp",
	}
end

local function broadcastChart(crew: Voyage)
	for _, member in crew.Members do
		if crew.ChartOpen[member] then
			sendTo(member, "ChartUpdate", buildView(crew, member))
		end
	end
end

local function closeChart(crew: Voyage, player: Player)
	if not crew.ChartOpen[player] then
		return
	end
	crew.ChartOpen[player] = nil
	if player:GetAttribute("Location") == "Chart" then
		setLocation(player, "Ship")
	end
	sendTo(player, "ChartClose")
end

-- Settles a crew vote: every vote is one ticket in the draw.
local function settleVote(crew: Voyage)
	local sea = currentSea(crew)
	local reachable = Chart.reachable(sea, crew.Node)
	local tickets: { number } = {}
	for _, member in crew.Members do
		local vote = crew.Votes[member]
		if vote and table.find(reachable, vote) then
			table.insert(tickets, vote)
		end
	end
	crew.VoteEndsAt = nil
	crew.VoteToken += 1
	if #tickets > 0 then
		crew.Pick = tickets[crew.Rng:NextInteger(1, #tickets)]
	end
end

local function everyoneVoted(crew: Voyage): boolean
	if #crew.Members == 0 then
		return false
	end
	for _, member in crew.Members do
		if not crew.Votes[member] then
			return false
		end
	end
	return true
end

-- ------------------------------------------------------------------ prompts (event choices and continue buttons)

-- Asks the crew something and waits for the answer. A solo player's answer is final. A bigger crew votes: the
-- timer starts with the first answer and the result is a draw weighted by votes. If nobody answers before
-- `timeout`, the last option is taken. Returns nil if the whole crew has left.
local function awaitPrompt(crew: Voyage, kind: string, tag: string, count: number, timeout: number, check: ((Player, number) -> boolean)?): number?
	local prompt: Prompt = { Kind = kind, Tag = tag, Count = count, Answers = {}, FirstAt = nil, Check = check }
	crew.Prompt = prompt
	local startedAt = os.clock()
	local result: number? = nil

	while crew.Alive do
		local tickets: { number } = {}
		for _, member in crew.Members do
			local answer = prompt.Answers[member]
			if answer then
				table.insert(tickets, answer)
			end
		end
		local now = os.clock()
		local firstAt = prompt.FirstAt
		local done = #tickets >= #crew.Members and #tickets > 0
		if not done and #tickets > 0 and firstAt and now - firstAt >= Config.VoteSeconds then
			done = true
		end
		if not done and now - startedAt >= timeout then
			done = true
		end
		if done then
			result = if #tickets > 0 then tickets[crew.Rng:NextInteger(1, #tickets)] else count
			break
		end
		task.wait(0.1)
	end

	if crew.Prompt == prompt then
		crew.Prompt = nil
	end
	return result
end

local function answerPrompt(crew: Voyage, player: Player, kind: string, tag: string, value: any)
	local prompt = crew.Prompt
	if not prompt or prompt.Kind ~= kind or prompt.Tag ~= tag then
		return
	end
	local answer = if kind == "Continue" then 1 else wholeNumber(value, 1, prompt.Count)
	if not answer then
		return
	end
	local check = prompt.Check
	if check and not check(player, answer) then
		return
	end
	prompt.Answers[player] = answer
	if not prompt.FirstAt then
		prompt.FirstAt = os.clock()
	end
end

-- ------------------------------------------------------------------ battles

-- Listens for the end of battles. CombatService may not be ready when the server starts, so this is tried again
-- before every fight until it works.
local function hookCombat(): boolean
	if combatHooked then
		return true
	end
	if not Bridge.has("CombatService", "onFinished") or not Bridge.has("CombatService", "startBattle") then
		return false
	end
	local ok = Bridge.call("CombatService", "onFinished", function(player: Player, result: any)
		local crew = crewOf[player]
		if crew and crew.InBattle then
			crew.BattleResults[player] = type(result) == "table" and result.Won == true
		end
	end)
	combatHooked = ok
	return combatHooked
end

-- Runs one fight for the whole crew and waits for it to end. Returns true if the crew won.
-- While CombatService cannot run battles, the fight counts as won after a short wait so the loop can be played.
local function runBattle(crew: Voyage, kind: string, enemies: { string }): boolean
	crew.BattleResults = {}
	crew.InBattle = true
	local hooked = hookCombat()

	local fighting: { Player } = {}
	for _, member in table.clone(crew.Members) do
		setLocation(member, "Battle")
		if hooked then
			local ok = Bridge.call("CombatService", "startBattle", member, { Kind = kind, Enemies = table.clone(enemies) })
			if ok then
				table.insert(fighting, member)
			end
		end
	end

	local won = false
	if #fighting == 0 then
		task.wait(STUB_BATTLE_SECONDS)
		won = true
	else
		local startedAt = os.clock()
		local canAsk = Bridge.has("CombatService", "isInBattle")
		while crew.Alive do
			local waiting = false
			for _, member in fighting do
				if table.find(crew.Members, member) and crew.BattleResults[member] == nil then
					-- Safety net: if CombatService says there is no battle and never reported a result, the
					-- fight did not start. Count it as won rather than leave the crew waiting for ever.
					if canAsk and os.clock() - startedAt > 3 then
						local ok, inBattle = Bridge.call("CombatService", "isInBattle", member)
						if ok and inBattle == false and crew.BattleResults[member] == nil then
							warn(("[VoyageService] no battle is running for %s; counting it as won"):format(member.Name))
							crew.BattleResults[member] = true
							continue
						end
					end
					waiting = true
					break
				end
			end
			if not waiting then
				break
			end
			task.wait(0.2)
		end
		-- The crew carries on if anyone is still standing.
		for _, member in fighting do
			if crew.BattleResults[member] == true then
				won = true
			end
		end
	end

	crew.InBattle = false
	return won and crew.Alive
end

local function payBattle(crew: Voyage, kind: string)
	local lines: { string } = {}
	local range = BATTLE_GOLD[kind] or BATTLE_GOLD.Battle
	addLine(lines, giveGold(crew, seaGold(crew, range)))
	local quality = BATTLE_ITEM[kind] or 0
	if quality > 0 then
		addLine(lines, giveItem(crew, quality))
	end
	if #lines > 0 then
		notify(crew, "Spoils: " .. table.concat(lines, ", "))
	end
end

-- A fight and its spoils. `wanted` is a line-up an event asked for. Returns true if the crew won.
local function fight(crew: Voyage, kind: string, wanted: { string }?): boolean
	local enemies = Loot.encounter(crew.Rng, kind, crew.Sea, wanted)
	local won = runBattle(crew, kind, enemies)
	if won then
		payBattle(crew, kind)
	end
	return won
end

-- ------------------------------------------------------------------ islands without a fight

-- Shows a result card to the crew and waits for them to close it.
local function showCard(crew: Voyage, card: { [string]: any })
	for _, member in crew.Members do
		setLocation(member, "Event")
		sendTo(member, "EventResult", card)
	end
	awaitPrompt(crew, "Continue", "Event", 1, CONTINUE_TIMEOUT, nil)
end

local function randomText(crew: Voyage, texts: { string }): string
	return texts[crew.Rng:NextInteger(1, #texts)]
end

local function runRest(crew: Voyage)
	local rest = Events.Rest
	local lines: { string } = {}
	addLine(lines, healShare(crew, rest.HealShare))
	addLine(lines, changeResolve(crew, rest.Resolve))
	showCard(crew, { Title = rest.Title, Tag = "Rest", Roll = "", Text = randomText(crew, rest.Texts), Effects = lines, Button = "Back to the ship" })
end

local function runTreasure(crew: Voyage)
	local treasure = Events.Treasure
	local lines: { string } = {}
	addLine(lines, giveGold(crew, seaGold(crew, treasure.Gold)))
	addLine(lines, giveItem(crew, treasure.Item))
	showCard(crew, { Title = treasure.Title, Tag = "Treasure", Roll = "", Text = randomText(crew, treasure.Texts), Effects = lines, Button = "Back to the ship" })
end

local function runPort(crew: Voyage)
	local port = Events.Port
	restoreCrew(crew)
	showCard(crew, {
		Title = port.Title,
		Tag = "Port",
		Roll = "",
		Text = randomText(crew, port.Texts),
		Effects = { "Fully rested: health restored, nerves steady" },
		Button = "Back to the ship",
	})
end

local function pickEvent(crew: Voyage): Events.Event
	local pool: { Events.Event } = {}
	for _, event in Events.List do
		if not crew.UsedEvents[event.Id] then
			table.insert(pool, event)
		end
	end
	if #pool == 0 then
		crew.UsedEvents = {}
		pool = table.clone(Events.List)
	end
	local event = pool[crew.Rng:NextInteger(1, #pool)]
	crew.UsedEvents[event.Id] = true
	return event
end

local function applyOutcome(crew: Voyage, outcome: Events.Outcome, lines: { string })
	local gold = outcome.Gold
	if gold then
		addLine(lines, giveGold(crew, crew.Rng:NextInteger(math.min(gold[1], gold[2]), math.max(gold[1], gold[2]))))
	end
	if outcome.Item then
		addLine(lines, giveItem(crew, outcome.Item))
	end
	if outcome.Heal then
		addLine(lines, healShare(crew, outcome.Heal))
	end
	if outcome.Resolve then
		addLine(lines, changeResolve(crew, outcome.Resolve))
	end
end

-- A narrated event: show the card, take the crew's choice, roll the odds, apply the outcome, and start the fight
-- if the outcome is one. Returns false only if that fight was lost.
local function runEvent(crew: Voyage): boolean
	local event = pickEvent(crew)
	local choices = {}
	for index, choice in event.Choices do
		choices[index] = {
			Label = choice.Label,
			Cost = choice.Cost or 0,
			Odds = if choice.Odds then math.round(choice.Odds * 100) else -1, -- percent; -1 = no gamble
		}
	end
	for _, member in crew.Members do
		setLocation(member, "Event")
		sendTo(member, "Event", { Title = event.Title, Tag = "Event", Text = event.Text, Choices = choices, CrewSize = #crew.Members })
	end

	local function canAfford(player: Player, index: number): boolean
		local choice = event.Choices[index]
		local cost = if choice then choice.Cost else nil
		if cost and cost > 0 then
			local gold = player:GetAttribute("Gold")
			if type(gold) == "number" and gold < cost then
				sendTo(player, "Notice", "You don't have the gold for that.")
				return false
			end
		end
		return true
	end

	local picked = awaitPrompt(crew, "Choice", "Event", #event.Choices, EVENT_CHOICE_TIMEOUT, canAfford)
	if not picked then
		return true
	end
	local choice = event.Choices[picked]
	local lines: { string } = {}
	if choice.Cost and choice.Cost > 0 then
		addLine(lines, giveGold(crew, -choice.Cost))
	end

	local roll = ""
	local outcome = choice.Success
	if choice.Odds then
		local success = crew.Rng:NextNumber() < choice.Odds
		roll = if success then "Success" else "Failure"
		if not success and choice.Fail then
			outcome = choice.Fail
		end
	end
	applyOutcome(crew, outcome, lines)

	local fightInfo = outcome.Fight
	showCard(crew, {
		Title = event.Title,
		Tag = "Event",
		Roll = roll,
		Text = outcome.Text,
		Effects = lines,
		Button = if fightInfo then "To arms" else "Back to the ship",
	})
	if not crew.Alive then
		return true
	end
	if fightInfo then
		return fight(crew, fightInfo.Kind, fightInfo.Enemies)
	end
	return true
end

-- ------------------------------------------------------------------ the run loop

local function clearCampState(crew: Voyage)
	crew.Pick = nil
	crew.Votes = {}
	crew.VoteEndsAt = nil
	crew.VoteToken += 1
	crew.Ready = {}
	crew.Prompt = nil
end

local function backToShip(crew: Voyage)
	clearCampState(crew)
	crew.Phase = "Camp"
	for _, member in crew.Members do
		crew.ChartOpen[member] = nil
		setLocation(member, "Ship")
		Bridge.call("ShipService", "placeOnShip", member)
	end
end

-- Starts a brand new voyage for the crew: new chart, starting gold and kit, full health, first sea.
local function startFreshVoyage(crew: Voyage)
	crew.Map = newMap()
	crew.Sea = 1
	crew.Node = 0
	crew.Path = {}
	crew.SeasCleared = 0
	crew.IslandsInSea = 0
	crew.IslandsCleared = 0
	crew.UsedEvents = {}
	crew.InBattle = false
	crew.BattleResults = {}
	Workspace:SetAttribute("SeaPreset", currentSea(crew).Preset)
	for _, member in crew.Members do
		Bridge.call("ProfileService", "resetVoyage", member)
		Bridge.call("CombatService", "restoreAll", member)
	end
	backToShip(crew)
end

-- The end of a voyage, won or lost: summary sheet, Renown, then a fresh voyage.
local function endVoyage(crew: Voyage, completed: boolean)
	crew.Phase = "Summary"
	local sea = currentSea(crew)
	local total, lines = Config.renown(crew.SeasCleared, if completed then 0 else crew.IslandsInSea, sea.RowCount)
	local summary = {
		Completed = completed,
		Sea = crew.Sea,
		SeaCount = #crew.Map.Seas,
		SeaName = sea.Name,
		SeasCleared = crew.SeasCleared,
		Islands = crew.IslandsCleared,
		Renown = total,
		Lines = lines,
	}
	for _, member in crew.Members do
		setLocation(member, "Event")
		if total > 0 then
			Bridge.call("ProfileService", "addRenown", member, total)
		end
		sendTo(member, "Summary", summary)
	end
	awaitPrompt(crew, "Continue", "Summary", 1, SUMMARY_TIMEOUT, nil)
	if not crew.Alive then
		return
	end
	startFreshVoyage(crew)
end

-- Sails to an island and plays it out.
local function runNode(crew: Voyage, nodeId: number)
	local sea = currentSea(crew)
	local node = sea.Nodes[nodeId]
	if not node then
		backToShip(crew)
		return
	end

	clearCampState(crew)
	crew.Node = nodeId
	table.insert(crew.Path, nodeId)
	local info = Config.Kinds[node.Kind]
	for _, member in table.clone(crew.Members) do
		closeChart(crew, member)
		sendTo(member, "Notice", "You set sail: " .. (if info then info.Label else node.Kind))
	end
	task.wait(SAIL_SECONDS)
	if not crew.Alive then
		return
	end

	crew.Phase = "Island"
	local kind = node.Kind
	local survived = true
	if kind == "Battle" or kind == "Elite" or kind == "Boss" then
		survived = fight(crew, kind, nil)
	elseif kind == "Event" then
		survived = runEvent(crew)
	elseif kind == "Rest" then
		runRest(crew)
	elseif kind == "Treasure" then
		runTreasure(crew)
	elseif kind == "Port" then
		runPort(crew)
	end
	if not crew.Alive then
		return
	end

	if not survived then
		endVoyage(crew, false)
		return
	end

	crew.IslandsInSea += 1
	crew.IslandsCleared += 1
	if kind == "Boss" then
		crew.SeasCleared += 1
		if crew.Sea >= #crew.Map.Seas then
			endVoyage(crew, true)
			return
		end
		crew.Sea += 1
		crew.Node = 0
		crew.Path = {}
		crew.IslandsInSea = 0
		local nextSea = currentSea(crew)
		Workspace:SetAttribute("SeaPreset", nextSea.Preset)
		notify(crew, ("The boss falls. You cross into sea %d: %s."):format(crew.Sea, nextSea.Name))
	end
	backToShip(crew)
end

-- Sails once the crew has settled on an island and everyone has rung the ready bell.
local function trySail(crew: Voyage)
	local pick = crew.Pick
	if crew.Phase ~= "Camp" or not pick or #crew.Members == 0 then
		return
	end
	for _, member in crew.Members do
		if not crew.Ready[member] then
			return
		end
	end
	crew.Phase = "Sailing"
	task.spawn(function()
		local ok, err = pcall(runNode, crew, pick)
		if not ok then
			warn(("[VoyageService] island %d failed: %s"):format(pick, tostring(err)))
			if crew.Alive then
				-- Don't leave the crew stranded: put them back on the ship to pick again.
				crew.InBattle = false
				local recovered, recoverErr = pcall(backToShip, crew)
				if not recovered then
					warn(("[VoyageService] could not return the crew to the ship: %s"):format(tostring(recoverErr)))
					crew.Phase = "Camp"
				end
			end
		end
	end)
end

local function onPick(crew: Voyage, player: Player, value: any)
	if crew.Phase ~= "Camp" then
		return
	end
	local sea = currentSea(crew)
	local nodeId = wholeNumber(value, 1, #sea.Nodes)
	if not nodeId or not table.find(Chart.reachable(sea, crew.Node), nodeId) then
		return
	end

	if #crew.Members <= 1 then
		crew.Pick = nodeId -- a solo captain just picks (and may change their mind until they sail)
	else
		if crew.Pick then
			return -- the vote is already settled
		end
		crew.Votes[player] = nodeId
		if not crew.VoteEndsAt then
			crew.VoteEndsAt = os.clock() + Config.VoteSeconds
			crew.VoteToken += 1
			local token = crew.VoteToken
			task.delay(Config.VoteSeconds, function()
				if crew.Alive and crew.VoteToken == token and crew.Phase == "Camp" and not crew.Pick then
					settleVote(crew)
					broadcastChart(crew)
					trySail(crew)
				end
			end)
		end
		if everyoneVoted(crew) then
			settleVote(crew)
		end
	end
	broadcastChart(crew)
	trySail(crew)
end

-- ------------------------------------------------------------------ crews and players

local function newCrew(members: { Player }): Voyage
	nextCrewId += 1
	local crew: Voyage = {
		Id = nextCrewId,
		Members = members,
		Alive = true,
		Map = newMap(),
		Sea = 1,
		Node = 0,
		Path = {},
		Phase = "Camp",
		Pick = nil,
		Votes = {},
		VoteEndsAt = nil,
		VoteToken = 0,
		Ready = {},
		ChartOpen = {},
		Prompt = nil,
		InBattle = false,
		BattleResults = {},
		SeasCleared = 0,
		IslandsInSea = 0,
		IslandsCleared = 0,
		UsedEvents = {},
		Rng = Random.new(seedRng:NextInteger(1, 2147483646)),
	}
	return crew
end

local function onPlayerAdded(player: Player)
	if crewOf[player] then
		return
	end
	local crew = newCrew({ player })
	crewOf[player] = crew
	setLocation(player, "Ship")
	Bridge.call("ShipService", "placeOnShip", player)
end

local function onPlayerRemoving(player: Player)
	messageWindow[player] = nil
	local crew = crewOf[player]
	crewOf[player] = nil
	if not crew then
		return
	end
	local index = table.find(crew.Members, player)
	if index then
		table.remove(crew.Members, index)
	end
	crew.Votes[player] = nil
	crew.Ready[player] = nil
	crew.ChartOpen[player] = nil
	crew.BattleResults[player] = nil
	local prompt = crew.Prompt
	if prompt then
		prompt.Answers[player] = nil
	end

	if #crew.Members == 0 then
		crew.Alive = false
		return
	end
	-- The rest of the crew may now be agreed.
	if crew.Phase == "Camp" then
		if not crew.Pick and everyoneVoted(crew) then
			settleVote(crew)
		end
		broadcastChart(crew)
		trySail(crew)
	end
end

local function onRemote(player: Player, action: any, value: any)
	if type(action) ~= "string" or not allowMessage(player) then
		return
	end
	local crew = crewOf[player]
	if not crew then
		return
	end
	if action == "OpenChart" then
		VoyageService.openChart(player)
	elseif action == "CloseChart" then
		closeChart(crew, player)
	elseif action == "PickNode" then
		onPick(crew, player, value)
	elseif action == "Ready" then
		if type(value) == "boolean" then
			VoyageService.setReady(player, value)
		end
	elseif action == "EventChoice" then
		answerPrompt(crew, player, "Choice", "Event", value)
	elseif action == "EventContinue" then
		answerPrompt(crew, player, "Continue", "Event", nil)
	elseif action == "SummaryContinue" then
		answerPrompt(crew, player, "Continue", "Summary", nil)
	end
end

-- ------------------------------------------------------------------ public API (design/architecture.md)

-- Shows the sea chart to this player (the chart table on the ship calls this).
function VoyageService.openChart(player: Player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local crew = crewOf[player]
	if not crew or crew.Phase ~= "Camp" then
		return
	end
	crew.ChartOpen[player] = true
	setLocation(player, "Chart")
	sendTo(player, "ChartOpen", buildView(crew, player))
end

-- The ready bell. When the whole crew is ready and an island has been chosen, the crew sails to it.
function VoyageService.setReady(player: Player, ready: boolean)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	local crew = crewOf[player]
	if not crew or crew.Phase ~= "Camp" then
		return
	end
	crew.Ready[player] = ready == true
	if ready == true and not crew.Pick then
		if #crew.Members <= 1 then
			sendTo(player, "Notice", "Ready to sail. Pick a heading on the sea chart.")
		else
			sendTo(player, "Notice", "Ready. The crew still has to agree on a heading at the sea chart.")
		end
	end
	broadcastChart(crew)
	trySail(crew)
end

-- The player's current run: Sea (index), Node (island id, 0 at the edge of the sea), Map (the chart), and more.
function VoyageService.getVoyage(player: Player): Voyage?
	return crewOf[player]
end

function VoyageService.init()
	local existing = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	local event: RemoteEvent
	if existing and existing:IsA("RemoteEvent") then
		event = existing
	else
		event = Instance.new("RemoteEvent")
		event.Name = REMOTE_NAME
		event.Parent = ReplicatedStorage
	end
	remote = event
	event.OnServerEvent:Connect(onRemote)
end

function VoyageService.start()
	if started then
		return
	end
	started = true
	hookCombat()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return VoyageService
