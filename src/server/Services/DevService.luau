--!strict
-- Studio-only test hooks, so play tests can jump straight to the part being tested.
-- Not created outside Studio. From the server side of a play test (command bar or MCP), for example:
--   game.ServerStorage.DevHook:Invoke("ForceNext", "Event")         -- every island you can reach next becomes an Event
--   game.ServerStorage.DevHook:Invoke("Call", "ProfileService", "addRenown", 100)
--   game.ServerStorage.DevHook:Invoke("Call", "CombatService", "heal", -30)
--   game.ServerStorage.DevHook:Invoke("State")
-- Commands act on the first player in the server. "Call" passes that player as the first argument.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DevService = {}

local function service(name: string): any
	local module = script.Parent:FindFirstChild(name)
	return if module and module:IsA("ModuleScript") then require(module) :: any else nil
end

local function onInvoke(command: string, a: any, b: any, ...: any): any
	local player = Players:GetPlayers()[1]
	if not player then
		return "no player"
	end
	if command == "ForceNext" then
		local voyage = service("VoyageService").getVoyage(player)
		if not voyage then
			return "no voyage"
		end
		local Chart = require(ReplicatedStorage.Shared.Voyage.Chart) :: any
		local sea = voyage.Map.Seas[voyage.Sea]
		local ids = Chart.reachable(sea, voyage.Node)
		for _, id in ids do
			sea.Nodes[id].Kind = a
		end
		return ids
	elseif command == "State" then
		local voyage = service("VoyageService").getVoyage(player)
		local out = { Location = player:GetAttribute("Location") }
		if voyage then
			out.Sea = voyage.Sea
			out.Node = voyage.Node
			out.Phase = voyage.Phase
			out.Pick = voyage.Pick
		end
		for k, v in player:GetAttributes() do
			out[k] = v
		end
		return out
	elseif command == "Call" then
		local svc = service(a)
		if not svc or type(svc[b]) ~= "function" then
			return "no such function"
		end
		return svc[b](player, ...)
	end
	return "unknown command"
end

function DevService.start()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "DevHook"
	hook.OnInvoke = onInvoke
	hook.Parent = ServerStorage
end

return DevService
