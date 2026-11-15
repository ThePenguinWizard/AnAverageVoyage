--!strict
-- Crew roles: the eight launch roles from design decision D7. Owned by ProfileService.
-- A player may also sail with no role, which is the empty string "" (not an entry in this table).
--
-- How to read it:
--   Roles[roleId]            -> the role's definition, or nil
--   Roles.get(roleId)        -> the same, but only ever returns a role (use this for ids that come from a client)
--   for id, def in Roles do  -> walks the roles only (generalised iteration; do NOT use pairs())
--   Roles.Order              -> ids in display order

export type RoleDef = {
	Name: string,
	Action: string, -- what the role does on its own turn
	DodgeHelp: string, -- how it helps while a crewmate is dodging
	VoyagePerk: string, -- what it does for the voyage
}

export type RolesModule = {
	[string]: RoleDef,
	Order: { string },
	get: (roleId: string) -> RoleDef?,
}

local defs: { [string]: RoleDef } = {
	Captain = {
		Name = "Captain",
		Action = "Rally: the crew gains Tension and loses some stress.",
		DodgeHelp = "Bullets slow down for 2 seconds.",
		VoyagePerk = "Breaks tied votes on the sea chart.",
	},
	Navigator = {
		Name = "Navigator",
		Action = "Shows the enemies' next moves further ahead.",
		DodgeHelp = "Warning lines show where the next bullets will spawn.",
		VoyagePerk = "Clears more fog on the chart and avoids one sea hazard per sea.",
	},
	Doctor = {
		Name = "Doctor",
		Action = "Heals an ally and cures a status.",
		DodgeHelp = "Heals half the damage from that dodge once it ends.",
		VoyagePerk = "Clears Scars at ports.",
	},
	Cook = {
		Name = "Cook",
		Action = "A snack: a small heal plus stress relief.",
		DodgeHelp = "Tosses food into the box that heals when grabbed.",
		VoyagePerk = "Port meals relieve more stress.",
	},
	Shipwright = {
		Name = "Shipwright",
		Action = "Shields an ally.",
		DodgeHelp = "Places a plank wall in the box for 3 seconds.",
		VoyagePerk = "Repairs the ship and cancels some sea hazards.",
	},
	Musician = {
		Name = "Musician",
		Action = "Plays a buff for the whole crew.",
		DodgeHelp = "The dodger gains no stress from this attack.",
		VoyagePerk = "Storms cause less stress.",
	},
	Archaeologist = {
		Name = "Archaeologist",
		Action = "Reveals enemy weaknesses.",
		DodgeHelp = "Shows the safe spot for the first second.",
		VoyagePerk = "Reads ruin glyphs: the clue-holder in crew puzzles.",
	},
	Gunner = {
		Name = "Gunner",
		Action = "Once per fight, the ship's cannons hit every enemy.",
		DodgeHelp = "Shoots down up to 3 bullets in the box.",
		VoyagePerk = "Wins ship battles and fights sea monsters on the sea lanes.",
	},
}

local Roles = {
	Order = { "Captain", "Navigator", "Doctor", "Cook", "Shipwright", "Musician", "Archaeologist", "Gunner" },
}

function Roles.get(roleId: string): RoleDef?
	if type(roleId) ~= "string" then
		return nil
	end
	return defs[roleId]
end

setmetatable(Roles, {
	__index = defs,
	__iter = function()
		return next, defs
	end,
})

return (Roles :: any) :: RolesModule
