--!strict
-- Safe reads of the item catalogue (ReplicatedStorage.Shared.Data.Items, owned by ProfileService) for the ship camp.
-- The catalogue belongs to another feature, so every read is defensive: if the module is missing or broken, callers
-- get nil / the raw item id back instead of an error.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Item = {
	Name: string,
	Description: string,
	Kind: string,
	Heal: number?,
	Resolve: number?,
	Price: number,
}

local ItemLookup = {}

local cached: any = nil

local function load(): any
	if cached ~= nil then
		return cached
	end
	local sharedFolder = ReplicatedStorage:FindFirstChild("Shared")
	local data = sharedFolder and sharedFolder:FindFirstChild("Data")
	local module = data and data:FindFirstChild("Items")
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, result = pcall(require, module)
	if ok and type(result) == "table" then
		cached = result
		return result
	end
	return nil
end

-- The item's definition, or nil if the id is unknown or the catalogue is unavailable.
function ItemLookup.find(itemId: string): Item?
	if type(itemId) ~= "string" then
		return nil
	end
	local items = load()
	if items == nil then
		return nil
	end
	local entry: any = nil
	if type(items.get) == "function" then
		local ok, result = pcall(items.get, itemId)
		if ok then
			entry = result
		end
	else
		local ok, result = pcall(function()
			return items[itemId]
		end)
		if ok then
			entry = result
		end
	end
	if type(entry) ~= "table" then
		return nil
	end
	return entry :: Item
end

-- Display name; falls back to the raw id.
function ItemLookup.name(itemId: string): string
	local item = ItemLookup.find(itemId)
	if item and type(item.Name) == "string" and item.Name ~= "" then
		return item.Name
	end
	return itemId
end

-- Description; empty string if unknown.
function ItemLookup.description(itemId: string): string
	local item = ItemLookup.find(itemId)
	if item and type(item.Description) == "string" then
		return item.Description
	end
	return ""
end

-- Kind ("Food", "Medicine", ...); empty string if unknown.
function ItemLookup.kind(itemId: string): string
	local item = ItemLookup.find(itemId)
	if item and type(item.Kind) == "string" then
		return item.Kind
	end
	return ""
end

-- What using the item does: (HP healed, Resolve change). Resolve is negative for stress relief. (0, 0) if unknown.
function ItemLookup.effects(itemId: string): (number, number)
	local item = ItemLookup.find(itemId)
	if not item then
		return 0, 0
	end
	local heal = if type(item.Heal) == "number" and item.Heal == item.Heal then item.Heal else 0
	local resolve = if type(item.Resolve) == "number" and item.Resolve == item.Resolve then item.Resolve else 0
	return math.max(0, heal), resolve
end

-- True if using the item at a chest would do anything.
function ItemLookup.isUsable(itemId: string): boolean
	local heal, resolve = ItemLookup.effects(itemId)
	return heal > 0 or resolve ~= 0
end

-- Item ids in display order, if the catalogue provides one.
function ItemLookup.order(): { string }?
	local items = load()
	if items == nil then
		return nil
	end
	local ok, order = pcall(function()
		return items.Order
	end)
	if ok and type(order) == "table" then
		return order
	end
	return nil
end

return ItemLookup
