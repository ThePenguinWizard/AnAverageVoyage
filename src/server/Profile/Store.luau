--!strict
-- Thin wrapper around DataStoreService for ProfileService: every call is in a pcall with a few retries.
-- If DataStores cannot be used at all (for example Studio without API access, or an unpublished place), it switches
-- to "memory only" for the rest of the session and warns once; ProfileService then keeps profiles in memory.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local STORE_NAME = "PlayerProfiles"
local KEY_PREFIX = "Player_"
local ATTEMPTS = 3
local RETRY_WAIT = 1.5 -- seconds, multiplied by the attempt number

local Store = {}

local dataStore: DataStore? = nil
local memoryOnly = false
local warned = false
local activeWrites = 0

local function fallBackToMemory(reason: string)
	memoryOnly = true
	dataStore = nil
	if not warned then
		warned = true
		warn(("[ProfileService] DataStores are unavailable, so profiles are kept in memory and will not be saved (%s)"):format(reason))
	end
end

local function getStore(): DataStore?
	if memoryOnly then
		return nil
	end
	if dataStore then
		return dataStore
	end
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and result then
		dataStore = result
		return dataStore
	end
	fallBackToMemory(tostring(result))
	return nil
end

local function keyFor(userId: number): string
	return KEY_PREFIX .. tostring(userId)
end

-- False once the store has fallen back to memory only.
function Store.isPersistent(): boolean
	return not memoryOnly
end

-- Reads a player's stored value. Returns (ok, value):
--   true, value   the read worked (value is nil for a new player, or when running memory only)
--   false, nil    the read failed after retries; the caller must not save over this player's data
function Store.read(userId: number): (boolean, any)
	local found = getStore()
	if not found then
		return true, nil
	end
	local store: DataStore = found
	local key = keyFor(userId)
	for attempt = 1, ATTEMPTS do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return true, result
		end
		if RunService:IsStudio() then
			-- In Studio a failed read almost always means API access is switched off; don't keep retrying.
			fallBackToMemory(tostring(result))
			return true, nil
		end
		warn(("[ProfileService] Reading %s failed (attempt %d of %d): %s"):format(key, attempt, ATTEMPTS, tostring(result)))
		if attempt < ATTEMPTS then
			task.wait(RETRY_WAIT * attempt)
		end
	end
	return false, nil
end

-- Writes a player's stored value. Returns true if it was saved.
function Store.write(userId: number, value: { [string]: any }): boolean
	local found = getStore()
	if not found then
		return false
	end
	local store: DataStore = found
	local key = keyFor(userId)
	-- Tag the entry with the player's id (for data-removal requests). Studio test players have negative ids.
	local userIds = if userId > 0 then { userId } else nil
	activeWrites += 1
	local saved = false
	for attempt = 1, ATTEMPTS do
		local ok, err = pcall(function()
			store:SetAsync(key, value, userIds)
		end)
		if ok then
			saved = true
			break
		end
		warn(("[ProfileService] Saving %s failed (attempt %d of %d): %s"):format(key, attempt, ATTEMPTS, tostring(err)))
		if attempt < ATTEMPTS then
			task.wait(RETRY_WAIT * attempt)
		end
	end
	activeWrites -= 1
	return saved
end

-- How many writes are in flight right now (used to hold the server open while they finish).
function Store.activeWrites(): number
	return activeWrites
end

return Store
