--!strict
-- The fail close-up (decision D4): the screen dims, the player's character is shown in a tilted portrait (a clone
-- in a ViewportFrame), a word is stamped across it and the narrator says one line. The breaking point is the longer
-- version: a slow push-in, a heavier frame, and the Affliction or Virtue as the stamp.
--
-- CloseUp.play yields for detail.duration seconds. detail comes from CombatService:
--   { kind = "Fail" | "Break", stamp, caption, duration, resolveFrom?, resolveTo?, summary?, virtue? }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paper = require(Shared:WaitForChild("UI"):WaitForChild("Paper"))

local CloseUp = {}

export type Token = { cancelled: boolean }

local BLACK = Color3.new(0, 0, 0)

-- Clones the local character into the viewport. Returns the part to look at (the head), or nil.
local function addPortrait(viewport: ViewportFrame): BasePart?
	local player = Players.LocalPlayer
	local character = player and player.Character
	if not character then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local ok, clone = pcall(function()
		return character:Clone()
	end)
	character.Archivable = was
	if not ok or not clone then
		return nil
	end
	for _, item in clone:GetDescendants() do
		if item:IsA("LuaSourceContainer") or item:IsA("ForceField") or item:IsA("BillboardGui") or item:IsA("Sound") then
			item:Destroy()
		end
	end
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	clone.Parent = world
	local head = clone:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	local primary = clone.PrimaryPart or clone:FindFirstChildWhichIsA("BasePart", true)
	return primary
end

local function gradientEdge(parent: Instance, anchor: Vector2, position: UDim2, size: UDim2, rotation: number, strength: number)
	local edge = Paper.frame(parent, { AnchorPoint = anchor, Position = position, Size = size, BackgroundColor3 = BLACK, ZIndex = 3 })
	Paper.make("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1 - strength), NumberSequenceKeypoint.new(1, 1) }),
	}, edge)
end

