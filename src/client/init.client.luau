--!strict
-- Client entry point. Loads every ModuleScript in Controllers; each one is a self-contained feature.
-- A controller may return a table with `init()` (set up, no yielding) and/or `start()` (may yield).

local controllers = {}
for _, module in script:WaitForChild("Controllers"):GetChildren() do
	if module:IsA("ModuleScript") then
		task.spawn(function()
			local ok, result = pcall(require, module)
			if not ok then
				warn(("[Client] %s failed to load: %s"):format(module.Name, tostring(result)))
				return
			end
			if type(result) == "table" then
				if type(result.init) == "function" then
					result.init()
				end
				if type(result.start) == "function" then
					result.start()
				end
			end
			controllers[module.Name] = result
		end)
	end
end
