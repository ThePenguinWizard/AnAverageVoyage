--!strict
-- The three attack minigames (decision D3), drawn on the parchment card: timing bar, drifting crosshair, rhythm.
-- Minigames.run builds one inside `body`, plays it, and returns "Perfect", "Good" or "Fail".
-- Strike with Space, Enter, gamepad A / X / R2, or the Strike button (mouse or touch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paper = require(Shared:WaitForChild("UI"):WaitForChild("Paper"))

local Minigames = {}

export type Token = { cancelled: boolean }

local LEAD_IN = 0.45 -- seconds before the game starts, so the click that chose the move cannot count as a strike
local RESULT_HOLD = 0.5 -- seconds the result stays on the card

local STRIKE_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.Space] = true,
	[Enum.KeyCode.Return] = true,
	[Enum.KeyCode.ButtonA] = true,
	[Enum.KeyCode.ButtonX] = true,
	[Enum.KeyCode.ButtonR2] = true,
}

local GRADE_TEXT = { Perfect = "PERFECT", Good = "GOOD", Fail = "MISSED" }

local function gradeColor(grade: string): Color3
	if grade == "Perfect" then
		return Paper.Colors.Gold
	elseif grade == "Good" then
		return Paper.Colors.Ink
	end
	return Paper.Colors.Red
end

-- Collects strike presses. `times` fills with os.clock() values; call `stop` when done.
local function listen(button: TextButton): ({ number }, () -> ())
	local times: { number } = {}
	local last = 0
	local function press()
		local now = os.clock()
		if now - last > 0.07 then
			last = now
			table.insert(times, now)
		end
	end
	local connections = {
		button.MouseButton1Down:Connect(press),
		UserInputService.InputBegan:Connect(function(input: InputObject)
			if STRIKE_KEYS[input.KeyCode] then
				press()
			end
		end),
	}
	return times, function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

local function round(parent: Instance)
	Paper.make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, parent)
end

local function wait(seconds: number, token: Token)
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not token.cancelled do
		RunService.RenderStepped:Wait()
	end
end

-- Timing: a blade sweeps back and forth along a bar; strike while it is in the middle.
local function playTiming(area: Frame, tuning: any, times: { number }, token: Token): string
	local bar = Paper.frame(area, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 0, 36), BackgroundColor3 = Paper.Colors.PaperDark })
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2 }, bar)
	Paper.frame(bar, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(tuning.Good * 2, 1), BackgroundColor3 = Paper.Colors.Pale })
	Paper.frame(bar, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(tuning.Perfect * 2, 1), BackgroundColor3 = Paper.Colors.Gold })
	local marker = Paper.frame(bar, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 6, 1, 18), BackgroundColor3 = Paper.Colors.Ink, ZIndex = 3 })

	wait(LEAD_IN, token)
	table.clear(times)
	local start = os.clock()
	local grade = "Fail"
	while not token.cancelled do
		RunService.RenderStepped:Wait()
		local pressedAt = times[1]
		local t = (pressedAt or os.clock()) - start
		local phase = t * tuning.Speed
		local pos = phase % 2
		if pos > 1 then
			pos = 2 - pos
		end
		marker.Position = UDim2.fromScale(pos, 0.5)
		if pressedAt then
			local off = math.abs(pos - 0.5)
			if off <= tuning.Perfect then
				grade = "Perfect"
			elseif off <= tuning.Good then
				grade = "Good"
			end
			break
		end
		if phase >= tuning.Passes then
			break
		end
	end
	marker.BackgroundColor3 = gradeColor(grade)
	return grade
end

-- Aim: a crosshair drifts in a figure of eight that passes over the mark; fire while it is on it.
local function playAim(area: Frame, tuning: any, times: { number }, token: Token): string
	local size = 170
	local box = Paper.frame(area, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Paper.Colors.PaperDark })
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2 }, box)

	local frequency = 0.3 * tuning.Speed
	local phaseX = math.random() * math.pi * 2
	local function path(t: number): Vector2
		local a = t * frequency * math.pi * 2
		return Vector2.new(0.5 + 0.36 * math.sin(a + phaseX), 0.5 + 0.36 * math.sin(a * 2))
	end
	local mark = path(0.9 + math.random() / frequency)

	local goodRing = Paper.frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(mark.X, mark.Y), Size = UDim2.fromScale(tuning.Good * 2, tuning.Good * 2), BackgroundColor3 = Paper.Colors.Pale })
	round(goodRing)
	Paper.make("UIStroke", { Color = Paper.Colors.Red, Thickness = 2 }, goodRing)
	local perfectRing = Paper.frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(mark.X, mark.Y), Size = UDim2.fromScale(tuning.Perfect * 2, tuning.Perfect * 2), BackgroundColor3 = Paper.Colors.Gold, ZIndex = 2 })
	round(perfectRing)

	local cross = Paper.frame(box, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, ZIndex = 4 })
	local lineH = Paper.frame(cross, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Paper.Colors.Ink, ZIndex = 4 })
	local lineV = Paper.frame(cross, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = Paper.Colors.Ink, ZIndex = 4 })
	local ring = Paper.frame(cross, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6), BackgroundTransparency = 1, ZIndex = 4 })
	round(ring)
	local ringStroke = Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2 }, ring)

	wait(LEAD_IN, token)
	table.clear(times)
	local start = os.clock()
	local grade = "Fail"
	while not token.cancelled do
		RunService.RenderStepped:Wait()
		local pressedAt = times[1]
		local t = (pressedAt or os.clock()) - start
		local pos = path(t)
		cross.Position = UDim2.fromScale(pos.X, pos.Y)
		if pressedAt then
			local off = (pos - mark).Magnitude
			if off <= tuning.Perfect then
				grade = "Perfect"
			elseif off <= tuning.Good then
				grade = "Good"
			end
			break
		end
		if t >= tuning.Time then
			break
		end
	end
	local color = gradeColor(grade)
	lineH.BackgroundColor3 = color
	lineV.BackgroundColor3 = color
	ringStroke.Color = color
	return grade