function CloseUp.play(gui: ScreenGui, detail: any, token: Token)
	local isBreak = detail.kind == "Break"
	local duration = if type(detail.duration) == "number" then math.clamp(detail.duration, 0.5, 8) else 1.8
	local stampColor = if isBreak and detail.virtue == true then Paper.Colors.Gold else Paper.Colors.Red

	local root = Paper.frame(gui, { Name = "CloseUp", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = if isBreak then 0.2 else 0.35, ZIndex = 50 })

	-- manga speed lines pointing at the middle of the screen
	local rng = Random.new()
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local distance = rng:NextNumber(0.34, 0.46)
		Paper.frame(root, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5 + math.cos(angle) * distance, 0.5 + math.sin(angle) * distance),
			Size = UDim2.new(rng:NextNumber(0.12, 0.24), 0, 0, rng:NextInteger(2, 5)),
			Rotation = math.deg(angle),
			BackgroundColor3 = Paper.Colors.Light,
			BackgroundTransparency = 0.55,
			ZIndex = 1,
		})
	end

	-- Kept well under full screen: a ViewportFrame renders into its own texture, and a full-screen one is a large
	-- graphics allocation every time a close-up plays (Studio once ran out of graphics memory here).
	local viewport: ViewportFrame = Paper.make("ViewportFrame", {
		Name = "Portrait",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55, 0.7),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Ambient = Color3.fromRGB(110, 100, 104),
		LightColor = Color3.fromRGB(255, 236, 214),
		LightDirection = Vector3.new(-1, -0.6, 0.8),
		ZIndex = 2,
	}, root)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local ok, head = pcall(addPortrait, viewport)
	local focus: BasePart? = if ok then head else nil

	local function aim(distance: number)
		if not focus then
			return
		end
		local cf = focus.CFrame
		local target = cf.Position + Vector3.new(0, -0.2, 0)
		local from = cf.Position + cf.LookVector * distance + cf.RightVector * (distance * 0.18) + Vector3.new(0, 0.25, 0)
		camera.CFrame = CFrame.lookAt(from, target) * CFrame.Angles(0, 0, math.rad(if isBreak then -6 else 9))
	end
	aim(if isBreak then 9 else 5.5)

	-- a heavy frame: letterbox bars and dark edges
	local bar = if isBreak then 0.17 else 0.12
	Paper.frame(root, { Size = UDim2.fromScale(1, bar), BackgroundColor3 = BLACK, ZIndex = 4 })
	Paper.frame(root, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, bar), BackgroundColor3 = BLACK, ZIndex = 4 })
	local strength = if isBreak then 0.9 else 0.7
	gradientEdge(root, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.3, 1), 0, strength)
	gradientEdge(root, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.3, 1), 180, strength)

	-- the red ink stamp
	local stamp = Paper.frame(root, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, if isBreak then 0.3 else 0.34),
		Size = UDim2.fromOffset(if isBreak then 440 else 360, if isBreak then 96 else 78),
		BackgroundTransparency = 1,
		Rotation = -7,
		Visible = false,
		ZIndex = 6,
	})
	Paper.make("UIStroke", { Color = stampColor, Thickness = 5 }, stamp)
	local stampScale: UIScale = Paper.make("UIScale", { Scale = 2.2 }, stamp)
	Paper.label(stamp, tostring(detail.stamp or "FAIL"), if isBreak then 52 else 42, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = stampColor,
		TextWrapped = false,
		TextScaled = true,
		ZIndex = 6,
	})
	local summary: TextLabel? = nil
	if isBreak and type(detail.summary) == "string" then
		summary = Paper.label(root, detail.summary, 24, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.42),
			Size = UDim2.new(0.8, 0, 0, 60),
			Font = Paper.Fonts.Hand,
			TextColor3 = Paper.Colors.Light,
			TextStrokeTransparency = 0.4,
			Visible = false,
			ZIndex = 6,
		})
	end

	-- the narrator, in the lower bar
	Paper.label(root, tostring(detail.caption or ""), if isBreak then 22 else 20, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.86, 0, bar, -16),
		TextColor3 = Paper.Colors.Light,
		ZIndex = 7,
	})

	-- Resolve ticking up
	local resolveLabel: TextLabel? = nil
	local from, to = detail.resolveFrom, detail.resolveTo
	if type(from) == "number" and type(to) == "number" and from ~= to then
		resolveLabel = Paper.label(root, "Resolve " .. from, 20, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.new(0.6, 0, bar, -20),
			TextColor3 = Paper.Colors.Gold,
			ZIndex = 7,
		})
	end

	local stampAt = if isBreak then 1.3 else 0.3
	local start = os.clock()
	local animated, err = pcall(function()
		while not token.cancelled do
			RunService.RenderStepped:Wait()
			local t = os.clock() - start
			if t >= duration then
				break
			end
			if isBreak then
				-- the slow push-in
				aim(9 - 4.2 * math.clamp(t / (duration * 0.8), 0, 1))
			end
			if t >= stampAt then
				stamp.Visible = true
				local since = t - stampAt
				stampScale.Scale = 1 + 1.2 * (1 - math.clamp(since / 0.12, 0, 1))
				if summary then
					summary.Visible = since > 0.4
				end
				-- a short shake as the stamp lands
				if since > 0.1 and since < 0.4 then
					local power = (0.4 - since) * 40
					viewport.Position = UDim2.new(0.5, rng:NextNumber(-power, power), 0.5, rng:NextNumber(-power, power))
				else
					viewport.Position = UDim2.fromScale(0.5, 0.5)
				end
			end
			if resolveLabel and type(from) == "number" and type(to) == "number" then
				local alpha = math.clamp((t - 0.4) / 0.8, 0, 1)
				resolveLabel.Text = "Resolve " .. math.floor(from + (to - from) * alpha + 0.5)
			end
		end
	end)
	if not animated then
		warn(("[Combat] close-up error: %s"):format(tostring(err)))
	end
	root:Destroy()
end

return CloseUp
