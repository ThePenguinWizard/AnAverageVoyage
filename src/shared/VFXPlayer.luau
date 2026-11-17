--[[
	AbilityVFX VFXPlayer
	Copied from the particles project (../particles/src/shared/AbilityVFX/Modules/VFXPlayer.luau), with one
	change for this game: there is no camera shake. The CameraShake / ShakeDuration / ShakeDelay template
	attributes and the Shake option are ignored.
	Plays templates from ReplicatedStorage.AbilityVFXTemplates (they live in the place file, not in Rojo).
	Play effects from a LocalScript: the server fires a RemoteEvent and every client plays it.

	USAGE
		local VFXPlayer = require(ReplicatedStorage.Shared.VFXPlayer)
		VFXPlayer.PlayByName("MeteorCrash", CFrame.new(pos))
		VFXPlayer.Play(templateModel, CFrame.new(pos), { Scale = 1, Parent = workspace })

	TEMPLATE FORMAT (every effect in AbilityVFX/Templates follows this)
		Model (PrimaryPart = "Core", an invisible anchored 1x1x1 part = effect origin, on the ground)
		  Model attributes: Rarity, DisplayName, Description, Duration (optional override), Radius (approx studs)

		ParticleEmitter (always Enabled = false in the template) attributes:
		  EmitCount    number  particles per burst
		  EmitDelay    number  seconds after Play before the first burst (default 0)
		  EmitDuration number  if > 0, the emitter is Enabled for this long instead of a burst
		  EmitRepeat   number  number of bursts (default 1)
		  EmitInterval number  seconds between repeated bursts (default 0.1)

		Light (PointLight / SpotLight / SurfaceLight) attributes:
		  Delay, AttackTime (default 0.04), Duration (decay time, default 0.5),
		  PeakBrightness (default = template Brightness), EasingStyle (decay, default "Quad")

		Beam attributes:
		  Delay, Duration, StartWidth, EndWidth, EasingStyle (default "Quint"), FadeTime (default 40% of Duration)

		Animated BasePart (attribute Animated = true; keep Transparency = 1 in the template):
		  Delay, TweenTime (default 0.5), StartSize, EndSize (Vector3),
		  StartTransparency (default 0), EndTransparency (default 1),
		  FadeDelay (default 0, relative to Delay), FadeTime (default TweenTime),
		  EasingStyle (default "Quint"), EasingDirection (default "Out"), FadeEasingStyle (default "Quad"),
		  Spin (Vector3, total degrees of rotation over TweenTime), EndOffset (Vector3, local studs moved over TweenTime),
		  StartColor / EndColor (Color3), StartScale / EndScale (Vector3, for a child SpecialMesh)
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local VFXPlayer = {}

local function attr(inst, name, default)
	local v = inst:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

local function enumOr(enumType, name, default)
	if type(name) ~= "string" then
		return default
	end
	local ok, v = pcall(function()
		return enumType[name]
	end)
	return (ok and v) or default
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function fadeSequence(keypoints, alpha)
	local out = table.create(#keypoints)
	for i, kp in ipairs(keypoints) do
		out[i] = NumberSequenceKeypoint.new(kp.Time, lerp(kp.Value, 1, alpha), kp.Envelope)
	end
	return NumberSequence.new(out)
end

-- Returns the computed lifetime (seconds) of a template, used for cleanup.
function VFXPlayer.GetDuration(template)
	local duration = 0
	for _, d in ipairs(template:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			local rep = math.max(1, math.floor(attr(d, "EmitRepeat", 1)))
			local last = attr(d, "EmitDelay", 0) + (rep - 1) * attr(d, "EmitInterval", 0.1) + attr(d, "EmitDuration", 0)
			duration = math.max(duration, last + d.Lifetime.Max / math.max(d.TimeScale, 0.01))
		elseif d:IsA("Light") then
			duration = math.max(duration, attr(d, "Delay", 0) + attr(d, "AttackTime", 0.04) + attr(d, "Duration", 0.5))
		elseif d:IsA("Beam") then
			duration = math.max(duration, attr(d, "Delay", 0) + attr(d, "Duration", 0.3))
		elseif d:IsA("BasePart") and d:GetAttribute("Animated") then
			local tweenTime = attr(d, "TweenTime", 0.5)
			local fadeEnd = attr(d, "FadeDelay", 0) + attr(d, "FadeTime", tweenTime)
			duration = math.max(duration, attr(d, "Delay", 0) + math.max(tweenTime, fadeEnd))
		end
	end
	return math.max(duration, attr(template, "Duration", 0))
end

--[[
	Plays a template at a CFrame (or Vector3). Returns a handle:
		handle.Model, handle.Time, handle:Freeze(), handle:Resume(), handle:Destroy()
	opts: Parent, Scale, KeepAlive (don't auto-destroy), TimeScale
]]
function VFXPlayer.Play(template, where, opts)
	opts = opts or {}
	assert(typeof(template) == "Instance" and template:IsA("Model"), "VFXPlayer.Play expects a Model template")

	local model = template:Clone()
	-- Pivot on Core even if PrimaryPart was never set, so rotated parts can't tilt the whole effect.
	if not model.PrimaryPart and model:FindFirstChild("Core") then
		model.PrimaryPart = model.Core
	end
	local k = opts.Scale or 1
	if k ~= 1 then
		model:ScaleTo(k)
	end
	-- ScaleTo scales emitters, parts and meshes; attribute-driven sizes need the same factor.
	local function scaled(inst, name, fallback)
		local v = inst:GetAttribute(name)
		if v == nil then
			return fallback
		end
		return v * k
	end
	local cf
	if typeof(where) == "CFrame" then
		cf = where
	elseif typeof(where) == "Vector3" then
		cf = CFrame.new(where)
	else
		cf = template:GetPivot()
	end
	model:PivotTo(cf)

	local events = {}
	local emitters, parts, lights, beams = {}, {}, {}, {}
	local duration = VFXPlayer.GetDuration(model)

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Enabled = false
			table.insert(emitters, { inst = d, timeScale = d.TimeScale })
			local delay = attr(d, "EmitDelay", 0)
			local rep = math.max(1, math.floor(attr(d, "EmitRepeat", 1)))
			local interval = attr(d, "EmitInterval", 0.1)
			local emitDuration = attr(d, "EmitDuration", 0)
			for i = 0, rep - 1 do
				local t = delay + i * interval
				if emitDuration > 0 then
					table.insert(events, { time = t, inst = d, enable = true })
					table.insert(events, { time = t + emitDuration, inst = d, enable = false })
				else
					table.insert(events, { time = t, inst = d, count = attr(d, "EmitCount", 10) })
				end
			end
		elseif d:IsA("Light") then
			table.insert(lights, {
				inst = d,
				delay = attr(d, "Delay", 0),
				attack = math.max(attr(d, "AttackTime", 0.04), 1e-3),
				decay = math.max(attr(d, "Duration", 0.5), 1e-3),
				peak = attr(d, "PeakBrightness", d.Brightness),
				style = enumOr(Enum.EasingStyle, attr(d, "EasingStyle", "Quad"), Enum.EasingStyle.Quad),
			})
			if k ~= 1 then
				d.Range = math.min(d.Range * k, 60)
			end
			d.Brightness = 0
			d.Enabled = true
		elseif d:IsA("Beam") then
			local dur = math.max(attr(d, "Duration", 0.3), 1e-3)
			table.insert(beams, {
				inst = d,
				delay = attr(d, "Delay", 0),
				dur = dur,
				w0 = scaled(d, "StartWidth", d.Width0),
				w1 = scaled(d, "EndWidth", d.Width1),
				fade = math.max(attr(d, "FadeTime", dur * 0.4), 1e-3),
				style = enumOr(Enum.EasingStyle, attr(d, "EasingStyle", "Quint"), Enum.EasingStyle.Quint),
				keypoints = d.Transparency.Keypoints,
			})
			d.Enabled = false
		elseif d:IsA("BasePart") and d:GetAttribute("Animated") then
			local tweenTime = math.max(attr(d, "TweenTime", 0.5), 1e-3)
			local mesh = d:FindFirstChildWhichIsA("SpecialMesh")
			local spin = attr(d, "Spin", nil)
			table.insert(parts, {
				inst = d,
				baseCF = d.CFrame,
				delay = attr(d, "Delay", 0),
				tweenTime = tweenTime,
				startSize = scaled(d, "StartSize", d.Size),
				endSize = scaled(d, "EndSize", d.Size),
				startT = attr(d, "StartTransparency", 0),
				endT = attr(d, "EndTransparency", 1),
				fadeDelay = attr(d, "FadeDelay", 0),
				fadeTime = math.max(attr(d, "FadeTime", tweenTime), 1e-3),
				style = enumOr(Enum.EasingStyle, attr(d, "EasingStyle", "Quint"), Enum.EasingStyle.Quint),
				dir = enumOr(Enum.EasingDirection, attr(d, "EasingDirection", "Out"), Enum.EasingDirection.Out),
				fadeStyle = enumOr(Enum.EasingStyle, attr(d, "FadeEasingStyle", "Quad"), Enum.EasingStyle.Quad),
				spin = spin and Vector3.new(math.rad(spin.X), math.rad(spin.Y), math.rad(spin.Z)) or nil,
				offset = scaled(d, "EndOffset", nil),
				startColor = attr(d, "StartColor", nil),
				endColor = attr(d, "EndColor", nil),
				mesh = mesh,
				startScale = mesh and scaled(d, "StartScale", nil),
				endScale = mesh and scaled(d, "EndScale", nil),
			})
			d.Transparency = 1
		end
	end
	table.sort(events, function(a, b)
		return a.time < b.time
	end)

	local handle = { Model = model, Time = 0, Frozen = false, Duration = duration, TimeScale = opts.TimeScale or 1 }
	local nextEvent = 1
	local conn

	local function step(dt)
		if handle.Frozen then
			return
		end
		handle.Time += dt * handle.TimeScale
		local t = handle.Time

		while nextEvent <= #events and events[nextEvent].time <= t do
			local ev = events[nextEvent]
			nextEvent += 1
			if ev.inst.Parent then
				if ev.enable ~= nil then
					ev.inst.Enabled = ev.enable
				elseif ev.count and ev.count > 0 then
					ev.inst:Emit(ev.count)
				end
			end
		end

		for _, p in ipairs(parts) do
			local lt = t - p.delay
			if lt >= 0 then
				local a = math.clamp(lt / p.tweenTime, 0, 1)
				local e = TweenService:GetValue(a, p.style, p.dir)
				local inst = p.inst
				if p.mesh and p.startScale and p.endScale then
					p.mesh.Scale = p.startScale:Lerp(p.endScale, e)
				else
					inst.Size = p.startSize:Lerp(p.endSize, e)
				end
				local fa = math.clamp((lt - p.fadeDelay) / p.fadeTime, 0, 1)
				inst.Transparency = lerp(p.startT, p.endT, TweenService:GetValue(fa, p.fadeStyle, Enum.EasingDirection.In))
				if p.startColor and p.endColor then
					inst.Color = p.startColor:Lerp(p.endColor, e)
				end
				if p.spin or p.offset then
					local cf = p.baseCF
					if p.offset then
						cf = cf * CFrame.new(p.offset * e)
					end
					if p.spin then
						cf = cf * CFrame.Angles(p.spin.X * e, p.spin.Y * e, p.spin.Z * e)
					end
					inst.CFrame = cf
				end
			end
		end

		for _, l in ipairs(lights) do
			local lt = t - l.delay
			if lt < 0 then
				l.inst.Brightness = 0
			elseif lt < l.attack then
				l.inst.Brightness = l.peak * (lt / l.attack)
			else
				local a = math.clamp((lt - l.attack) / l.decay, 0, 1)
				l.inst.Brightness = l.peak * (1 - TweenService:GetValue(a, l.style, Enum.EasingDirection.Out))
			end
		end

		for _, b in ipairs(beams) do
			local lt = t - b.delay
			local inst = b.inst
			if lt < 0 or lt > b.dur then
				inst.Enabled = false
			else
				inst.Enabled = true
				local e = TweenService:GetValue(math.clamp(lt / b.dur, 0, 1), b.style, Enum.EasingDirection.Out)
				local w = lerp(b.w0, b.w1, e)
				inst.Width0 = w
				inst.Width1 = w
				local fa = math.clamp((lt - (b.dur - b.fade)) / b.fade, 0, 1)
				inst.Transparency = fadeSequence(b.keypoints, fa)
			end
		end

		if not opts.KeepAlive and t >= duration + 0.1 then
			handle:Destroy()
		end
	end

	function handle:Freeze()
		self.Frozen = true
		for _, e in ipairs(emitters) do
			e.inst.TimeScale = 0
		end
	end

	function handle:Resume()
		self.Frozen = false
		for _, e in ipairs(emitters) do
			e.inst.TimeScale = e.timeScale
		end
	end

	function handle:Destroy()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		if model.Parent then
			model:Destroy()
		end
	end

	model.Parent = opts.Parent or workspace
	conn = RunService.Heartbeat:Connect(step)
	step(0)

	return handle
end

-- Templates are authored in the place (kitbashed from the place's VFX), not in Rojo:
-- ReplicatedStorage.AbilityVFXTemplates.<Rarity>.<Name>
local function templatesRoot()
	return game:GetService("ReplicatedStorage"):FindFirstChild("AbilityVFXTemplates")
end

-- Finds an effect template anywhere under ReplicatedStorage.AbilityVFXTemplates by name.
function VFXPlayer.Find(name)
	local templates = templatesRoot()
	if not templates then
		return nil
	end
	for _, d in ipairs(templates:GetDescendants()) do
		if d:IsA("Model") and d.Name == name then
			return d
		end
	end
	return nil
end

function VFXPlayer.PlayByName(name, where, opts)
	local template = VFXPlayer.Find(name)
	assert(template, "AbilityVFX template not found: " .. tostring(name))
	return VFXPlayer.Play(template, where, opts)
end

-- Returns { [rarityFolderName] = { templates... } }.
function VFXPlayer.List()
	local out = {}
	local templates = templatesRoot()
	if templates then
		for _, folder in ipairs(templates:GetChildren()) do
			out[folder.Name] = {}
			for _, m in ipairs(folder:GetChildren()) do
				if m:IsA("Model") then
					table.insert(out[folder.Name], m)
				end
			end
		end
	end
	return out
end

return VFXPlayer
