--!strict
-- Builds the blocky enemy pirates for a battle. They are built on the client, so each player only sees the enemies
-- of their own encounter. Also holds the small effects played on them: lunge, flash, pop-up, topple. (Their HP
-- bars are Client.Combat.Plates.)

local EnemyModels = {}

local SKIN = Color3.fromRGB(234, 184, 146)
local WHITE = Color3.fromRGB(236, 236, 240)
local NAVY = Color3.fromRGB(40, 60, 120)
local GOLD = Color3.fromRGB(214, 170, 62)
local WOOD = Color3.fromRGB(96, 60, 36)
local STEEL = Color3.fromRGB(196, 200, 208)
local IRON = Color3.fromRGB(62, 62, 68)

type Look = {
	Shirt: Color3,
	Pants: Color3,
	Hat: string, -- "Bandana", "Cap", "Tricorn" or "None"
	HatColor: Color3,
	Skin: Color3?,
	Coat: Color3?,
	Epaulettes: boolean?,
	Scale: number?,
}

-- Keyed by enemy id (Moves.Enemies).
local LOOKS: { [string]: Look } = {
	Deckhand = { Shirt = Color3.fromRGB(150, 60, 50), Pants = Color3.fromRGB(70, 60, 54), Hat = "Bandana", HatColor = Color3.fromRGB(190, 40, 40) },
	Swordsman = { Shirt = WHITE, Pants = NAVY, Hat = "Cap", HatColor = Color3.fromRGB(240, 240, 244) },
	Gunner = { Shirt = WHITE, Pants = NAVY, Hat = "Cap", HatColor = NAVY },
	Bomber = { Shirt = Color3.fromRGB(196, 120, 50), Pants = Color3.fromRGB(60, 52, 48), Hat = "Bandana", HatColor = Color3.fromRGB(40, 40, 44), Scale = 0.9 },
	Brute = { Shirt = Color3.fromRGB(110, 90, 70), Pants = Color3.fromRGB(50, 44, 40), Hat = "None", HatColor = WOOD, Scale = 1.3 },
	Harpooner = { Shirt = Color3.fromRGB(40, 120, 120), Pants = Color3.fromRGB(70, 60, 54), Hat = "Bandana", HatColor = Color3.fromRGB(230, 220, 190) },
	Duelist = { Shirt = WHITE, Pants = NAVY, Hat = "Tricorn", HatColor = NAVY, Coat = NAVY, Scale = 1.15 },
	Cannoneer = { Shirt = Color3.fromRGB(60, 70, 110), Pants = NAVY, Hat = "Cap", HatColor = NAVY, Epaulettes = true, Scale = 1.25 },
	CaptainRedtide = {
		Shirt = Color3.fromRGB(240, 232, 214),
		Pants = Color3.fromRGB(40, 34, 34),
		Hat = "Tricorn",
		HatColor = Color3.fromRGB(34, 28, 28),
		Coat = Color3.fromRGB(150, 30, 34),
		Scale = 1.5,
	},
	CommodoreVane = { Shirt = WHITE, Pants = WHITE, Hat = "Tricorn", HatColor = NAVY, Coat = NAVY, Epaulettes = true, Scale = 1.55 },
	StormAdmiral = {
		Shirt = Color3.fromRGB(60, 80, 84),
		Pants = Color3.fromRGB(34, 44, 48),
		Hat = "Tricorn",
		HatColor = Color3.fromRGB(24, 30, 34),
		Skin = Color3.fromRGB(150, 176, 170),
		Coat = Color3.fromRGB(30, 60, 64),
		Epaulettes = true,
		Scale = 1.75,
	},
}

