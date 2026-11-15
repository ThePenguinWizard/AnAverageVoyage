--!strict
-- The dodge box (decisions D6 and D13): a square parchment field, the player's compass-star soul, and an enemy
-- move's pattern drawn as ink shapes. Every shape is telegraphed: it appears pale with a red outline, then turns
-- dark for a moment, which is when it hurts. A hit gives a short spell of invulnerability.
-- Move the soul with WASD, the arrow keys, a gamepad stick or D-pad, or by dragging on a touch screen.
--
-- DodgeBox.run plays one pattern and returns how many times the soul was hit. The pattern data and its timing
-- rules are in Shared.Combat.Moves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paper = require(Shared:WaitForChild("UI"):WaitForChild("Paper"))
local Moves = require(Shared:WaitForChild("Combat"):WaitForChild("Moves"))

local DodgeBox = {}

export type Token = { cancelled: boolean }
export type Mods = { speed: number, radius: number }

type Live = {
	e: any,
	warnAt: number,
	hurtAt: number,
	endAt: number,
	state: number, -- 0 waiting, 1 warning, 2 hurting, 3 done
	hit: boolean,
	randomA: number,
	randomB: number,
	-- geometry, set when the warning appears
	disc: boolean,
	x: number,
	y: number,
	r: number,
	axis: string,
	pos: number,
	half: number,
	gui: Frame?,
	stroke: UIStroke?,
	extras: { GuiObject },
}

local ARC_CENTRES: { [string]: Vector2 } = {
	Left = Vector2.new(0, 0.5),
	Right = Vector2.new(1, 0.5),
	Top = Vector2.new(0.5, 0),
	Bottom = Vector2.new(0.5, 1),
}

local KEYS_LEFT = { Enum.KeyCode.A, Enum.KeyCode.Left }
local KEYS_RIGHT = { Enum.KeyCode.D, Enum.KeyCode.Right }
local KEYS_UP = { Enum.KeyCode.W, Enum.KeyCode.Up }
local KEYS_DOWN = { Enum.KeyCode.S, Enum.KeyCode.Down }

local function anyDown(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function padDown(button: Enum.KeyCode): boolean
	local ok, down = pcall(function()
		return UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, button)
	end)
	return ok and down == true
end

-- Draws the compass-star soul inside `holder`.
local function drawSoul(holder: Frame, color: Color3)
	Paper.frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = color })
	Paper.frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 0.2), BackgroundColor3 = color })
	Paper.frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), Rotation = 45, BackgroundColor3 = color })
	Paper.frame(holder, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.16, 0.16), BackgroundColor3 = Paper.Colors.Paper, ZIndex = 2 })
end

local function setSoulColor(holder: Frame, color: Color3)
	for _, child in holder:GetChildren() do
		if child:IsA("Frame") and child.ZIndex < 2 then
			child.BackgroundColor3 = color
		end
	end
end