end

-- Rhythm: a marker runs along a row of rings; strike as it crosses each one.
local function playRhythm(area: Frame, tuning: any, times: { number }, token: Token): string
	local beats = math.max(1, math.floor(tuning.Beats))
	local track = Paper.frame(area, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 0, 60), BackgroundTransparency = 1 })
	Paper.frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = Paper.Colors.Pale })
	local rings: { Frame } = {}
	for i = 1, beats do
		local ringFrame = Paper.frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i / (beats + 1), 0.5), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Paper.Colors.PaperDark, ZIndex = 2 })
		round(ringFrame)
		Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2 }, ringFrame)
		rings[i] = ringFrame
	end
	local marker = Paper.frame(track, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 5, 1, 0), BackgroundColor3 = Paper.Colors.Ink, ZIndex = 3 })

	wait(LEAD_IN, token)
	table.clear(times)
	local start = os.clock()
	local lead = 0.9 -- seconds before the first beat
	local function beatTime(i: number): number
		return lead + (i - 1) * tuning.Interval
	end

	local current = 1
	local used = 0 -- presses already judged
	local perfects = 0
	local failed = false
	while not token.cancelled and not failed and current <= beats do
		RunService.RenderStepped:Wait()
		local now = os.clock() - start
		marker.Position = UDim2.fromScale(math.clamp((1 + (now - lead) / tuning.Interval) / (beats + 1), 0, 1), 0.5)

		while used < #times and current <= beats and not failed do
			used += 1
			local t = times[used] - start
			local off = t - beatTime(current)
			if off < -tuning.Interval * 0.5 then
				-- far too early to belong to this beat: ignored
				continue
			end
			if math.abs(off) <= tuning.Perfect then
				perfects += 1
				rings[current].BackgroundColor3 = Paper.Colors.Gold
				current += 1
			elseif math.abs(off) <= tuning.Good then
				rings[current].BackgroundColor3 = Paper.Colors.Ink
				current += 1
			else
				rings[current].BackgroundColor3 = Paper.Colors.Red
				failed = true
			end
		end
		if not failed and current <= beats and now > beatTime(current) + tuning.Good then
			rings[current].BackgroundColor3 = Paper.Colors.Red
			failed = true
		end
	end
	if failed or current <= beats then
		return "Fail"
	end
	-- Perfect allows one beat that was only Good.
	return if perfects >= beats - 1 then "Perfect" else "Good"
end

-- `move` is an entry of Moves.Player. Yields until the minigame is over.
function Minigames.run(body: Frame, move: any, token: Token): string
	body:ClearAllChildren()
	Paper.label(body, tostring(move.Name), 22, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 30), TextXAlignment = Enum.TextXAlignment.Left })
	local hint = Paper.label(body, tostring(move.Hint), 20, { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 28), Font = Paper.Fonts.Hand, TextXAlignment = Enum.TextXAlignment.Left })
	local area = Paper.frame(body, { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66 - 64), BackgroundTransparency = 1 })
	local button = Paper.button(body, "Strike!", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -20, 0, 52), TextSize = 20 })

	local times, stop = listen(button)
	local ok, result = pcall(function(): string
		if move.Game == "Aim" then
			return playAim(area, move.Tuning, times, token)
		elseif move.Game == "Rhythm" then
			return playRhythm(area, move.Tuning, times, token)
		end
		return playTiming(area, move.Tuning, times, token)
	end)
	stop()
	local grade = "Fail"
	if ok and (result == "Perfect" or result == "Good") then
		grade = result
	elseif not ok then
		warn(("[Combat] minigame error: %s"):format(tostring(result)))
	end
	button.Active = false
	button.AutoButtonColor = false
	hint.Text = GRADE_TEXT[grade]
	hint.TextColor3 = gradeColor(grade)
	wait(RESULT_HOLD, token)
	return grade
end

return Minigames
