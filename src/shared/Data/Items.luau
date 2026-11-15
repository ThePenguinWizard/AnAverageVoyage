--!strict
-- Item catalogue for a voyage. Owned by ProfileService (see design/architecture.md).
--
-- How to read it:
--   Items[itemId]            -> the item's definition, or nil
--   Items.get(itemId)        -> the same, but only ever returns an item (use this for ids that come from a client)
--   for id, def in Items do  -> walks the items only (generalised iteration; do NOT use pairs(), which skips them)
--   Items.Order              -> item ids in display order
--   Items.StartingKit        -> { [itemId]: count } every voyage starts with
--   Items.StartingGold       -> gold every voyage starts with
--
-- Fields: Heal restores HP. Resolve changes stress and is negative for relief. Price is the cost in gold at a
-- market; for Treasure it is what the item is worth when sold. Tools and Treasure have no effect when used.

export type ItemKind = "Food" | "Medicine" | "Tool" | "Treasure"

export type ItemDef = {
	Name: string,
	Description: string,
	Kind: ItemKind,
	Heal: number?,
	Resolve: number?,
	Price: number,
}

export type ItemsModule = {
	[string]: ItemDef,
	Order: { string },
	StartingKit: { [string]: number },
	StartingGold: number,
	get: (itemId: string) -> ItemDef?,
}

local defs: { [string]: ItemDef } = {
	Hardtack = {
		Name = "Hardtack",
		Description = "A ship's biscuit baked hard enough to outlast the voyage. Filling, if you still have your teeth.",
		Kind = "Food",
		Heal = 8,
		Price = 4,
	},
	SaltedFish = {
		Name = "Salted Fish",
		Description = "Dried on the rigging and packed in salt. Tough, but it keeps a sailor on their feet.",
		Kind = "Food",
		Heal = 14,
		Price = 8,
	},
	SeaLimes = {
		Name = "Sea Limes",
		Description = "A net of sharp green limes. A little strength, and a welcome change from biscuit.",
		Kind = "Food",
		Heal = 5,
		Resolve = -10,
		Price = 9,
	},
	GalleyStew = {
		Name = "Galley Stew",
		Description = "A hot bowl of whatever the cook had left. Warms the hands and settles the nerves.",
		Kind = "Food",
		Heal = 20,
		Resolve = -10,
		Price = 18,
	},
	SpicedTea = {
		Name = "Spiced Tea",
		Description = "Black tea with clove and orange peel. It mends nothing, but it calms a shaken crew.",
		Kind = "Food",
		Resolve = -18,
		Price = 12,
	},
	Bandage = {
		Name = "Bandage",
		Description = "Clean linen strips, rolled tight. Binds a wound well enough to keep fighting.",
		Kind = "Medicine",
		Heal = 15,
		Price = 8,
	},
	KelpSalve = {
		Name = "Kelp Salve",
		Description = "A cold green paste that stings, then soothes. Closes deep cuts.",
		Kind = "Medicine",
		Heal = 30,
		Price = 20,
	},
	SmellingSalts = {
		Name = "Smelling Salts",
		Description = "One sniff clears the head and steadies the hands, however bad the day has been.",
		Kind = "Medicine",
		Resolve = -30,
		Price = 22,
	},
	Rope = {
		Name = "Coil of Rope",
		Description = "Thirty paces of tarred rope. There is always something that needs tying, climbing or hauling.",
		Kind = "Tool",
		Price = 10,
	},
	Pearl = {
		Name = "Storm Pearl",
		Description = "A grey pearl with a dark swirl at its heart. Any market will pay well for it.",
		Kind = "Treasure",
		Price = 40,
	},
	SunkenIdol = {
		Name = "Sunken Idol",
		Description = "A small gold figure crusted with barnacles. Someone lost a fortune when this went down.",
		Kind = "Treasure",
		Price = 90,
	},
}

local Items = {
	Order = {
		"Hardtack",
		"SaltedFish",
		"SeaLimes",
		"GalleyStew",
		"SpicedTea",
		"Bandage",
		"KelpSalve",
		"SmellingSalts",
		"Rope",
		"Pearl",
		"SunkenIdol",
	},
	StartingKit = {
		Hardtack = 3,
		Bandage = 2,
	},
	StartingGold = 30,
}

function Items.get(itemId: string): ItemDef?
	if type(itemId) ~= "string" then
		return nil
	end
	return defs[itemId]
end

setmetatable(Items, {
	__index = defs,
	__iter = function()
		return next, defs
	end,
})

return (Items :: any) :: ItemsModule
