--!strict
-- Snappy comic-menu motion for the battle UI: things pop in with an overshoot, banners slam across the screen,
-- hits shake. Every function returns at once (the motion plays on its own) and is safe to call again on the same
-- object: it cancels what that object was doing.
--
--   Anim.popIn(gui, delay?)          grow from nothing with a little spin and overshoot
--   Anim.popOut(gui, done?)          shrink away, then call done
--   Anim.punch(gui, amount?)         a quick scale-up-and-back (a press, a number changing)
--   Anim.shake(gui, pixels?, time?)  jitter around its own position (a hit)
--   Anim.slamIn(gui, fromLeft?)      fly in from the side, tilted, and settle (banners)
--   Anim.sweep(parent, text)         the turn strip: a black band with big text that sweeps across and away

local TweenService = game:GetService("TweenService")

local Ink = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Ink"))

local Anim = {}

local running: { [Instance]: { Tween } } = {}

local function stop(gui: Instance)
	local list = running[gui]
	if list then
		for _, tween in list do
			tween:Cancel()
		end
		running[gui] = nil
	end
end

local function play(gui: Instance, target: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(target, info, goal)
	local list = running[gui]
	if not list then
		list = {}
		running[gui] = list
	end
	table.insert(list, tween)
	tween:Play()
	return tween
end

-- The UIScale every animated object uses (made on first use).
local function scaler(gui: GuiObject): UIScale
	local found = gui:FindFirstChild("AnimScale")
	if found and found:IsA("UIScale") then
		return found
	end
	local scale = Instance.new("UIScale")
	scale.Name = "AnimScale"
	scale.Parent = gui
	return scale
end

local function homeRotation(gui: GuiObject): number
	local home = gui:GetAttribute("AnimRotation")
	if type(home) ~= "number" then
		home = gui.Rotation
		gui:SetAttribute("AnimRotation", home)
	end
	return home :: number
end

local function homePosition(gui: GuiObject): UDim2
	local home = gui:GetAttribute("AnimPosition")
	if typeof(home) ~= "UDim2" then
		home = gui.Position
		gui:SetAttribute("AnimPosition", home)
	end
	return home :: UDim2
end

function Anim.popIn(gui: GuiObject, delay: number?)
	stop(gui)
	local scale = scaler(gui)
	local rotation = homeRotation(gui)
	scale.Scale = 0
	gui.Rotation = rotation - 25
	local info = TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay or 0)
	play(gui, scale, info, { Scale = 1 })
	play(gui, gui, info, { Rotation = rotation })
end

function Anim.popOut(gui: GuiObject, done: (() -> ())?)
	stop(gui)
	local scale = scaler(gui)
	local tween = play(gui, scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
	play(gui, gui, TweenInfo.new(0.12), { Rotation = homeRotation(gui) + 20 })
	if done then
		tween.Completed:Once(function()
			done()
		end)
	end
end

function Anim.punch(gui: GuiObject, amount: number?)
	local scale = scaler(gui)
	stop(scale)
	scale.Scale = 1 + (amount or 0.18)
	play(scale, scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

function Anim.shake(gui: GuiObject, pixels: number?, seconds: number?)
	local home = homePosition(gui)
	local size = pixels or 6
	local steps = math.max(2, math.floor((seconds or 0.25) / 0.03))
	task.spawn(function()
		for i = 1, steps do
			if gui.Parent == nil then
				return
			end
			local fade = 1 - (i - 1) / steps
			gui.Position = home + UDim2.fromOffset(math.random(-size, size) * fade, math.random(-size, size) * fade)
			task.wait(0.03)
		end
		gui.Position = home
	end)
end

function Anim.slamIn(gui: GuiObject, fromLeft: boolean?)
	stop(gui)
	local home = homePosition(gui)
	local rotation = homeRotation(gui)
	local side = if fromLeft == false then 1 else -1
	gui.Position = home + UDim2.fromScale(side * 0.7, 0)
	gui.Rotation = rotation + side * 14
	local scale = scaler(gui)
	scale.Scale = 1.25
	local info = TweenInfo.new(0.16, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	play(gui, gui, info, { Position = home, Rotation = rotation - side * 3 })
	play(gui, scale, info, { Scale = 1 })
	task.delay(0.16, function()
		if gui.Parent ~= nil then
			play(gui, gui, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = rotation })
			Anim.shake(gui, 4, 0.15)
		end
	end)
end

-- A layered box (Ink.box) arriving: the red shard whips in first, the black slab stretches open, the outline
-- snaps on, then the halftone and speed lines slide in. ~0.3 s.
function Anim.boxIn(box: Ink.Box)
	local function from(gui: GuiObject, offset: UDim2, rotation: number, delay: number, seconds: number)
		local homePos = homePosition(gui)
		local homeRot = homeRotation(gui)
		stop(gui)
		gui.Position = homePos + offset
		gui.Rotation = homeRot + rotation
		local info = TweenInfo.new(seconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay)
		play(gui, gui, info, { Position = homePos, Rotation = homeRot })
	end
	from(box.shard, UDim2.fromOffset(-60, 10), -10, 0, 0.22)
	local slabScale = scaler(box.slab)
	stop(slabScale)
	slabScale.Scale = 0.6
	play(slabScale, slabScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.03), { Scale = 1 })
	from(box.outline, UDim2.fromOffset(8, -6), 4, 0.07, 0.16)
	from(box.halftone, UDim2.fromOffset(40, 0), 0, 0.12, 0.2)
	from(box.speed, UDim2.fromOffset(-50, 0), 0, 0.1, 0.2)
end

-- The turn strip: a long tilted layered box (Ink.box) with huge text that whips in from the left, holds, and
-- flies off to the right. Takes ~1 s.
function Anim.sweep(parent: Instance, text: string)
	local holder = Ink.make("Frame", {
		Name = "Sweep",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.9, 0.4),
		Size = UDim2.new(1.3, 0, 0, 112),
		Rotation = -6,
		BackgroundTransparency = 1,
		ZIndex = 8,
	}, parent) :: Frame
	local box = Ink.box(holder, { Size = UDim2.fromScale(1, 1) }, 8, 0.6)
	box.speed.Size = UDim2.new(0, 180, 1.3, 0)
	box.halftone.Size = UDim2.fromScale(0.12, 0.85)
	Ink.text(box.root, text, 90, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.42, 0, 1, -24),
		FontFace = Ink.Fonts.Display,
		TextScaled = true,
		ZIndex = 14,
	})
	TweenService:Create(holder, TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.4) }):Play()
	Anim.boxIn(box)
	task.delay(0.8, function()
		local out = TweenService:Create(holder, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.In), { Position = UDim2.fromScale(1.9, 0.4) })
		out:Play()
		out.Completed:Once(function()
			holder:Destroy()
		end)
	end)
end

return Anim
