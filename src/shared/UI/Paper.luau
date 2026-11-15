--!strict
-- Shared "ink on parchment" UI kit (design decision D13). Every screen should build its UI from these helpers so the
-- game looks like one thing: cream paper, dark ink borders, serif type, handwritten notes.

local Players = game:GetService("Players")

local Paper = {}

Paper.Colors = {
	Paper = Color3.fromRGB(238, 226, 192),
	PaperDark = Color3.fromRGB(226, 212, 176),
	Edge = Color3.fromRGB(214, 198, 160),
	Ink = Color3.fromRGB(52, 38, 30),
	Pale = Color3.fromRGB(206, 186, 150),
	Red = Color3.fromRGB(170, 48, 40),
	Teal = Color3.fromRGB(34, 128, 128),
	Gold = Color3.fromRGB(190, 146, 44),
	Light = Color3.fromRGB(255, 246, 226), -- text drawn over the 3D world
}
Paper.Fonts = { Serif = Enum.Font.Merriweather, Hand = Enum.Font.IndieFlower }

-- DisplayOrder conventions so screens stack predictably.
Paper.Layers = { Hud = 1, Panel = 5, Card = 10, Overlay = 20 }

function Paper.make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = parent
	return inst
end

function Paper.frame(parent: Instance?, props: { [string]: any }): Frame
	props.BorderSizePixel = 0
	return Paper.make("Frame", props, parent)
end

-- Text label. Transparent background, serif ink text unless overridden.
function Paper.label(parent: Instance?, text: string, size: number, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = props or {}
	p.Text = text
	p.TextSize = size
	p.BackgroundTransparency = p.BackgroundTransparency or 1
	p.Font = p.Font or Paper.Fonts.Serif
	p.TextColor3 = p.TextColor3 or Paper.Colors.Ink
	if p.TextWrapped == nil then
		p.TextWrapped = true
	end
	return Paper.make("TextLabel", p, parent)
end

-- A ScreenGui in the local player's PlayerGui (client only).
function Paper.screen(name: string, layer: number?): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	return Paper.make("ScreenGui", { Name = name, IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = layer or Paper.Layers.Panel }, playerGui)
end

-- A sheet of parchment with a double ink border. Returns the sheet and the content frame inside the border.
function Paper.sheet(parent: Instance?, props: { [string]: any }): (Frame, Frame)
	props.BackgroundColor3 = props.BackgroundColor3 or Paper.Colors.Paper
	local sheet = Paper.frame(parent, props)
	Paper.make("UIStroke", { Color = Paper.Colors.Edge, Thickness = 3 }, sheet)
	local border = Paper.frame(sheet, { Name = "Border", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -14, 1, -14), BackgroundTransparency = 1 })
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 3 }, border)
	local content = Paper.frame(border, { Name = "Content", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 1, -12), BackgroundTransparency = 1 })
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 1 }, content)
	return sheet, content
end

-- A paper button with an ink outline.
function Paper.button(parent: Instance?, text: string, props: { [string]: any }?): TextButton
	local p: { [string]: any } = props or {}
	p.Text = text
	p.Font = p.Font or Paper.Fonts.Serif
	p.TextSize = p.TextSize or 17
	p.TextColor3 = p.TextColor3 or Paper.Colors.Ink
	p.BackgroundColor3 = p.BackgroundColor3 or Paper.Colors.Paper
	p.Size = p.Size or UDim2.fromOffset(150, 44)
	p.BorderSizePixel = 0
	p.AutoButtonColor = true
	local b = Paper.make("TextButton", p, parent)
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	return b
end

-- A dark name tab (white-on-ink), like the attacker tab on the dodge card.
function Paper.tab(parent: Instance?, text: string, props: { [string]: any }?): TextLabel
	local p: { [string]: any } = props or {}
	p.BackgroundTransparency = 0
	p.BackgroundColor3 = Paper.Colors.Ink
	p.TextColor3 = Paper.Colors.Paper
	p.Size = p.Size or UDim2.fromOffset(170, 22)
	return Paper.label(parent, string.upper(text), 15, p)
end

return Paper
