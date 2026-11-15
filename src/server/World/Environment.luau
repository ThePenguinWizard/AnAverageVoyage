--!strict
-- Applies a sea preset (sky, lighting, clouds, water) from ReplicatedStorage.Shared.World.SeaPresets.
-- In a running game the change is tweened; from the Studio command bar it applies instantly:
--   require(game.ServerScriptService.Server.World.Environment).apply("Sea2")

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local SeaPresets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("World"):WaitForChild("SeaPresets"))

local Environment = {}
Environment.DefaultPreset = "Sea1"

local function ensure(parent: Instance, className: string, name: string?): Instance
	local existing = parent:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local inst = Instance.new(className)
	if name then
		inst.Name = name
	end
	inst.Parent = parent
	return inst
end

local function setProps(inst: Instance, props: { [string]: any }, tweenTime: number?)
	if tweenTime and tweenTime > 0 then
		local tweened = {}
		for key, value in props do
			local kind = typeof(value)
			if kind == "number" or kind == "Color3" then
				tweened[key] = value
			else
				(inst :: any)[key] = value
			end
		end
		TweenService:Create(inst, TweenInfo.new(tweenTime, Enum.EasingStyle.Sine), tweened):Play()
	else
		for key, value in props do
			(inst :: any)[key] = value
		end
	end
end

-- Returns the name of the preset that was applied.
function Environment.apply(name: string?, tweenTime: number?): string
	local key = if name and SeaPresets[name] then name else Environment.DefaultPreset
	local preset = SeaPresets[key]
	local t = if RunService:IsRunning() then tweenTime else nil

	setProps(Lighting, preset.Lighting, t)
	setProps(ensure(Lighting, "Atmosphere"), preset.Atmosphere, t)
	setProps(ensure(Lighting, "ColorCorrectionEffect", "ColorCorrection"), preset.ColorCorrection, t)
	setProps(ensure(Lighting, "BloomEffect", "Bloom"), preset.Bloom, t)
	setProps(ensure(Lighting, "SunRaysEffect", "SunRays"), preset.SunRays, t)
	ensure(Lighting, "Sky")

	local terrain = workspace.Terrain
	setProps(terrain, preset.Water, t)
	setProps(ensure(terrain, "Clouds"), preset.Clouds, t)

	return key
end

return Environment
