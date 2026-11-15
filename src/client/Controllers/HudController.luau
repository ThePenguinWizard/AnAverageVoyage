--!strict
-- HudController: a small parchment strip in the top-left corner showing HP, Resolve, Gold, Renown and the current
-- build. Everything is read from Player attributes (design/architecture.md) and updates when they change.
-- HP, MaxHP and Resolve belong to CombatService and may be missing at first: a dash is shown until they appear.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Paper = require(Shared:WaitForChild("UI"):WaitForChild("Paper"))
local Data = Shared:WaitForChild("Data")
local Weapons = require(Data:WaitForChild("Weapons"))
local Roles = require(Data:WaitForChild("Roles"))

local clientRoot = (script.Parent :: Instance).Parent :: Instance
local Layout = require(clientRoot:WaitForChild("Profile"):WaitForChild("Layout"))

local DASH = "—"
local RESOLVE_MAX = 200
local RESOLVE_BREAK = 100

local LABEL_WIDTH = 60
local BAR_WIDTH = 72
local VALUE_WIDTH = 70
local ROW_HEIGHT = 22

local player = Players.LocalPlayer

local HudController = {}

local function numberAttribute(name: string): number?
	local value = player:GetAttribute(name)
	if type(value) == "number" and value == value then
		return value
	end
	return nil
end

local function stringAttribute(name: string): string?
	local value = player:GetAttribute(name)
	if type(value) == "string" then
		return value
	end
	return nil
end

local function whole(value: number): string
	return tostring(math.floor(value + 0.5))
end

