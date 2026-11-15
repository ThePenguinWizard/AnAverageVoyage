--!strict
-- Combat on the client: everything the player sees and does in a battle run by CombatService.
--   * builds this player's enemy models on the arena (other players never see them) and removes them afterwards
--   * holds the battle camera while the battle lasts, then lets go of it
--   * the parchment card: move menu, attack minigames (Combat/Minigames), dodge box (Combat/DodgeBox)
--   * HP and Resolve under the card, a narrator caption, grade and result banners
--   * fail and breaking-point close-ups (Combat/CloseUp)
--
-- The server sends (event, state, detail) over CombatRemote; see the header of CombatService for the list. Events
-- are handled one at a time, in order. "Close" is the exception: it cancels whatever is playing and packs up.
--
-- PROTOTYPE SHORTCUT (known): this client grades its own minigame and counts its own hits; the server only
-- sanity-checks them.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paper = require(Shared:WaitForChild("UI"):WaitForChild("Paper"))
local Moves = require(Shared:WaitForChild("Combat"):WaitForChild("Moves"))

local CombatFolder = script.Parent.Parent:WaitForChild("Combat")
local EnemyModels = require(CombatFolder:WaitForChild("EnemyModels"))
local Minigames = require(CombatFolder:WaitForChild("Minigames"))
local DodgeBox = require(CombatFolder:WaitForChild("DodgeBox"))
local CloseUp = require(CombatFolder:WaitForChild("CloseUp"))

local CombatController = {}

local CARD_WIDTH = 440
local BODY_WIDTH = CARD_WIDTH - 26 -- the sheet's double border takes 13 px on each side
local FIELD_SIZE = 280
local STATUS_HEIGHT = 58
local CAMERA_BINDING = "CombatCamera"
local ENEMY_FOLDER = "CombatEnemies"

type Token = { cancelled: boolean }
type EnemyView = { id: string, name: string, hp: number, maxHp: number, model: Model? }
type QueueItem = { event: string, state: any, detail: any }

local player = Players.LocalPlayer
local remote: RemoteEvent? = nil

local token: Token = { cancelled = false }
local queue: { QueueItem } = {}
local working = false

local inBattle = false
local enemies: { EnemyView } = {}
local selectedTarget: number? = nil
local cameraBound = false

-- UI, built once in start()
local gui: ScreenGui
local battleRoot: Frame
local dim: Frame
local stageScale: UIScale
local sheet: Frame
local body: Frame
local hpLabel: TextLabel
local hpBar: Frame
local resolveLabel: TextLabel
local resolveBar: Frame
local caption: TextLabel
local banner: TextLabel
local targetHighlight: Highlight? = nil

local cardVersion = 0
local bannerVersion = 0
local cardHeight = 10

------------------------------------------------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------------------------------------------------

local function send(...: any)
	if remote then
		remote:FireServer(...)
	end
end

-- Waits, giving up early if the battle was closed. Returns false if it was.
local function sleep(seconds: number, my: Token): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if my.cancelled then
			return false
		end
		task.wait(0.03)
	end
	return not my.cancelled
end

local function attributeNumber(name: string, fallback: number): number
	local value = player:GetAttribute(name)
	if type(value) == "number" then
		return value
	end
	return fallback
end

local function currentCondition(): any
	local id = player:GetAttribute("Condition")
	if type(id) == "string" and id ~= "" then
		return (Moves.Conditions :: any)[id]
	end
	return nil
end

local function usingGamepad(): boolean
	local last = UserInputService:GetLastInputType()
	return string.sub(last.Name, 1, 7) == "Gamepad"
end

------------------------------------------------------------------------------------------------------------------
-- Status strip, caption, banner
------------------------------------------------------------------------------------------------------------------

local function refreshStatus()
	if not hpLabel then
		return
	end
	local maxHp = math.max(1, math.floor(attributeNumber("MaxHP", Moves.PlayerMaxHP) + 0.5))
	local hp = math.floor(math.clamp(attributeNumber("HP", maxHp), 0, maxHp) + 0.5)
	hpLabel.Text = ("HP  %d / %d"):format(hp, maxHp)
	hpBar.Size = UDim2.fromScale(hp / maxHp, 1)

	local resolve = math.floor(math.clamp(attributeNumber("Resolve", 0), 0, Moves.Resolve.Max) + 0.5)
	local condition = currentCondition()
	if condition then
		resolveLabel.Text = ("Resolve  %d   ·   %s"):format(resolve, tostring(condition.Name))
		resolveLabel.TextColor3 = if condition.Kind == "Virtue" then Paper.Colors.Gold else Paper.Colors.Red
	else
		resolveLabel.Text = ("Resolve  %d"):format(resolve)
		resolveLabel.TextColor3 = Paper.Colors.Ink
	end
	resolveBar.Size = UDim2.fromScale(resolve / Moves.Resolve.Max, 1)
	resolveBar.BackgroundColor3 = if resolve >= Moves.Resolve.Break then Paper.Colors.Red else Paper.Colors.Gold
