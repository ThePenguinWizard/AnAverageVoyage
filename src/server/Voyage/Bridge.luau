--!strict
-- Safe calls into the other services (CombatService, ShipService, ProfileService).
-- They are required lazily and every call is wrapped in pcall, so the voyage keeps running while another service
-- is missing, half-built or throwing (design/architecture.md, rules).

local Bridge = {}

local warned: { [string]: boolean } = {}

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn("[VoyageService] " .. message)
	end
end

-- The service's table, or nil if it does not exist or failed to load.
function Bridge.get(serviceName: string): any?
	local server = (script.Parent :: Instance).Parent
	local services = if server then server:FindFirstChild("Services") else nil
	local module = if services then services:FindFirstChild(serviceName) else nil
	if not module or not module:IsA("ModuleScript") then
		warnOnce(serviceName, serviceName .. " is missing; carrying on without it")
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok or type(result) ~= "table" then
		warnOnce(serviceName, serviceName .. " failed to load; carrying on without it")
		return nil
	end
	return result
end

-- True if the service has a function with this name.
function Bridge.has(serviceName: string, functionName: string): boolean
	local service = Bridge.get(serviceName)
	return service ~= nil and type(service[functionName]) == "function"
end

-- Calls service.functionName(...). Returns whether the call ran without error, and its first result.
function Bridge.call(serviceName: string, functionName: string, ...: any): (boolean, any)
	local service = Bridge.get(serviceName)
	if not service then
		return false, nil
	end
	local fn = service[functionName]
	if type(fn) ~= "function" then
		warnOnce(serviceName .. "." .. functionName, ("%s.%s is missing; skipping it"):format(serviceName, functionName))
		return false, nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		warn(("[VoyageService] %s.%s failed: %s"):format(serviceName, functionName, tostring(result)))
		return false, nil
	end
	return true, result
end

return Bridge
