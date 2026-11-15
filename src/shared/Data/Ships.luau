--!strict
-- Ship tiers (design decision D11): permanent upgrades bought with Renown. Owned by ProfileService.
-- Ships.Tiers[tier] is the tier's definition; Cost is the Renown needed to move up to that tier from the one below.

export type ShipDef = {
	Name: string,
	Cost: number,
	Adds: string, -- what the tier adds, for the upgrade button's note
}

local Ships = {
	MaxTier = 3,
	Tiers = {
		[1] = {
			Name = "Sloop",
			Cost = 0,
			Adds = "One mast, a chart table, a cook fire, a workbench and the ready bell.",
		},
		[2] = {
			Name = "Brigantine",
			Cost = 60,
			Adds = "Two masts, a galley, an infirmary and 4 cannons.",
		},
		[3] = {
			Name = "Galleon",
			Cost = 150,
			Adds = "Three masts, a workshop, a crow's nest, a captain's cabin and 8 cannons.",
		},
	} :: { ShipDef },
}

return Ships