end

local function setCaption(text: string)
	caption.Text = text
end

local function showBanner(text: string, color: Color3, seconds: number)
	bannerVersion += 1
	local version = bannerVersion
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	task.delay(seconds, function()
		if bannerVersion == version then
			banner.Visible = false
		end
	end)
end

------------------------------------------------------------------------------------------------------------------
-- The card
------------------------------------------------------------------------------------------------------------------

local function updateScale()
	local camera = workspace.CurrentCamera
	if not camera or not stageScale then
		return
	end
	local view = camera.ViewportSize
	local needWidth = CARD_WIDTH + 24
	local needHeight = cardHeight + STATUS_HEIGHT + 8 + 130
	stageScale.Scale = math.clamp(math.min(1, view.X / needWidth, view.Y / needHeight), 0.35, 1)
end

-- Unfolds the card to `height` pixels. The caller fills `body` (before or after).
local function showCard(height: number)
	cardVersion += 1
	cardHeight = height
	body.Size = UDim2.fromOffset(BODY_WIDTH, height - 26)
	sheet.Visible = true
	updateScale()
	TweenService:Create(sheet, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(CARD_WIDTH, height) }):Play()
end

local function hideCard()
	cardVersion += 1
	local version = cardVersion
	TweenService:Create(sheet, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(CARD_WIDTH, 10) }):Play()
	task.delay(0.2, function()
		if cardVersion == version then
			sheet.Visible = false
			body:ClearAllChildren()
		end
	end)
end

local function setDim(on: boolean)
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = if on then 0.5 else 1 }):Play()
end

------------------------------------------------------------------------------------------------------------------
-- Enemies, camera
------------------------------------------------------------------------------------------------------------------

local function clearTargetHighlight()
	if targetHighlight then
		targetHighlight:Destroy()
		targetHighlight = nil
	end
end

local function highlightTarget(index: number?)
	clearTargetHighlight()
	local enemy = if index then enemies[index] else nil
	if enemy and enemy.model and enemy.model.Parent then
		local highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineColor = Paper.Colors.Gold
		highlight.OutlineTransparency = 0
		highlight.Parent = enemy.model
		targetHighlight = highlight
	end
end

local function removeEnemies()
	clearTargetHighlight()
	local folder = workspace:FindFirstChild(ENEMY_FOLDER)
	if folder then
		folder:Destroy()
	end
	enemies = {}
	selectedTarget = nil
end

local function firstStanding(): number?
	for i, enemy in enemies do
		if enemy.hp > 0 then
			return i
		end
	end
	return nil
end

-- Copies the server's numbers onto the enemy views and the status strip.
local function applyState(state: any)
	if type(state) == "table" and type(state.enemies) == "table" then
		for i, hp in state.enemies do
			local enemy = enemies[i]
			if enemy and type(hp) == "number" then
				enemy.hp = hp
				if enemy.model then
					EnemyModels.setHealth(enemy.model, hp, enemy.maxHp)
					if hp <= 0 then
						EnemyModels.topple(enemy.model)
					end
				end
			end
		end
	end
	refreshStatus()
end

local function holdCamera(cf: CFrame)
	if cameraBound then
		RunService:UnbindFromRenderStep(CAMERA_BINDING)
	end
	cameraBound = true
	-- Narrow the view and tip it up so the fighters sit in the lower part of the screen, clear of the card.
	local view = cf * CFrame.Angles(math.rad(13), 0, 0)
	RunService:BindToRenderStep(CAMERA_BINDING, Enum.RenderPriority.Camera.Value + 1, function()
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = view
			camera.FieldOfView = 45
		end
	end)
end

