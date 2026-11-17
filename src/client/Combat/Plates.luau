--!strict
-- The HP plates that float over every fighter in a battle: this player's crew (other players too) and this
-- player's enemies. Each is a big comic HP number in front of a slanted bar (Shared.UI.Ink art). Crew plates
-- add a thin cyan Resolve bar. The target's plate shows its name and a red marker.
--
-- Each plate is a BillboardGui in the PlayerGui (not in the world) so it can be tapped: tapping an enemy's plate
-- makes it the target.
--
--   local plate = Plates.new(head, "Enemy")
--   plate.set(hp, maxHp)             -- crew plates also take Resolve: plate.set(hp, maxHp, resolve)
--   plate.setName("Pirate Deckhand") -- shown above the bar; "" hides it
--   plate.setTarget(true)            -- the red marker and a gold name
--   plate.button.Activated:Connect(...)
--   plate.destroy()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Ink = require(Shared:WaitForChild("UI"):WaitForChild("Ink"))
local Moves = require(Shared:WaitForChild("Combat"):WaitForChild("Moves"))
local Anim = require(script.Parent:WaitForChild("Anim"))

local Plates = {}

export type Kind = "Crew" | "Enemy"

export type Plate = {
	gui: BillboardGui,
	button: TextButton,
	set: (hp: number, maxHp: number, resolve: number?) -> (),
	setName: (text: string) -> (),
	setTarget: (on: boolean) -> (),
	destroy: () -> (),
}

local WIDTH, HEIGHT = 216, 98
local BAR_X, BAR_Y, BAR_W, BAR_H = 56, 52, 154, 22 -- the bar art is 1448 x 208 px

function Plates.new(adornee: BasePart, kind: Kind): Plate
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("BillboardGui")
	gui.Name = kind .. "Plate"
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	gui.SizeOffset = Vector2.new(0, 0.5) -- the bottom edge sits just above the head
	gui.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 300
	gui.ResetOnSpawn = false
	gui.Active = true

	local button = Ink.make("TextButton", {
		Name = "Tap",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Selectable = kind == "Enemy",
		Active = kind == "Enemy",
	}, gui) :: TextButton

	local marker = Ink.image(button, "Marker", {
		Name = "Marker",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(BAR_X + BAR_W / 2, 0),
		Size = UDim2.fromOffset(26, 29), -- the marker art is 268 x 298 px
		Visible = false,
		ZIndex = 4,
	})
	local bob = TweenService:Create(
		marker,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(BAR_X + BAR_W / 2, 5) }
	)

	local title = Ink.text(button, "", 18, {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(BAR_X + BAR_W / 2 - 10, 30),
		Size = UDim2.fromOffset(WIDTH, 20),
		FontFace = Ink.Fonts.Display,
		Visible = false,
		ZIndex = 4,
	})

	-- The bar: its black inside, a white fill shape tinted red and clipped to how full it is, the jagged frame on top.
	local bar = Ink.make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(BAR_X, BAR_Y),
		Size = UDim2.fromOffset(BAR_W, BAR_H),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, button) :: Frame
	local back = Ink.image(bar, "BarBack", { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Stretch, ZIndex = 1 })
	local clip = Ink.make("Frame", {
		Name = "Clip",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 2,
	}, bar) :: Frame
	local fill = Ink.image(clip, "BarFill", {
		Size = UDim2.fromOffset(BAR_W, BAR_H),
		ScaleType = Enum.ScaleType.Stretch,
		ImageColor3 = Ink.Colors.Red,
		ZIndex = 2,
	})
	local frame = Ink.image(bar, "BarFrame", { Size = UDim2.fromScale(1, 1), ScaleType = Enum.ScaleType.Stretch, ZIndex = 3 })

	-- the HP number, big and in front of the bar's left end
	local number = Ink.text(button, "", 34, {
		Name = "Number",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(BAR_X + 20, BAR_Y + BAR_H / 2 - 2),
		Size = UDim2.fromOffset(BAR_X + 20, 36),
		FontFace = Ink.Fonts.Display,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})

	local resolveFill: Frame? = nil
	if kind == "Crew" then
		local back = Ink.make("Frame", {
			Name = "Resolve",
			Position = UDim2.fromOffset(BAR_X + 14, BAR_Y + BAR_H + 3),
			Size = UDim2.fromOffset(BAR_W - 40, 6),
			BackgroundColor3 = Ink.Colors.Black,
			BorderSizePixel = 0,
			Rotation = -2,
			ZIndex = 2,
		}, button) :: Frame
		Ink.make("UIStroke", { Color = Ink.Colors.Cream, Thickness = 1.5 }, back)
		resolveFill = Ink.make("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = Ink.Colors.Cyan,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, back)
	end

	gui.Parent = playerGui

	local lastHp: number? = nil
	local plate = {} :: Plate
	plate.gui = gui
	plate.button = button

	function plate.set(hp: number, maxHp: number, resolve: number?)
		local top = math.max(1, math.floor(maxHp + 0.5))
		local now = math.floor(math.clamp(hp, 0, top) + 0.5)
		clip.Size = UDim2.fromScale(now / top, 1)
		number.Text = tostring(now)
		-- a hit: the plate shakes, the number punches and the bar flashes white for a moment
		if lastHp and now < lastHp then
			Anim.shake(button, 5, 0.3)
			Anim.punch(number, 0.35)
			fill.ImageColor3 = Ink.Colors.Cream
			task.delay(0.08, function()
				fill.ImageColor3 = Ink.Colors.Red
			end)
		elseif lastHp and now > lastHp then
			Anim.punch(number, 0.2)
		end
		lastHp = now
		local down = now <= 0
		for _, layer in { back, fill, frame } do
			layer.ImageTransparency = if down then 0.5 else 0
		end
		number.TextTransparency = if down then 0.5 else 0
		if resolveFill and resolve then
			resolveFill.Size = UDim2.fromScale(math.clamp(resolve / Moves.Resolve.Max, 0, 1), 1)
			resolveFill.BackgroundColor3 = if resolve >= Moves.Resolve.Break then Ink.Colors.Red else Ink.Colors.Cyan
		end
	end

	function plate.setName(text: string)
		title.Text = string.upper(text)
		title.Visible = text ~= ""
	end

	function plate.setTarget(on: boolean)
		if on and not marker.Visible then
			Anim.popIn(marker)
		end
		marker.Visible = on
		if on then
			bob:Play()
		else
			bob:Cancel()
		end
		title.TextColor3 = if on then Ink.Colors.Gold else Ink.Colors.Cream
	end

	function plate.destroy()
		bob:Cancel()
		gui:Destroy()
	end

	return plate
end

return Plates
