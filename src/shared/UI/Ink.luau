--!strict
-- The battle UI kit: bold comic menus built from stacked layers (a red shard behind, a black slab, a jagged cream
-- outline, halftone dots, speed lines) that can each move on their own, plus big comic numbers. The art lives in
-- assets/ui (cut with tools/ui/cut_sheet.py) and is uploaded as images; the ids are below. Everything outside
-- battles still uses Shared.UI.Paper.
--
--   Ink.image(parent, "Sword", props)       an ImageLabel showing one piece of art (scaled to fit)
--   Ink.panel(parent, "Slab", props)        a 9-sliced layer that stretches to any size
--   Ink.box(parent, props)                  a whole layered box (see Client.Combat.Anim.boxIn to bring it in)
--   Ink.text(parent, text, size, props)     cream text with a black outline; Ink.Fonts.Display for numbers
--   Ink.MoveIcons[moveId]                   the icon for a player move (and "Brace")

local Ink = {}

-- Uploaded art (assets/ui, made with ChatGPT in the style of the user's UI sheets; sheets in assets/ui/sheets).
Ink.Images = {
	-- move tiles: idle is black, lit is cream with a burst (draw lit ~1.4x the idle size)
	TileIdle = "rbxassetid://79570364026870",
	TileLit = "rbxassetid://77248722798969",
	KeyBadge = "rbxassetid://105523565238640",
	-- icons
	Sword = "rbxassetid://109759595242984",
	Lightning = "rbxassetid://134560256506930",
	Shield = "rbxassetid://116331142679999",
	Crosshair = "rbxassetid://100647258139525",
	Eye = "rbxassetid://96698936641245",
	Fist = "rbxassetid://140600864303163",
	Wing = "rbxassetid://133893030727306",
	Star = "rbxassetid://82002810220451",
	-- layers for Ink.box (slab, outline and shard are 9-sliced)
	Slab = "rbxassetid://86066106943692",
	Outline = "rbxassetid://91130087662885",
	Shard = "rbxassetid://98447018299436",
	Halftone = "rbxassetid://75479083270267",
	Speed = "rbxassetid://75035807688232",
	Burst = "rbxassetid://140701376881026",
	-- HP bar: black inside, white fill shape (tint it, clip its width), hollow frame on top. All three line up.
	BarBack = "rbxassetid://109397758417299",
	BarFill = "rbxassetid://123355399983643",
	BarFrame = "rbxassetid://108773810853077",
	-- banners and markers
	Banner = "rbxassetid://93829797163845",
	Badge = "rbxassetid://137415997496410",
	MarkAlert = "rbxassetid://119218031088774",
	MarkX = "rbxassetid://75771539903630",
	Marker = "rbxassetid://112034390733486",
}

-- Pixel size of each piece of art, and for 9-sliced panels the part that stretches (left, top, right, bottom).
type Slice = { size: Vector2, center: Rect }
local SLICES: { [string]: Slice } = {
	Slab = { size = Vector2.new(468, 208), center = Rect.new(100, 64, 368, 144) },
	Outline = { size = Vector2.new(478, 208), center = Rect.new(105, 64, 373, 144) },
	Shard = { size = Vector2.new(498, 278), center = Rect.new(110, 90, 388, 188) },
}

Ink.Colors = {
	Black = Color3.fromRGB(14, 12, 12),
	Cream = Color3.fromRGB(246, 238, 220),
	Red = Color3.fromRGB(232, 32, 36),
	Cyan = Color3.fromRGB(128, 238, 230),
	Gold = Color3.fromRGB(255, 212, 84),
	Grey = Color3.fromRGB(90, 90, 92),
}

Ink.Fonts = {
	Display = Font.new("rbxasset://fonts/families/Bangers.json"),
	Body = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.ExtraBold),
}

Ink.MoveIcons = {
	Slash = "Sword",
	Cleave = "Lightning",
	AimedShot = "Crosshair",
	Deadeye = "Eye",
	Combo = "Fist",
	Flurry = "Wing",
	Brace = "Shield",
} :: { [string]: string }

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end
Ink.make = make

function Ink.image(parent: Instance?, key: string, props: { [string]: any }?): ImageLabel
	local p: { [string]: any } = props or {}
	p.Image = Ink.Images[key] or key
	p.BackgroundTransparency = 1
	p.ScaleType = p.ScaleType or Enum.ScaleType.Fit
	p.BorderSizePixel = 0
	return make("ImageLabel", p, parent)
end

-- A panel that stretches to any size. `scale` shrinks the corners (1 = the art's own pixel size).
function Ink.panel(parent: Instance?, key: string, props: { [string]: any }?, scale: number?): ImageLabel
	local p: { [string]: any } = props or {}
	local slice = SLICES[key]
	p.Image = Ink.Images[key]
	p.BackgroundTransparency = 1
	p.BorderSizePixel = 0
	if slice then
		p.ScaleType = Enum.ScaleType.Slice
		p.SliceCenter = slice.center
		p.SliceScale = scale or 0.4
	else
		p.ScaleType = Enum.ScaleType.Stretch
	end
	return make("ImageLabel", p, parent)
end

export type Box = {
	root: Frame,
	shard: ImageLabel,
	slab: ImageLabel,
	outline: ImageLabel,
	halftone: ImageLabel,
	speed: ImageLabel,
}

-- A layered box: a red shard peeking out behind, a black slab, a jagged cream outline on top, red halftone dots in
-- one corner and cream speed lines off the left end. Each layer is its own image so it can move on its own (see
-- Client.Combat.Anim.boxIn). `props` sizes and places the root; content goes in box.root above the layers
-- (ZIndex `z` + 4 and up). `scale` sizes the jagged corners (1 = the art's own pixels).
function Ink.box(parent: Instance?, props: { [string]: any }, z: number?, scale: number?): Box
	local base = z or 1
	local s = scale or 0.4
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	local root = make("Frame", props, parent) :: Frame
	local function layer(key: string, extra: { [string]: any }): ImageLabel
		extra.Name = key
		return Ink.panel(root, key, extra, s)
	end
	local box = {
		root = root,
		shard = layer("Shard", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 10, 0.5, 8),
			Size = UDim2.new(1, 22, 1, 26),
			Rotation = 1.5,
			ZIndex = base,
		}),
		slab = layer("Slab", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			ZIndex = base + 1,
		}),
		outline = layer("Outline", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, -3, 0.5, -2),
			Size = UDim2.new(1, 6, 1, 4),
			ZIndex = base + 2,
		}),
		halftone = Ink.image(root, "Halftone", {
			Name = "Halftone",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -18, 1, -6),
			Size = UDim2.fromScale(0.16, 0.7),
			Rotation = 180,
			ImageTransparency = 0.15,
			ZIndex = base + 3,
		}),
		speed = Ink.image(root, "Speed", {
			Name = "Speed",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(0, 18, 0.35, 0),
			Size = UDim2.new(0, 70, 0.9, 0),
			ZIndex = base,
		}),
	}
	return box
end

function Ink.text(parent: Instance?, text: string, size: number, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = props or {}
	p.Text = text
	p.TextSize = size
	p.BackgroundTransparency = 1
	p.FontFace = p.FontFace or Ink.Fonts.Body
	p.TextColor3 = p.TextColor3 or Ink.Colors.Cream
	p.TextStrokeColor3 = p.TextStrokeColor3 or Ink.Colors.Black
	if p.TextStrokeTransparency == nil then
		p.TextStrokeTransparency = 0
	end
	if p.TextWrapped == nil then
		p.TextWrapped = false
	end
	return make("TextLabel", p, parent)
end

return Ink
