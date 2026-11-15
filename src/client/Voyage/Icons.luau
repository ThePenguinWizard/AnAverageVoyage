--!strict
-- Small ink drawings for the island kinds on the sea chart, made of frames and text only (no images).
-- Everything is sized in scale units, so one drawing works for big chart markers and small legend entries.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Paper = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("Paper"))

local Icons = {}

-- A bar centred at (x, y), all in 0-1 units of the parent, turned by `rotation` degrees.
local function bar(parent: Instance, x: number, y: number, width: number, height: number, rotation: number, color: Color3): Frame
	return Paper.frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(width, height),
		Rotation = rotation,
		BackgroundColor3 = color,
	})
end

local function disc(parent: Instance, x: number, y: number, size: number, color: Color3): Frame
	local frame = bar(parent, x, y, size, size, 0, color)
	Paper.make("UICorner", { CornerRadius = UDim.new(1, 0) }, frame)
	return frame
end

local function glyph(parent: Instance, text: string, color: Color3)
	Paper.label(parent, text, 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.8),
		TextScaled = true,
		TextWrapped = false,
		TextColor3 = color,
	})
end

local function crossedBlades(parent: Instance, color: Color3)
	bar(parent, 0.5, 0.5, 0.74, 0.11, 45, color)
	bar(parent, 0.5, 0.5, 0.74, 0.11, -45, color)
end

-- Draws the icon for `kind` inside `parent` (a square). `background` is the colour behind it, which the crescent
-- moon needs to cut its shape.
function Icons.draw(parent: Instance, kind: string, background: Color3)
	local colors = Paper.Colors
	if kind == "Battle" then
		crossedBlades(parent, colors.Ink)
	elseif kind == "Elite" then
		crossedBlades(parent, colors.Red)
		disc(parent, 0.5, 0.5, 0.2, colors.Red)
	elseif kind == "Boss" then
		-- Drawn light on the dark boss marker: crossed blades under a pair of eyes.
		crossedBlades(parent, colors.Paper)
		disc(parent, 0.36, 0.3, 0.14, colors.Red)
		disc(parent, 0.64, 0.3, 0.14, colors.Red)
	elseif kind == "Event" then
		glyph(parent, "!", colors.Ink)
	elseif kind == "Rest" then
		-- A crescent moon: an ink disc with a bite taken out of it.
		disc(parent, 0.48, 0.52, 0.56, colors.Ink)
		disc(parent, 0.6, 0.42, 0.46, background)
	elseif kind == "Treasure" then
		-- A chest: gold box, lid line, lock.
		local chest = bar(parent, 0.5, 0.55, 0.6, 0.42, 0, colors.Gold)
		Paper.make("UIStroke", { Color = colors.Ink, Thickness = 1.5 }, chest)
		bar(parent, 0.5, 0.47, 0.6, 0.06, 0, colors.Ink)
		bar(parent, 0.5, 0.58, 0.12, 0.14, 0, colors.Ink)
	elseif kind == "Port" then
		-- A harbour flag on a pole.
		bar(parent, 0.36, 0.5, 0.08, 0.66, 0, colors.Ink)
		bar(parent, 0.57, 0.31, 0.34, 0.26, 0, colors.Teal)
		bar(parent, 0.42, 0.83, 0.4, 0.08, 0, colors.Ink)
	else
		glyph(parent, "?", colors.Ink:Lerp(colors.Paper, 0.45)) -- fog: faded ink
	end
end

return Icons
