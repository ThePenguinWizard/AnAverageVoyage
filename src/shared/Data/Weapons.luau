--!strict
-- Weapon styles (design decision D7). Owned by ProfileService.
--
-- How to read it:
--   Weapons[weaponId]            -> the style's definition, or nil
--   Weapons.get(weaponId)        -> the same, but only ever returns a style (use this for ids that come from a client)
--   for id, def in Weapons do    -> walks the styles only (generalised iteration; do NOT use pairs())
--   Weapons.Order                -> ids in display order
--   Weapons.Default              -> the style a new player starts with
--
-- Only styles with Available = true can be chosen. The rest are listed so the UI can show what is coming.

export type WeaponDef = {
	Name: string,
	When: "Prototype" | "Launch" | "Later",
	Available: boolean,
	Rank: string, -- where the fighter stands in the formation
	Minigame: string, -- the attack minigame on the player's own turn
	Identity: string, -- what the style is good at
}

export type WeaponsModule = {
	[string]: WeaponDef,
	Order: { string },
	Default: string,
	get: (weaponId: string) -> WeaponDef?,
}

local defs: { [string]: WeaponDef } = {
	Sword = {
		Name = "Sword",
		When = "Prototype",
		Available = true,
		Rank = "Front",
		Minigame = "A timing-bar slash: stop the mark in the sweet spot.",
		Identity = "Reliable damage, and it breaks guards.",
	},
	Gun = {
		Name = "Gun",
		When = "Prototype",
		Available = true,
		Rank = "Back",
		Minigame = "A drifting crosshair: fire when it is over the weak point.",
		Identity = "Hits the enemy's back line and loads trick ammo (smoke, fire, nets). Weak if pulled forward.",
	},
	Fist = {
		Name = "Fist",
		When = "Prototype",
		Available = true,
		Rank = "Front",
		Minigame = "A short rhythm combo.",
		Identity = "Hits several times, knocks enemies out of their line and builds itself up.",
	},
	Shield = {
		Name = "Shield",
		When = "Launch",
		Available = false,
		Rank = "Front",
		Minigame = "A simple timed bash, with a sidearm to follow.",
		Identity = "Taunts: pulls enemy attacks onto itself. Its real test of skill is the dodge.",
	},
	Harpoon = {
		Name = "Harpoon / Spear",
		When = "Launch",
		Available = false,
		Rank = "Front",
		Minigame = "Charge and release: hold, then let go in the sweet spot.",
		Identity = "Reaches through to the back line and drags back-line enemies forward.",
	},
	WeatherStaff = {
		Name = "Weather Staff",
		When = "Later",
		Available = false,
		Rank = "Back",
		Minigame = "Trace a shape.",
		Identity = "Area attacks, plus weather that changes the next dodge: rain slows bullets, wind pushes them sideways.",
	},
	Daggers = {
		Name = "Daggers",
		When = "Later",
		Available = false,
		Rank = "Any",
		Minigame = "Reaction taps: targets pop up and you tap them fast.",
		Identity = "Critical hits, poison, and stealing gold and items.",
	},
}

local Weapons = {
	Order = { "Sword", "Gun", "Fist", "Shield", "Harpoon", "WeatherStaff", "Daggers" },
	Default = "Sword",
}

function Weapons.get(weaponId: string): WeaponDef?
	if type(weaponId) ~= "string" then
		return nil
	end
	return defs[weaponId]
end

setmetatable(Weapons, {
	__index = defs,
	__iter = function()
		return next, defs
	end,
})

return (Weapons :: any) :: WeaponsModule
