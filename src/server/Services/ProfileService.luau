--!strict
-- ProfileService: the saved profile (Renown, ShipTier, Weapon, CrewRole) and the voyage-only state (Gold, Inventory).
-- API and attribute contract: design/architecture.md. Every function is safe to call before a profile has loaded:
-- it returns nil/false or does nothing.
--
-- Saved with DataStoreService: store "PlayerProfiles", key "Player_<UserId>", value
--   { Version = 1, Renown = number, ShipTier = number, Weapon = string, CrewRole = string, SavedAt = number }
-- A profile that failed to load is played from defaults and is never saved, so a bad read cannot wipe real data.
--
-- Extra Player attributes this service sets besides the six in architecture.md:
--   ProfileLoaded (boolean)  true once the profile exists on the server
--   ProfileSaves  (boolean)  false when this session's progress will not be saved (the HUD shows a note)
--
-- Client requests on ReplicatedStorage.ProfileRemote:
--   FireServer("SetBuild", weaponId, roleId)   roleId "" means no role
--   FireServer("BuyShipTier")
-- The server answers with FireClient(action, ok: boolean, message: string).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data")
local Items = require(Data:WaitForChild("Items"))
local Weapons = require(Data:WaitForChild("Weapons"))
local Roles = require(Data:WaitForChild("Roles"))
local Ships = require(Data:WaitForChild("Ships"))

local serverRoot = (script.Parent :: Instance).Parent :: Instance
local Store = require(serverRoot:WaitForChild("Profile"):WaitForChild("Store"))

export type Profile = {
	Renown: number,
	ShipTier: number,
	Weapon: string,
	CrewRole: string,
	Gold: number,
	Inventory: { [string]: number },
}

type Session = {
	UserId: number,
	Profile: Profile,
	CanSave: boolean, -- false if the load failed or DataStores are unavailable
	Dirty: boolean, -- saved fields changed since the last save
	Saving: boolean,
}

local STORE_VERSION = 1
local REMOTE_NAME = "ProfileRemote"
local AUTOSAVE_SECONDS = 180
local CLOSE_TIMEOUT = 20 -- seconds BindToClose may wait for saves
local REQUEST_COOLDOWN = 0.25 -- seconds between remote requests from one player
local MAX_CURRENCY = 1e9
local MAX_STACK = 999

local ProfileService = {}

local sessions: { [Player]: Session } = {}
local loading: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local remote: RemoteEvent? = nil
local savesInFlight = 0

-- Helpers ---------------------------------------------------------------------------------------------------------

-- A whole number from an untrusted value, or nil if it is not a usable number.
local function toInteger(value: any): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.round(value)
end

local function startingInventory(): { [string]: number }
	local inventory: { [string]: number } = {}
	for itemId, count in Items.StartingKit do
		if Items.get(itemId) and count > 0 then
			inventory[itemId] = count
		end
	end
	return inventory
end

local function newProfile(): Profile
	return {
		Renown = 0,
		ShipTier = 1,
		Weapon = Weapons.Default,
		CrewRole = "",
		Gold = Items.StartingGold,
		Inventory = startingInventory(),
	}
end

local function isAvailableWeapon(weaponId: any): boolean
	if type(weaponId) ~= "string" then
		return false
	end
	local def = Weapons.get(weaponId)
	return def ~= nil and def.Available == true
end

local function isRole(roleId: any): boolean
	return type(roleId) == "string" and (roleId == "" or Roles.get(roleId) ~= nil)
end

-- The other player in this server who already holds a role (one of each role per crew, D7), if any.
local function roleHolder(roleId: string, except: Player): Player?
	if roleId == "" then
		return nil
	end
	for other, session in sessions do
		if other ~= except and session.Profile.CrewRole == roleId then
			return other
		end
	end
	return nil
end

local function encodeInventory(inventory: { [string]: number }): string
	if next(inventory) == nil then
		return "{}" -- JSONEncode would write an empty table as "[]"
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode(inventory)
	end)
	return if ok and type(json) == "string" then json else "{}"
end

-- Copies the profile onto the Player's attributes so clients and other services can read it.
local function mirror(player: Player, session: Session)
	local profile = session.Profile
	player:SetAttribute("Weapon", profile.Weapon)
	player:SetAttribute("CrewRole", profile.CrewRole)
	player:SetAttribute("Renown", profile.Renown)
	player:SetAttribute("ShipTier", profile.ShipTier)
	player:SetAttribute("Gold", profile.Gold)
	player:SetAttribute("InventoryJson", encodeInventory(profile.Inventory))
	player:SetAttribute("ProfileSaves", session.CanSave)
	player:SetAttribute("ProfileLoaded", true)
end

-- Call after any change. `saved` marks the profile as needing a save (pass false for voyage-only changes).
local function changed(player: Player, session: Session, saved: boolean)
	if saved then
		session.Dirty = true
	end
	if player.Parent ~= nil then
		mirror(player, session)
	end