-- Lets go of the camera. Where it looks next is up to whoever moves the player (the ship or chart controller).
local function releaseCamera()
	if not cameraBound then
		return
	end
	cameraBound = false
	RunService:UnbindFromRenderStep(CAMERA_BINDING)
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
end

-- Packs everything up at the end of a battle.
local function closeBattle()
	inBattle = false
	releaseCamera()
	removeEnemies()
	cardVersion += 1
	bannerVersion += 1
	if battleRoot then
		battleRoot.Visible = false
		sheet.Visible = false
		sheet.Size = UDim2.fromOffset(CARD_WIDTH, 10)
		body:ClearAllChildren()
		banner.Visible = false
		dim.BackgroundTransparency = 1
		setCaption("")
	end
end

------------------------------------------------------------------------------------------------------------------
-- Event handlers. Each runs to the end before the next event is handled.
------------------------------------------------------------------------------------------------------------------

local INTRO_LINES = {
	Battle = "Hostile colours. Steel is drawn.",
	Elite = "This one has killed better crews than yours.",
	Boss = "The sea goes quiet. Something has decided to deal with you itself.",
}

local function onBegin(state: any, detail: any)
	removeEnemies()
	inBattle = true
	battleRoot.Visible = true
	sheet.Visible = false
	sheet.Size = UDim2.fromOffset(CARD_WIDTH, 10)
	dim.BackgroundTransparency = 1
	banner.Visible = false

	local folder = Instance.new("Folder")
	folder.Name = ENEMY_FOLDER
	folder.Parent = workspace
	if type(detail.enemies) == "table" then
		for i, entry in detail.enemies do
			if type(entry) ~= "table" or type(entry.id) ~= "string" then
				continue
			end
			local info = (Moves.Enemies :: any)[entry.id]
			local view: EnemyView = {
				id = entry.id,
				name = if type(entry.name) == "string" then entry.name else entry.id,
				hp = if type(entry.hp) == "number" then entry.hp else 1,
				maxHp = if type(entry.maxHp) == "number" then entry.maxHp else 1,
				model = nil,
			}
			if info and typeof(entry.cf) == "CFrame" then
				local ok, result = pcall(EnemyModels.build, entry.id, info, entry.cf, folder)
				if ok then
					view.model = result
					EnemyModels.setHealth(result, view.hp, view.maxHp)
				else
					warn(("[Combat] could not build %s: %s"):format(entry.id, tostring(result)))
				end
			end
			enemies[i] = view
		end
	end
	if typeof(detail.camera) == "CFrame" then
		holdCamera(detail.camera)
	end
	applyState(state)
	setCaption(INTRO_LINES[detail.kind] or INTRO_LINES.Battle)
end