-- `info` is an entry of Moves.Enemies. The model is built facing -Z with its feet at the origin, then moved to `feet`.
function EnemyModels.build(id: string, info: any, feet: CFrame, parent: Instance): Model
	local look = LOOKS[id] or LOOKS.Deckhand
	local k = look.Scale or 1
	local skin = look.Skin or SKIN

	local m = Instance.new("Model")
	m.Name = id
	m:SetAttribute("EnemyId", id)
	m:SetAttribute("Scale", k)

	-- Sizes and offsets are written for a 5-stud-tall figure and multiplied by the look's scale.
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * k
		p.CFrame = cf.Rotation + cf.Position * k
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = true -- so a click or tap on the enemy can pick it as the target
		p.CanTouch = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = m
		return p
	end

	local torso = part("Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), look.Shirt)
	part("LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), look.Pants)
	part("RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), look.Pants)
	part("LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), look.Coat or look.Shirt)
	-- the weapon arm is raised forward
	part("RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3.4, -0.6) * CFrame.Angles(math.rad(70), 0, 0), look.Coat or look.Shirt)
	local head = part("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 4.65, 0), skin)
	part("Belt", Vector3.new(2.05, 0.35, 1.05), CFrame.new(0, 2.15, 0), Color3.fromRGB(60, 44, 34))
	for _, x in { -0.3, 0.3 } do
		part("Eye", Vector3.new(0.18, 0.18, 0.05), CFrame.new(x, 4.75, -0.66), Color3.fromRGB(30, 30, 34))
	end

	if look.Hat == "Cap" then
		part("Cap", Vector3.new(1.45, 0.4, 1.45), CFrame.new(0, 5.45, 0), look.HatColor)
		part("Brim", Vector3.new(1.3, 0.12, 0.6), CFrame.new(0, 5.3, -0.9), Color3.fromRGB(30, 40, 80))
	elseif look.Hat == "Tricorn" then
		part("HatBrim", Vector3.new(2.1, 0.16, 2.1), CFrame.new(0, 5.36, 0) * CFrame.Angles(0, math.rad(45), 0), look.HatColor)
		part("HatCrown", Vector3.new(1.25, 0.55, 1.25), CFrame.new(0, 5.68, 0), look.HatColor)
		part("HatTrim", Vector3.new(1.3, 0.12, 1.3), CFrame.new(0, 5.46, 0), GOLD)
	elseif look.Hat == "Bandana" then
		part("Bandana", Vector3.new(1.4, 0.45, 1.4), CFrame.new(0, 5.2, 0), look.HatColor)
		part("BandanaKnot", Vector3.new(0.4, 0.4, 0.5), CFrame.new(0.5, 5.1, 0.85), look.HatColor)
	end
	if look.Coat then
		part("CoatBack", Vector3.new(2.2, 3, 0.25), CFrame.new(0, 2.5, 0.6), look.Coat)
		part("CoatLeft", Vector3.new(0.25, 3, 1), CFrame.new(-1.05, 2.5, 0.1), look.Coat)
		part("CoatRight", Vector3.new(0.25, 3, 1), CFrame.new(1.05, 2.5, 0.1), look.Coat)
	end
	if look.Epaulettes then
		part("EpauletteLeft", Vector3.new(1.1, 0.2, 1.1), CFrame.new(-1.5, 4.1, 0), GOLD)
		part("EpauletteRight", Vector3.new(1.1, 0.2, 1.1), CFrame.new(1.5, 4.1, -0.1), GOLD)
	end

	local hand = CFrame.new(1.5, 3.75, -1.6)
	local weapon = info.Weapon
	if weapon == "Flintlock" then
		part("PistolGrip", Vector3.new(0.3, 0.7, 0.35), hand * CFrame.new(0, -0.2, 0.1), WOOD, Enum.Material.Wood)
		part("PistolBarrel", Vector3.new(0.28, 0.28, 1.5), hand * CFrame.new(0, 0.2, -0.6), IRON, Enum.Material.Metal)
	elseif weapon == "Bomb" then
		local bomb = part("Bomb", Vector3.new(1.1, 1.1, 1.1), hand * CFrame.new(0, 0.3, -0.2), Color3.fromRGB(34, 34, 38))
		bomb.Shape = Enum.PartType.Ball
		part("Fuse", Vector3.new(0.12, 0.5, 0.12), hand * CFrame.new(0, 1, -0.2), Color3.fromRGB(214, 190, 120))
	elseif weapon == "Club" then
		part("ClubGrip", Vector3.new(0.3, 0.3, 1), hand, WOOD, Enum.Material.Wood)
		part("ClubHead", Vector3.new(0.7, 0.7, 2), hand * CFrame.new(0, 0, -1.4), Color3.fromRGB(80, 50, 30), Enum.Material.Wood)
	elseif weapon == "Harpoon" then
		part("Shaft", Vector3.new(0.2, 0.2, 5), hand * CFrame.new(0, 0, -1), WOOD, Enum.Material.Wood)
		part("Tip", Vector3.new(0.4, 0.12, 0.9), hand * CFrame.new(0, 0, -3.8), STEEL, Enum.Material.Metal)
	elseif weapon == "Cannon" then
		part("CannonBarrel", Vector3.new(0.9, 0.9, 2.6), hand * CFrame.new(-0.2, -0.2, -0.7), IRON, Enum.Material.Metal)
		part("CannonBand", Vector3.new(1, 1, 0.3), hand * CFrame.new(-0.2, -0.2, -1.8), GOLD, Enum.Material.Metal)
	elseif weapon == "Rapier" then
		part("Hilt", Vector3.new(0.25, 0.25, 0.6), hand, WOOD, Enum.Material.Wood)
		part("Guard", Vector3.new(0.7, 0.7, 0.12), hand * CFrame.new(0, 0, -0.35), GOLD, Enum.Material.Metal)
		part("Blade", Vector3.new(0.1, 0.1, 3.4), hand * CFrame.new(0, 0, -2.1), STEEL, Enum.Material.Metal)
	else
		part("Hilt", Vector3.new(0.25, 0.25, 0.7), hand, WOOD, Enum.Material.Wood)
		part("Guard", Vector3.new(0.9, 0.2, 0.2), hand * CFrame.new(0, 0, -0.4), GOLD, Enum.Material.Metal)
		part("Blade", Vector3.new(0.12, 0.34, 2.8), hand * CFrame.new(0, 0.05, -1.9), STEEL, Enum.Material.Metal)
	end

	m.PrimaryPart = torso

	m:PivotTo(feet * CFrame.new(0, 3 * k, 0))
	m:SetAttribute("Down", false)
	m.Parent = parent
	return m
end

-- A short step toward the crew and back, played when the enemy attacks.
function EnemyModels.lunge(model: Model)
	if model.Parent == nil or model:GetAttribute("Down") == true then
		return
	end
	task.spawn(function()
		local home = model:GetPivot()
		local forward = home.LookVector
		local steps = { 0.3, 0.6, 0.9, 1.2, 1.4, 1.2, 0.8, 0.4, 0 }
		for _, distance in steps do
			if model.Parent == nil or model:GetAttribute("Down") == true then
				return
			end
			model:PivotTo(home + forward * distance)
			task.wait(0.03)
		end
	end)
end

-- A quick white flash, played when the enemy is hit.
function EnemyModels.flash(model: Model)
	if model.Parent == nil then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.2
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	task.delay(0.18, function()
		highlight:Destroy()
	end)
end

-- Text that rises from the enemy's head: a damage number or "MISS".
function EnemyModels.popup(model: Model, text: string, color: Color3)
	local head = model:FindFirstChild("Head")
	if model.Parent == nil or not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Popup"
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Adornee = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Merriweather
	label.TextSize = 30
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	gui.Parent = model
	task.spawn(function()
		for i = 1, 20 do
			if gui.Parent == nil then
				return
			end
			gui.StudsOffset = Vector3.new(0, 4 + i * 0.08, 0)
			task.wait(0.04)
		end
		gui:Destroy()
	end)
end

-- Tips the enemy over and fades it when it is defeated.
function EnemyModels.topple(model: Model)
	if model.Parent == nil or model:GetAttribute("Down") == true then
		return
	end
	model:SetAttribute("Down", true)
	local scale = model:GetAttribute("Scale")
	local k = if type(scale) == "number" then scale else 1
	local home = model:GetPivot()
	model:PivotTo(home * CFrame.new(0, -2 * k, 1.5 * k) * CFrame.Angles(math.rad(80), 0, 0))
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Transparency = 0.6
		end
	end
end

return EnemyModels