end

-- Loading and saving ------------------------------------------------------------------------------------------------

-- Turns a stored value into saved fields on `profile`. Returns false if the value cannot be trusted (unknown shape
-- or written by a newer version of the game), in which case the profile must not be saved over it.
local function applyStored(profile: Profile, raw: any): boolean
	if raw == nil then
		return true -- a new player
	end
	if type(raw) ~= "table" then
		return false
	end
	local version = raw.Version
	if type(version) ~= "number" or version > STORE_VERSION then
		return false
	end
	-- Migrations from older versions go here: if version < 2 then ... end

	local renown = toInteger(raw.Renown)
	if renown then
		profile.Renown = math.clamp(renown, 0, MAX_CURRENCY)
	end
	local tier = toInteger(raw.ShipTier)
	if tier then
		profile.ShipTier = math.clamp(tier, 1, Ships.MaxTier)
	end
	if isAvailableWeapon(raw.Weapon) then
		profile.Weapon = raw.Weapon
	end
	if isRole(raw.CrewRole) then
		profile.CrewRole = raw.CrewRole
	end
	return true
end

local function writeSession(session: Session): boolean
	while session.Saving do
		task.wait(0.1)
	end
	if not session.CanSave or not session.Dirty then
		return true
	end
	if not Store.isPersistent() then
		return false
	end
	local profile = session.Profile
	local payload = {
		Version = STORE_VERSION,
		Renown = profile.Renown,
		ShipTier = profile.ShipTier,
		Weapon = profile.Weapon,
		CrewRole = profile.CrewRole,
		SavedAt = os.time(),
	}
	session.Saving = true
	session.Dirty = false -- cleared before the write yields, so a change made meanwhile marks it dirty again
	local ok, saved = pcall(Store.write, session.UserId, payload)
	session.Saving = false
	if not (ok and saved) then
		session.Dirty = true
		return false
	end
	return true
end

-- Saves a session if it needs it. Counted in savesInFlight from start to finish so shutdown can wait for it.
local function saveSession(session: Session): boolean
	savesInFlight += 1
	local ok, saved = pcall(writeSession, session)
	savesInFlight -= 1
	return ok and saved == true
end

local function onPlayerAdded(player: Player)
	if sessions[player] or loading[player] then
		return
	end
	loading[player] = true
	local readOk, raw = Store.read(player.UserId)
	loading[player] = nil
	if player.Parent == nil then
		return -- left while loading
	end

	local profile = newProfile()
	local trusted = readOk and applyStored(profile, raw)
	if not trusted then
		warn(("[ProfileService] %s's profile could not be loaded; playing from defaults without saving"):format(player.Name))
	end
	-- Someone already aboard holds this role: sail without one until the player picks again.
	if roleHolder(profile.CrewRole, player) then
		profile.CrewRole = ""
	end

	local session: Session = {
		UserId = player.UserId,
		Profile = profile,
		CanSave = trusted and Store.isPersistent(),
		Dirty = false,
		Saving = false,
	}
	sessions[player] = session
	mirror(player, session)
end

local function onPlayerRemoving(player: Player)
	lastRequest[player] = nil
	loading[player] = nil
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	saveSession(session)
end

-- Public API (design/architecture.md) -------------------------------------------------------------------------------

-- A copy of the player's profile, or nil if it has not loaded. Change it through the functions below.
function ProfileService.get(player: Player): Profile?
	local session = sessions[player]
	if not session then
		return nil
	end
	local copy = table.clone(session.Profile)
	copy.Inventory = table.clone(session.Profile.Inventory)
	return copy
end

local function trySetBuild(player: Player, weaponId: any, roleId: any): (boolean, string)
	local session = sessions[player]
	if not session then
		return false, "Your papers are still being fetched."
	end
	if not isAvailableWeapon(weaponId) then
		return false, "That weapon style cannot be chosen yet."
	end
	if not isRole(roleId) then
		return false, "That is not a crew role."
	end
	local profile = session.Profile
	if roleId ~= profile.CrewRole then
		local holder = roleHolder(roleId, player)
		if holder then
			return false, ("%s is already the crew's %s."):format(holder.DisplayName, roleId)
		end
	end
	if profile.Weapon ~= weaponId or profile.CrewRole ~= roleId then
		profile.Weapon = weaponId
		profile.CrewRole = roleId
		changed(player, session, true)
	end
	return true, "Papers signed."
end

function ProfileService.setBuild(player: Player, weaponId: string, roleId: string): boolean
	local ok = trySetBuild(player, weaponId, roleId)
	return ok
end

function ProfileService.addRenown(player: Player, amount: number)
	local session = sessions[player]
	local delta = toInteger(amount)
	if not session or not delta or delta == 0 then
		return
	end
	local profile = session.Profile
	profile.Renown = math.clamp(profile.Renown + delta, 0, MAX_CURRENCY)
	changed(player, session, true)
end

