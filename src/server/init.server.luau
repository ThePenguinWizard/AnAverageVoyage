--!strict
-- Server entry point: sets up the world (sky and lighting for the current sea, the ocean), then loads every
-- ModuleScript in Services. A service may return a table with `init()` (no yielding; runs for all services first)
-- and/or `start()` (may yield; runs after every init).
-- Switch seas by setting the "SeaPreset" attribute on Workspace to "Sea1", "Sea2" or "Sea3".

local World = script:WaitForChild("World")
local Environment = require(World:WaitForChild("Environment"))
local Ocean = require(World:WaitForChild("Ocean"))

Environment.apply(workspace:GetAttribute("SeaPreset") :: string?)
task.spawn(Ocean.build)

workspace:GetAttributeChangedSignal("SeaPreset"):Connect(function()
	Environment.apply(workspace:GetAttribute("SeaPreset") :: string?, 4)
end)

local services = {}
for _, module in script:WaitForChild("Services"):GetChildren() do
	if module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			services[module.Name] = result
		elseif not ok then
			warn(("[Server] %s failed to load: %s"):format(module.Name, tostring(result)))
		end
	end
end
for name, service in services do
	if type(service.init) == "function" then
		local ok, err = pcall(service.init)
		if not ok then
			warn(("[Server] %s.init failed: %s"):format(name, tostring(err)))
		end
	end
end
for name, service in services do
	if type(service.start) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.start)
			if not ok then
				warn(("[Server] %s.start failed: %s"):format(name, tostring(err)))
			end
		end)
	end
end