-- A row with a name on the left, a bar in the middle and a value on the right. Returns the fill and value label.
local function barRow(parent: Frame, y: number, name: string, color: Color3): (Frame, TextLabel, Frame)
	Paper.label(parent, name, 13, {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.fromOffset(LABEL_WIDTH, ROW_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})
	local track = Paper.frame(parent, {
		Name = name .. "Bar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(LABEL_WIDTH + 2, y + ROW_HEIGHT / 2),
		Size = UDim2.fromOffset(BAR_WIDTH, 10),
		BackgroundColor3 = Paper.Colors.PaperDark,
	})
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 1 }, track)
	local fill = Paper.frame(track, {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color,
	})
	local value = Paper.label(parent, DASH, 12, {
		Position = UDim2.fromOffset(LABEL_WIDTH + BAR_WIDTH + 6, y),
		Size = UDim2.fromOffset(VALUE_WIDTH, ROW_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
	})
	return fill, value, track
end

-- A small drawn marker (coin or diamond) followed by a text label. Returns the label.
local function moneyCell(parent: Frame, x: number, y: number, width: number, color: Color3, diamond: boolean): TextLabel
	local marker = Paper.frame(parent, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + 6, y + ROW_HEIGHT / 2),
		Size = UDim2.fromOffset(if diamond then 8 else 10, if diamond then 8 else 10),
		Rotation = if diamond then 45 else 0,
		BackgroundColor3 = color,
	})
	if not diamond then
		Paper.make("UICorner", { CornerRadius = UDim.new(1, 0) }, marker)
	end
	Paper.make("UIStroke", { Color = Paper.Colors.Ink, Thickness = 1 }, marker)
	return Paper.label(parent, DASH, 13, {
		Position = UDim2.fromOffset(x + 16, y),
		Size = UDim2.fromOffset(width - 16, ROW_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})
end

function HudController.start()
	local gui = Paper.screen("HudGui", Paper.Layers.Hud)

	local sheet, content = Paper.sheet(gui, {
		Name = "Strip",
		Position = UDim2.fromOffset(Layout.Margin, Layout.hudTop()),
		Size = UDim2.fromOffset(Layout.HudWidth, Layout.HudHeight),
	})
	local scale: UIScale = Paper.make("UIScale", {}, sheet)
	Layout.onViewport(function()
		scale.Scale = Layout.hudScale()
		sheet.Position = UDim2.fromOffset(Layout.Margin, Layout.hudTop())
	end)

	-- Everything sits in a body frame with a little margin inside the sheet's ink border.
	local body = Paper.frame(content, {
		Name = "Body",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -16, 1, -12),
		BackgroundTransparency = 1,
	})

	local hpFill, hpValue = barRow(body, 0, "HP", Paper.Colors.Red)
	local resolveFill, resolveValue, resolveTrack = barRow(body, 24, "Resolve", Paper.Colors.Teal)
	-- The breaking point at 100 Resolve (decision D4).
	Paper.frame(resolveTrack, {
		Name = "BreakMarker",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(RESOLVE_BREAK / RESOLVE_MAX, 0.5),
		Size = UDim2.new(0, 2, 1, 6),
		BackgroundColor3 = Paper.Colors.Ink,
		ZIndex = 2,
	})

	Paper.frame(body, {
		Name = "Rule",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Paper.Colors.Pale,
	})

	local goldLabel = moneyCell(body, 0, 54, 96, Paper.Colors.Gold, false)
	local renownLabel = moneyCell(body, 98, 54, 110, Paper.Colors.Teal, true)

	local buildLabel = Paper.label(body, DASH, 17, {
		Name = "Build",
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		Font = Paper.Fonts.Hand,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- Shown under the strip when this session's progress will not be saved.
	local unsavedNote = Paper.label(sheet, "Progress is not being saved this session", 15, {
		Name = "UnsavedNote",
		Position = UDim2.new(0, 4, 1, 6),
		Size = UDim2.new(1, 60, 0, 18),
		Font = Paper.Fonts.Hand,
		TextColor3 = Paper.Colors.Light,
		TextStrokeColor3 = Paper.Colors.Ink,
		TextStrokeTransparency = 0.4,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
		Visible = false,
	})

	local function refreshHealth()
		local hp = numberAttribute("HP")
		local maxHp = numberAttribute("MaxHP")
		if hp == nil and maxHp == nil then
			hpValue.Text = DASH
		else
			hpValue.Text = (if hp then whole(hp) else DASH) .. " / " .. (if maxHp then whole(maxHp) else DASH)
		end
		local fraction = 0
		if hp and maxHp and maxHp > 0 then
			fraction = math.clamp(hp / maxHp, 0, 1)
		end
		hpFill.Size = UDim2.fromScale(fraction, 1)
	end

	local function refreshResolve()
		local resolve = numberAttribute("Resolve")
		if resolve == nil then
			resolveValue.Text = DASH
			resolveFill.Size = UDim2.fromScale(0, 1)
			return
		end
		resolveValue.Text = whole(resolve)
		resolveFill.Size = UDim2.fromScale(math.clamp(resolve / RESOLVE_MAX, 0, 1), 1)
		resolveFill.BackgroundColor3 = if resolve >= RESOLVE_BREAK then Paper.Colors.Red else Paper.Colors.Teal
	end

	local function refreshMoney()
		local gold = numberAttribute("Gold")
		local renown = numberAttribute("Renown")
		goldLabel.Text = "Gold " .. (if gold then whole(gold) else DASH)
		renownLabel.Text = "Renown " .. (if renown then whole(renown) else DASH)
	end

	local function refreshBuild()
		local weaponId = stringAttribute("Weapon")
		local roleId = stringAttribute("CrewRole")
		if weaponId == nil and roleId == nil then
			buildLabel.Text = DASH
			return
		end
		local weaponName = DASH
		if weaponId then
			local weapon = Weapons.get(weaponId)
			weaponName = if weapon then weapon.Name else weaponId
		end
		local roleName = "No role"
		if roleId and roleId ~= "" then
			local role = Roles.get(roleId)
			roleName = if role then role.Name else roleId
		end
		buildLabel.Text = weaponName .. " · " .. roleName
	end

	local function refreshSaved()
		unsavedNote.Visible = player:GetAttribute("ProfileSaves") == false
	end

	local watched: { [string]: () -> () } = {
		HP = refreshHealth,
		MaxHP = refreshHealth,
		Resolve = refreshResolve,
		Gold = refreshMoney,
		Renown = refreshMoney,
		Weapon = refreshBuild,
		CrewRole = refreshBuild,
		ProfileSaves = refreshSaved,
	}
	for name, refresh in watched do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refreshHealth()
	refreshResolve()
	refreshMoney()
	refreshBuild()
	refreshSaved()
end

return HudController