function ProfileService.addGold(player: Player, amount: number)
	local session = sessions[player]
	local delta = toInteger(amount)
	if not session or not delta or delta == 0 then
		return
	end
	local profile = session.Profile
	profile.Gold = math.clamp(profile.Gold + delta, 0, MAX_CURRENCY)
	changed(player, session, false)
end

function ProfileService.giveItem(player: Player, itemId: string, count: number)
	local session = sessions[player]
	local amount = toInteger(count)
	if not session or not amount or amount < 1 then
		return
	end
	if type(itemId) ~= "string" or not Items.get(itemId) then
		warn(("[ProfileService] giveItem: unknown item %s"):format(tostring(itemId)))
		return
	end
	local inventory = session.Profile.Inventory
	inventory[itemId] = math.min((inventory[itemId] or 0) + amount, MAX_STACK)
	changed(player, session, false)
end

function ProfileService.takeItem(player: Player, itemId: string, count: number): boolean
	local session = sessions[player]
	local amount = toInteger(count)
	if not session or not amount or amount < 1 or type(itemId) ~= "string" then
		return false
	end
	local inventory = session.Profile.Inventory
	local have = inventory[itemId] or 0
	if have < amount then
		return false
	end
	inventory[itemId] = if have > amount then have - amount else nil
	changed(player, session, false)
	return true
end

function ProfileService.resetVoyage(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.Profile.Gold = Items.StartingGold
	session.Profile.Inventory = startingInventory()
	changed(player, session, false)
end

-- Ship tier upgrade (an addition to architecture.md): buys the next tier with Renown.
local function tryBuyShipTier(player: Player): (boolean, string)
	local session = sessions[player]
	if not session then
		return false, "Your papers are still being fetched."
	end
	local profile = session.Profile
	local nextTier = profile.ShipTier + 1
	local def = Ships.Tiers[nextTier]
	if nextTier > Ships.MaxTier or not def then
		return false, "Your ship is already the largest there is."
	end
	if profile.Renown < def.Cost then
		return false, ("The %s costs %d Renown; you have %d."):format(def.Name, def.Cost, profile.Renown)
	end
	profile.Renown -= def.Cost
	profile.ShipTier = nextTier
	changed(player, session, true)
	task.spawn(saveSession, session) -- a permanent purchase: save it straight away
	-- Step aboard the new ship right away if the player is in camp (otherwise it happens after the next island).
	if player:GetAttribute("Location") == "Ship" then
		task.spawn(function()
			local module = script.Parent:FindFirstChild("ShipService")
			local ok, ShipService = pcall(require, module :: any)
			if ok and type(ShipService) == "table" and type(ShipService.placeOnShip) == "function" then
				pcall(ShipService.placeOnShip, player)
			end
		end)
	end
	return true, ("The %s is yours."):format(def.Name)
end

function ProfileService.buyShipTier(player: Player): boolean
	local ok = tryBuyShipTier(player)
	return ok
end

-- Remote ------------------------------------------------------------------------------------------------------------

-- Builds and ships are only changed in camp: Location is "Ship", or not set yet.
local function isAboard(player: Player): boolean
	local location = player:GetAttribute("Location")
	return location == nil or location == "Ship"
end

local function onRequest(player: Player, action: any, a: any, b: any)
	local event = remote
	if not event or type(action) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now

	if action == "SetBuild" then
		if type(a) ~= "string" or type(b) ~= "string" or #a > 40 or #b > 40 then
			return
		end
		if not isAboard(player) then
			event:FireClient(player, action, false, "You can only change your papers aboard the ship.")
			return
		end
		local ok, message = trySetBuild(player, a, b)
		event:FireClient(player, action, ok, message)
	elseif action == "BuyShipTier" then
		if not isAboard(player) then
			event:FireClient(player, action, false, "You can only buy a ship while aboard.")
			return
		end
		local ok, message = tryBuyShipTier(player)
		event:FireClient(player, action, ok, message)
	end
end

-- Lifecycle ---------------------------------------------------------------------------------------------------------

function ProfileService.init()
	local existing = ReplicatedStorage:FindFirstChild(REMOTE_NAME)
	local event: RemoteEvent
	if existing and existing:IsA("RemoteEvent") then
		event = existing
	else
		event = Instance.new("RemoteEvent")
		event.Name = REMOTE_NAME
		event.Parent = ReplicatedStorage
	end
	remote = event
	event.OnServerEvent:Connect(onRequest)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	game:BindToClose(function()
		for _, session in sessions do
			task.spawn(saveSession, session)
		end
		-- Also covers saves started by PlayerRemoving, which fires for everyone as the server closes.
		local deadline = os.clock() + CLOSE_TIMEOUT
		while (savesInFlight > 0 or Store.activeWrites() > 0) and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function ProfileService.start()
	while true do
		task.wait(AUTOSAVE_SECONDS)
		for player, session in table.clone(sessions) do
			if sessions[player] == session then
				saveSession(session)
			end
		end
	end
end

return ProfileService
