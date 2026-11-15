--!strict
-- Ship camp controller: the client side of ShipService.
--   * Whenever the player's Location is "Ship", hands the camera back to the normal follow camera (combat leaves
--     it scripted).
--   * Shows the ship UI (see Client.Ship.ShipGui) when the server asks over "ShipRemote": the inventory panel for
--     the stash and crew chests, short station notes, and the ready indicator.
--   * Panels close with their Close button or gamepad B, when the player walks away from the station, and
--     when Location stops being "Ship".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ShipGui = require(script.Parent.Parent:WaitForChild("Ship"):WaitForChild("ShipGui"))

local ShipController = {}

local REMOTE_NAME = "ShipRemote"
local WALK_AWAY_SLACK = 8 -- studs past a station's prompt range before its panel closes itself

local player = Players.LocalPlayer

local remote: RemoteEvent? = nil
local started = false
local watchToken = 0

local isReady = false
local readyCount = 0
local crewTotal = 1

local function locationOf(): string?
	local value = player:GetAttribute("Location")
	if type(value) == "string" then
		return value
	end
	return nil
end

-- Panels may show at camp. A missing Location (VoyageService not running yet) counts as camp, like on the server.
local function atCamp(): boolean
	local location = locationOf()
	return location == nil or location == "Ship"
end

local function asVector3(value: unknown): Vector3?
	if typeof(value) == "Vector3" then
		return value :: any
	end
	return nil
end

local function asNumber(value: unknown): number?
	if type(value) == "number" and value == value then
		return value :: any
	end
	return nil
end

-- ------------------------------------------------------------------ camera

local function restoreCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function restoreCameraSoon()
	restoreCamera()
	-- Combat may let go of its scripted camera a moment after Location changes, so check again shortly.
	for _, seconds in { 0.25, 1 } do
		task.delay(seconds, function()
			if locationOf() == "Ship" then
				restoreCamera()
			end
		end)
	end
end

-- ------------------------------------------------------------------ panels

local function updateReady()
	ShipGui.setReady(locationOf() == "Ship", isReady, readyCount, crewTotal)
end

-- Closes the open panel once the player has walked away from the station it belongs to.
local function watchStation(position: Vector3?, range: number?)
	watchToken += 1
	if not position then
		return
	end
	local token = watchToken
	local centre: Vector3 = position
	local limit = (range or 8) + WALK_AWAY_SLACK
	task.spawn(function()
		while token == watchToken and ShipGui.current() ~= nil do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position - centre).Magnitude > limit then
				ShipGui.close()
				return
			end
			task.wait(0.3)
		end
	end)
end

local function onRemote(action: unknown, a: unknown, b: unknown, c: unknown, d: unknown)
	if action == "Note" then
		-- (title, body, stationPosition?, stationRange?)
		if atCamp() and type(a) == "string" and type(b) == "string" then
			ShipGui.showNote(a, b)
			watchStation(asVector3(c), asNumber(d))
		end
	elseif action == "OpenInventory" then
		-- (title, stationPosition?, stationRange?)
		if atCamp() then
			ShipGui.openInventory(if type(a) == "string" then a else "Chest")
			watchStation(asVector3(b), asNumber(c))
		end
	elseif action == "ItemResult" then
		-- (ok, message)
		if type(b) == "string" then
			ShipGui.setStatus(b, a == true)
		end
	elseif action == "Ready" then
		-- (ready, readyCount, crewTotal)
		isReady = a == true
		readyCount = asNumber(b) or 0
		crewTotal = asNumber(c) or 1
		updateReady()
	end
end

local function onLocationChanged()
	if locationOf() == "Ship" then
		restoreCameraSoon()
	end
	if not atCamp() then
		ShipGui.close()
	end
	updateReady()
end

local function onCharacterAdded(character: Model)
	if locationOf() ~= "Ship" then
		return
	end
	character:WaitForChild("Humanoid", 10)
	if player.Character == character and locationOf() == "Ship" then
		restoreCamera()
	end
end

function ShipController.start()
	if started then
		return
	end
	started = true

	ShipGui.build({
		UseItem = function(itemId: string)
			if remote and atCamp() then
				remote:FireServer("UseItem", itemId)
			end
		end,
		Closed = function(panel: string)
			watchToken += 1 -- stops the walk-away watcher
			if panel == "Inventory" and remote then
				remote:FireServer("ClosePanel")
			end
		end,
	})

	player.AttributeChanged:Connect(function(name: string)
		if name == "Location" then
			onLocationChanged()
		elseif name == "InventoryJson" or name == "HP" or name == "MaxHP" or name == "Resolve" then
			ShipGui.refreshInventory()
		end
	end)
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Gamepad B closes the open panel (as well as its Close button). Escape is left alone: Roblox always opens its own
	-- menu on Escape, so binding it here would close the panel and open the menu at the same time.
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.ButtonB then
			ShipGui.close()
		end
	end)

	onLocationChanged()

	local found = ReplicatedStorage:WaitForChild(REMOTE_NAME, 60)
	if found and found:IsA("RemoteEvent") then
		remote = found
		found.OnClientEvent:Connect(onRemote)
	else
		warn("[ShipController] ShipRemote was not found; ship stations will not open their panels")
	end
end

return ShipController