local function onPlayerTurn(state: any, detail: any, my: Token)
	applyState(state)
	local moveIds: { string } = {}
	if type(detail.moves) == "table" then
		for _, id in detail.moves do
			if type(id) == "string" and (Moves.Player :: any)[id] then
				table.insert(moveIds, id)
			end
		end
	end
	local standing: { number } = {}
	for i, enemy in enemies do
		if enemy.hp > 0 then
			table.insert(standing, i)
		end
	end
	if not selectedTarget or not enemies[selectedTarget] or enemies[selectedTarget].hp <= 0 then
		selectedTarget = firstStanding()
	end

	local rows = math.max(#standing, #moveIds + 1)
	local height = 26 + 48 + rows * 50 + 6
	body:ClearAllChildren()
	Paper.label(body, "Your move", 22, { Position = UDim2.fromOffset(8, 4), Size = UDim2.new(0.5, -8, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
	Paper.label(body, ("Round %d"):format(if type(state) == "table" and type(state.round) == "number" then state.round else 1), 20, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.new(0.5, -8, 0, 28),
		Font = Paper.Fonts.Hand,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	local columnWidth = (BODY_WIDTH - 24) / 2
	local targetButtons: { [number]: TextButton } = {}
	local function styleTargets()
		for index, button in targetButtons do
			local chosen = index == selectedTarget
			button.BackgroundColor3 = if chosen then Paper.Colors.Ink else Paper.Colors.Paper
			button.TextColor3 = if chosen then Paper.Colors.Paper else Paper.Colors.Ink
		end
		highlightTarget(selectedTarget)
	end
	for row, index in standing do
		local enemy = enemies[index]
		local button = Paper.button(body, ("%s   %d / %d"):format(enemy.name, enemy.hp, enemy.maxHp), {
			Position = UDim2.fromOffset(8, 44 + (row - 1) * 50),
			Size = UDim2.fromOffset(columnWidth, 44),
			TextSize = 14,
			TextWrapped = true,
		})
		targetButtons[index] = button
		button.Activated:Connect(function()
			selectedTarget = index
			styleTargets()
		end)
	end
	styleTargets()

	local choice: string? = nil -- a move id, or "Brace"
	local firstButton: TextButton? = nil
	for row, id in moveIds do
		local move = (Moves.Player :: any)[id]
		local button = Paper.button(body, ("%s   ·   %d"):format(tostring(move.Name), move.Damage), {
			Position = UDim2.fromOffset(16 + columnWidth, 44 + (row - 1) * 50),
			Size = UDim2.fromOffset(columnWidth, 44),
			TextSize = 16,
		})
		firstButton = firstButton or button
		button.Activated:Connect(function()
			choice = choice or id
		end)
	end
	local canBrace = detail.canBrace ~= false
	local brace = Paper.button(body, if canBrace then "Brace" else "Brace  (too reckless)", {
		Position = UDim2.fromOffset(16 + columnWidth, 44 + #moveIds * 50),
		Size = UDim2.fromOffset(columnWidth, 44),
		TextSize = 16,
		BackgroundColor3 = Paper.Colors.PaperDark,
		TextColor3 = if canBrace then Paper.Colors.Ink else Paper.Colors.Pale,
		Active = canBrace,
		AutoButtonColor = canBrace,
	})
	if canBrace then
		brace.Activated:Connect(function()
			choice = choice or "Brace"
		end)
	end

	showCard(height)
	setCaption("Pick a target and a move, or brace to take a third less damage this round.")
	if usingGamepad() and firstButton then
		GuiService.SelectedObject = firstButton
	end

	-- Wait for a choice. If the server moves on by itself (the turn timer ran out), stop waiting.
	while choice == nil and not my.cancelled and #queue == 0 do
		task.wait(0.03)
	end
	clearTargetHighlight()
	if my.cancelled or choice == nil then
		return
	end

	if choice == "Brace" then
		send("Brace")
		hideCard()
		return
	end

	local move = (Moves.Player :: any)[choice]
	setCaption(tostring(move.Label))
	showCard(346)
	local grade = Minigames.run(body, move, my)
	if my.cancelled then
		return
	end
	send("Attack", choice, selectedTarget, grade)
end

local GRADE_BANNERS: { [string]: string } = { Perfect = "PERFECT!", Good = "HIT", Fail = "FAIL" }

local function onAttackResult(state: any, detail: any, my: Token)
	hideCard()
	local grade = if type(detail.grade) == "string" then detail.grade else "Fail"
	local color = if grade == "Perfect" then Paper.Colors.Gold elseif grade == "Good" then Paper.Colors.Light else Paper.Colors.Red
	showBanner(GRADE_BANNERS[grade] or "FAIL", color, 0.9)

	local enemy = if type(detail.target) == "number" then enemies[detail.target] else nil
	local move = (Moves.Player :: any)[detail.move]
	local damage = if type(detail.damage) == "number" then detail.damage else 0
	if enemy then
		if enemy.model then
			if damage > 0 then
				EnemyModels.flash(enemy.model)
				EnemyModels.popup(enemy.model, "-" .. damage, color)
			else
				EnemyModels.popup(enemy.model, "MISS", Paper.Colors.Light)
			end
		end
		local moveName = if move then tostring(move.Name) else "The attack"
		if damage <= 0 then
			setCaption(("%s misses %s completely."):format(moveName, enemy.name))
		elseif detail.down == true then
			setCaption(("%s drops %s."):format(moveName, enemy.name))
		else
			setCaption(("%s hits %s for %d."):format(moveName, enemy.name, damage))
		end
	end
	applyState(state)
	sleep(if detail.closeUp == true then 0.8 else 1.1, my)
end

local function onBraced(state: any, detail: any, my: Token)
	applyState(state)
	hideCard()
	if detail.braced == true then
		showBanner("BRACE", Paper.Colors.Light, 0.8)
		setCaption(if detail.auto == true then "No order given. You brace by instinct." else "You brace for what is coming.")
	else
		setCaption("No order given, and no thought of defence. The moment passes.")
	end
	sleep(0.8, my)
end

local function onEnemyAttack(state: any, detail: any, my: Token)
	applyState(state)
	local enemy = if type(detail.enemy) == "number" then enemies[detail.enemy] else nil
	local move = if type(detail.move) == "string" then (Moves.Enemy :: any)[detail.move] else nil
	if not move then
		warn(("[Combat] unknown enemy move %s"):format(tostring(detail.move)))
		return
	end
	local name = if enemy then enemy.name else "Enemy"
	if enemy and enemy.model then
		EnemyModels.lunge(enemy.model)
	end
	setCaption(("%s attacks."):format(name))

	body:ClearAllChildren()
	Paper.tab(body, name, { Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(190, 24) })
	Paper.label(body, tostring(move.Label), 19, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 4),
		Size = UDim2.fromOffset(BODY_WIDTH - 208, 28),
		Font = Paper.Fonts.Hand,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		TextScaled = true,
	})
	if detail.braced == true then
		Paper.label(body, "braced", 18, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -4),
			Size = UDim2.fromOffset(60, 22),
			Font = Paper.Fonts.Hand,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
	showCard(26 + 48 + FIELD_SIZE + 26)
	setDim(true)
	if not sleep(0.3, my) then
		return
	end

	local condition = currentCondition()
	local mods = {
		speed = if condition and type(condition.SoulSpeed) == "number" then condition.SoulSpeed else 1,
		radius = if condition and type(condition.SoulRadius) == "number" then condition.SoulRadius else 1,
	}
	local seed = if type(detail.seed) == "number" then detail.seed else 1
	local hits = DodgeBox.run(body, FIELD_SIZE, UDim2.new(0.5, 0, 0, 48), move, seed, mods, my)
	if my.cancelled then
		return
	end
	send("Dodged", hits)
end

local function onDodgeResult(state: any, detail: any, my: Token)
	applyState(state)
	setDim(false)
	local hits = if type(detail.hits) == "number" then detail.hits else 0
	local damage = if type(detail.damage) == "number" then detail.damage else 0
	if detail.knockedOut == true then
		showBanner(("-%d HP"):format(damage), Paper.Colors.Red, 0.9)
		setCaption("That one was the last you could take.")
	elseif hits <= 0 then
		showBanner("CLEAN DODGE", Paper.Colors.Light, 0.8)
		setCaption("Not a scratch. The nerves settle a little.")
	else
		showBanner(("-%d HP"):format(damage), Paper.Colors.Red, 0.9)
		setCaption(("Hit %d time%s for %d%s."):format(hits, if hits == 1 then "" else "s", damage, if detail.braced == true then ", braced" else ""))
	end
	if sleep(0.7, my) then
		hideCard()
		sleep(0.2, my)
	end
end

local function onCloseUp(state: any, detail: any, my: Token)
	if state ~= nil then
		applyState(state)
	else
		refreshStatus()
	end
	CloseUp.play(gui, detail, my)
end

local function onEnd(state: any, detail: any, my: Token)
	applyState(state)
	hideCard()
	setDim(false)
	if detail.won == true then
		showBanner("VICTORY", Paper.Colors.Gold, 2)
		setCaption("The deck is yours. For now.")
	else
		showBanner("DEFEATED", Paper.Colors.Red, 2)
		setCaption("The sea takes its due.")
	end
	sleep(2, my)
end

local function handle(item: QueueItem, my: Token)
	local event = item.event
	local detail: any = if type(item.detail) == "table" then item.detail else {}
	if event == "CloseUp" then
		onCloseUp(item.state, detail, my)
		return
	end
	if event == "Begin" then
		onBegin(item.state, detail)
		return
	end
	if not inBattle then
		return
	end
	if event == "PlayerTurn" then
		onPlayerTurn(item.state, detail, my)
	elseif event == "AttackResult" then
		onAttackResult(item.state, detail, my)
	elseif event == "Braced" then
		onBraced(item.state, detail, my)
	elseif event == "EnemyAttack" then
		onEnemyAttack(item.state, detail, my)
	elseif event == "DodgeResult" then
		onDodgeResult(item.state, detail, my)
	elseif event == "End" then
		onEnd(item.state, detail, my)
	end
end

local function pump()
	if working then
		return
	end
	working = true
	while #queue > 0 do
		local item = table.remove(queue, 1) :: QueueItem
		local my = token
		local ok, err = pcall(handle, item, my)
		if not ok then
			warn(("[Combat] error while handling %s: %s"):format(item.event, tostring(err)))
		end
	end
	working = false
end

local function onRemote(event: any, state: any, detail: any)
	if type(event) ~= "string" then
		return
	end
	if event == "Close" then
		-- Stop whatever is playing, drop anything still waiting, and pack up now.
		token.cancelled = true
		token = { cancelled = false }
		table.clear(queue)
		closeBattle()
		return
	end
	table.insert(queue, { event = event, state = state, detail = detail })
	task.spawn(pump)
end

------------------------------------------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------------------------------------------

local function buildGui()
	gui = Paper.screen("CombatGui", Paper.Layers.Card)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	battleRoot = Paper.frame(gui, { Name = "Battle", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false })
	dim = Paper.frame(battleRoot, { Name = "Dim", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 1 })

	local stage = Paper.frame(battleRoot, { Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(CARD_WIDTH + 20, 600), BackgroundTransparency = 1, ZIndex = 2 })
	stageScale = Paper.make("UIScale", { Scale = 1 }, stage)
	Paper.make("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, stage)

	local content: Frame
	sheet, content = Paper.sheet(stage, { Name = "Card", Size = UDim2.fromOffset(CARD_WIDTH, 10), ClipsDescendants = true, Visible = false, LayoutOrder = 1 })
	body = Paper.frame(content, { Name = "Body", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(BODY_WIDTH, 100), BackgroundTransparency = 1 })

	-- HP and Resolve, just under the card
	local status = Paper.frame(stage, { Name = "Status", Size = UDim2.fromOffset(CARD_WIDTH, STATUS_HEIGHT), BackgroundColor3 = Paper.Colors.Paper, LayoutOrder = 2 })
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2 }, status)
	local half = (CARD_WIDTH - 36) / 2
	hpLabel = Paper.label(status, "HP", 15, { Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(half, 22), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
	local hpBack = Paper.frame(status, { Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(half, 12), BackgroundColor3 = Paper.Colors.Pale })
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 1 }, hpBack)
	hpBar = Paper.frame(hpBack, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Paper.Colors.Red })

	resolveLabel = Paper.label(status, "Resolve", 15, { Position = UDim2.fromOffset(24 + half, 6), Size = UDim2.fromOffset(half, 22), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false })
	local resolveBack = Paper.frame(status, { Position = UDim2.fromOffset(24 + half, 32), Size = UDim2.fromOffset(half, 12), BackgroundColor3 = Paper.Colors.Pale })
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 1 }, resolveBack)
	resolveBar = Paper.frame(resolveBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Paper.Colors.Gold })
	-- the breaking point, halfway along the bar
	Paper.frame(resolveBack, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(Moves.Resolve.Break / Moves.Resolve.Max, 0.5), Size = UDim2.new(0, 2, 1, 6), BackgroundColor3 = Paper.Colors.Ink, ZIndex = 2 })

	caption = Paper.label(battleRoot, "", 20, {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(0.86, 0, 0, 52),
		TextColor3 = Paper.Colors.Light,
		TextStrokeTransparency = 0.3,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		ZIndex = 3,
	})
	banner = Paper.label(battleRoot, "", 44, {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.new(0.9, 0, 0, 60),
		TextColor3 = Paper.Colors.Light,
		TextStrokeTransparency = 0.2,
		TextWrapped = false,
		Visible = false,
		ZIndex = 4,
	})
end

function CombatController.start()
	buildGui()
	refreshStatus()

	local lastCondition = player:GetAttribute("Condition")
	for _, name in { "HP", "MaxHP", "Resolve" } do
		player:GetAttributeChangedSignal(name):Connect(refreshStatus)
	end
	player:GetAttributeChangedSignal("Condition"):Connect(function()
		local now = player:GetAttribute("Condition")
		if now == "" and type(lastCondition) == "string" and lastCondition ~= "" then
			local old = (Moves.Conditions :: any)[lastCondition]
			if old and inBattle then
				setCaption(("The nerves steady. %s fades."):format(tostring(old.Name)))
			end
		end
		lastCondition = now
		refreshStatus()
	end)

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end

	local found = ReplicatedStorage:WaitForChild("CombatRemote", 60)
	if not found or not found:IsA("RemoteEvent") then
		warn("[Combat] CombatRemote was not found; battles cannot be shown")
		return
	end
	remote = found
	found.OnClientEvent:Connect(onRemote)
	found:FireServer("Ready")
end

return CombatController