-- parent:   the frame to build in (the card's body)
-- size:     side of the square field in pixels
-- position: where the field's top centre goes inside parent
-- move:     an entry of Moves.Enemy
-- seed:     from the server, so random shapes are the same for everyone who may watch later
-- mods:     soul speed and hitbox multipliers (afflictions and virtues)
function DodgeBox.run(parent: Frame, size: number, position: UDim2, move: any, seed: number, mods: Mods, token: Token): number
	local rules = Moves.Dodge
	local rng = Random.new(seed)
	local radius = rules.SoulRadius * mods.radius
	local speed = rules.SoulSpeed * mods.speed
	local duration = Moves.patternDuration(move)

	local field = Paper.frame(parent, { Name = "Field", AnchorPoint = Vector2.new(0.5, 0), Position = position, Size = UDim2.fromOffset(size, size), BackgroundColor3 = Paper.Colors.PaperDark, ClipsDescendants = true })
	local fieldStroke = Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2 }, field)
	-- Things that must not be clipped (the soul, weapon marks outside the field) go on this layer.
	local top = Paper.frame(parent, { Name = "FieldTop", AnchorPoint = Vector2.new(0.5, 0), Position = position, Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 3 })

	local soulSize = math.max(16, math.floor(radius * 2 * size * 1.6))
	local soul = Paper.frame(top, { Name = "Soul", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(soulSize, soulSize), BackgroundTransparency = 1, ZIndex = 5 })
	drawSoul(soul, Paper.Colors.Teal)

	-- Elements, with their random numbers drawn up front so the pattern is the same for a given seed.
	local lives: { Live } = {}
	local rails: { any } = {}
	for _, e in move.Pattern do
		if e.Kind == "Rail" then
			table.insert(rails, e)
		else
			local warnAt = e.At
			local hurtAt = warnAt + (e.Warn or rules.Warn)
			table.insert(lives, {
				e = e,
				warnAt = warnAt,
				hurtAt = hurtAt,
				endAt = hurtAt + (e.Hurt or rules.Hurt),
				state = 0,
				hit = false,
				randomA = rng:NextNumber(),
				randomB = rng:NextNumber(),
				disc = false,
				x = 0,
				y = 0,
				r = 0,
				axis = "H",
				pos = 0,
				half = 0,
				gui = nil,
				stroke = nil,
				extras = {},
			})
		end
	end
	local railGuis: { [any]: Frame } = {}

	local soulPos = Vector2.new(0.5, 0.5)

	-- Decides where a shape goes and draws its warning.
	local function telegraph(live: Live)
		local e = live.e
		if e.Kind == "Arc" then
			local centre = ARC_CENTRES[e.Side] or ARC_CENTRES.Left
			live.disc = true
			live.x = centre.X
			live.y = centre.Y
			live.r = e.Reach or 0.56
		elseif e.Kind == "Blast" then
			live.disc = true
			live.r = e.Radius or 0.2
			if e.Aim == "Fixed" then
				live.x = e.X or 0.5
				live.y = e.Y or 0.5
			elseif e.Aim == "Random" then
				live.x = 0.1 + live.randomA * 0.8
				live.y = 0.1 + live.randomB * 0.8
			else
				live.x = soulPos.X
				live.y = soulPos.Y
			end
		else
			live.disc = false
			live.axis = if e.Axis == "V" then "V" else "H"
			live.half = (e.Width or 0.09) / 2
			if e.Aim == "Fixed" then
				live.pos = e.Pos or 0.5
			elseif e.Aim == "Random" then
				live.pos = 0.08 + live.randomA * 0.84
			else
				local aimed = if live.axis == "V" then soulPos.X else soulPos.Y
				local offset = e.Offset or 0
				local pos = aimed + offset
				if pos < 0.04 or pos > 0.96 then
					pos = aimed - offset
				end
				live.pos = math.clamp(pos, 0, 1)
			end
		end

		if live.disc then
			local gui = Paper.frame(field, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(live.x, live.y), Size = UDim2.fromScale(live.r * 2, live.r * 2), BackgroundColor3 = Paper.Colors.Pale, BackgroundTransparency = 0.3 })
			Paper.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, gui)
			live.stroke = Paper.make("UIStroke", { Color = Paper.Colors.Red, Thickness = 2 }, gui)
			live.gui = gui
			if e.Kind == "Arc" then
				-- the blade's hilt, drawn outside the card on the side the sweep comes from
				local vertical = e.Side == "Left" or e.Side == "Right"
				local mark = Paper.frame(top, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(live.x, if e.Side == "Left" then -12 elseif e.Side == "Right" then 12 else 0, live.y, if e.Side == "Top" then -12 elseif e.Side == "Bottom" then 12 else 0),
					Size = if vertical then UDim2.new(0, 6, 0.3, 0) else UDim2.new(0.3, 0, 0, 6),
					BackgroundColor3 = Paper.Colors.Ink,
				})
				table.insert(live.extras, mark)
			end
		else
			local horizontal = live.axis == "H"
			local gui = Paper.frame(field, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = if horizontal then UDim2.fromScale(0.5, live.pos) else UDim2.fromScale(live.pos, 0.5),
				Size = if horizontal then UDim2.fromScale(1, live.half * 2) else UDim2.fromScale(live.half * 2, 1),
				BackgroundColor3 = Paper.Colors.Pale,
				BackgroundTransparency = 0.3,
			})
			live.gui = gui
			-- the dashed red line along the shot's path
			local dashes = 9
			for i = 1, dashes do
				local along = (i - 0.5) / dashes
				local dash = Paper.frame(gui, {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = if horizontal then UDim2.fromScale(along, 0.5) else UDim2.fromScale(0.5, along),
					Size = if horizontal then UDim2.new(0.06, 0, 0, 3) else UDim2.new(0, 3, 0.06, 0),
					BackgroundColor3 = Paper.Colors.Red,
				})
				table.insert(live.extras, dash)
			end
			-- the muzzle, drawn outside the card where the shot comes from
			local mark = Paper.frame(top, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = if horizontal then UDim2.new(0, -12, live.pos, 0) else UDim2.new(live.pos, 0, 0, -12),
				Size = if horizontal then UDim2.fromOffset(14, 8) else UDim2.fromOffset(8, 14),
				BackgroundColor3 = Paper.Colors.Ink,
			})
			table.insert(live.extras, mark)
		end
	end

	local function darken(live: Live)
		local gui = live.gui
		if gui then
			gui.BackgroundColor3 = Paper.Colors.Ink
			gui.BackgroundTransparency = 0
		end
		if live.stroke then
			live.stroke.Color = Paper.Colors.Ink
		end
		for _, extra in live.extras do
			if gui and extra.Parent == gui then
				extra.Visible = false
			end
		end
	end

	local function clear(live: Live)
		if live.gui then
			live.gui:Destroy()
			live.gui = nil
		end
		for _, extra in live.extras do
			extra:Destroy()
		end
		table.clear(live.extras)
	end

	local function touches(live: Live): boolean
		if live.disc then
			return (soulPos - Vector2.new(live.x, live.y)).Magnitude < live.r + radius
		end
		local value = if live.axis == "V" then soulPos.X else soulPos.Y
		return math.abs(value - live.pos) < live.half + radius
	end

	-- Input: gamepad stick and touch drag come through events; keys are polled each frame.
	local stick = Vector2.zero
	local drag = Vector2.zero -- touch movement not yet applied, in field widths
	local activeTouch: InputObject? = nil
	local lastTouch = Vector2.zero
	local connections = {
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if input.KeyCode == Enum.KeyCode.Thumbstick1 then
				local v = Vector2.new(input.Position.X, -input.Position.Y)
				stick = if v.Magnitude > 0.2 then v else Vector2.zero
			end
		end),
		UserInputService.TouchStarted:Connect(function(input: InputObject)
			if not activeTouch then
				activeTouch = input
				lastTouch = Vector2.new(input.Position.X, input.Position.Y)
				drag = Vector2.zero
			end
		end),
		UserInputService.TouchMoved:Connect(function(input: InputObject)
			if input == activeTouch then
				local now = Vector2.new(input.Position.X, input.Position.Y)
				local pixels = math.max(1, field.AbsoluteSize.X)
				drag += (now - lastTouch) / pixels
				if drag.Magnitude > 0.6 then
					drag = drag.Unit * 0.6
				end
				lastTouch = now
			end
		end),
		UserInputService.TouchEnded:Connect(function(input: InputObject)
			if input == activeTouch then
				activeTouch = nil
				drag = Vector2.zero
			end
		end),
	}

	local hits = 0
	local invulnerableUntil = -1
	local start = os.clock()
	local ok, err = pcall(function()
		while not token.cancelled do
			local dt = math.min(RunService.RenderStepped:Wait(), 0.1)
			local t = os.clock() - start
			if t >= duration then
				break
			end

			-- The rail in force, if any.
			local railAxis: string? = nil
			for _, e in rails do
				local active = t >= e.At and t < e.At + (e.For or 0)
				if active then
					railAxis = if e.Axis == "V" then "V" else "H"
				end
				if active and not railGuis[e] then
					local horizontal = e.Axis ~= "V"
					railGuis[e] = Paper.frame(field, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = if horizontal then UDim2.new(1, 0, 0, 3) else UDim2.new(0, 3, 1, 0),
						BackgroundColor3 = Paper.Colors.Ink,
						BackgroundTransparency = 0.35,
						ZIndex = 2,
					})
				elseif not active and railGuis[e] then
					railGuis[e]:Destroy()
					railGuis[e] = nil
				end
			end

			-- Move the soul.
			local dir = Vector2.zero
			if anyDown(KEYS_LEFT) or padDown(Enum.KeyCode.DPadLeft) then
				dir += Vector2.new(-1, 0)
			end
			if anyDown(KEYS_RIGHT) or padDown(Enum.KeyCode.DPadRight) then
				dir += Vector2.new(1, 0)
			end
			if anyDown(KEYS_UP) or padDown(Enum.KeyCode.DPadUp) then
				dir += Vector2.new(0, -1)
			end
			if anyDown(KEYS_DOWN) or padDown(Enum.KeyCode.DPadDown) then
				dir += Vector2.new(0, 1)
			end
			dir += stick
			if dir.Magnitude > 1 then
				dir = dir.Unit
			end
			local step = dir * speed * dt
			if drag.Magnitude > 0 then
				local most = speed * dt
				local part = if drag.Magnitude > most then drag.Unit * most else drag
				drag -= part
				step += part
			end
			local x = soulPos.X + step.X
			local y = soulPos.Y + step.Y
			if railAxis == "H" then
				-- rides a left-right rail: slide to the middle row and stay there
				local toRail = math.clamp(0.5 - soulPos.Y, -3 * dt, 3 * dt)
				y = soulPos.Y + toRail
			elseif railAxis == "V" then
				local toRail = math.clamp(0.5 - soulPos.X, -3 * dt, 3 * dt)
				x = soulPos.X + toRail
			end
			soulPos = Vector2.new(math.clamp(x, radius, 1 - radius), math.clamp(y, radius, 1 - radius))
			soul.Position = UDim2.fromScale(soulPos.X, soulPos.Y)

			-- Advance the shapes and check for hits.
			for _, live in lives do
				if live.state == 0 and t >= live.warnAt then
					live.state = 1
					telegraph(live)
				end
				if live.state == 1 and t >= live.hurtAt then
					live.state = 2
					darken(live)
				end
				if live.state == 2 then
					if t >= live.endAt then
						live.state = 3
						clear(live)
					elseif not live.hit and t >= invulnerableUntil and touches(live) then
						live.hit = true
						hits += 1
						invulnerableUntil = t + rules.Invulnerable
					end
				end
			end

			-- The soul blinks red while it is invulnerable after a hit.
			if t < invulnerableUntil then
				setSoulColor(soul, Paper.Colors.Red)
				soul.Visible = math.floor(t * 14) % 2 == 0
				fieldStroke.Color = Paper.Colors.Red
			else
				setSoulColor(soul, Paper.Colors.Teal)
				soul.Visible = true
				fieldStroke.Color = Paper.Colors.Ink
			end
		end
	end)
	for _, connection in connections do
		connection:Disconnect()
	end
	if not ok then
		warn(("[Combat] dodge box error: %s"):format(tostring(err)))
		-- Sit out the rest of the attack: the server ignores a report that arrives before the pattern could end.
		while not token.cancelled and os.clock() - start < duration do
			task.wait(0.1)
		end
	end
	for _, live in lives do
		pcall(clear, live)
	end
	soul.Visible = true
	fieldStroke.Color = Paper.Colors.Ink
	return hits
end

return DodgeBox
