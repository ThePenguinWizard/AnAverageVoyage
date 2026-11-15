--!strict
-- What each ship station is called, what its prompt says, how close you must stand, and (for stations that have no
-- gameplay yet) the note it shows. Station kinds are the values of the `Station` attribute (design decision D11).

export type Info = {
	Name: string, -- shown on the prompt and as the title of its note
	Action: string, -- the prompt's action text
	Range: number, -- prompt distance in studs (rooms are bigger than chests)
	Note: string?, -- for stations that only explain what they will do later
}

export type Meal = {
	HealShare: number, -- share of MaxHP restored
	Resolve: number, -- Resolve change (negative relieves stress)
	Text: string,
}

local StationInfo = {}

StationInfo.Stations = {
	ChartTable = { Name = "Sea Chart", Action = "Study the chart", Range = 9 },
	ReadyBell = { Name = "Ready Bell", Action = "Ring the bell", Range = 8 },
	Stash = { Name = "Ship's Stash", Action = "Open", Range = 8 },
	CrewChest = { Name = "Crew Chest", Action = "Open", Range = 7 },
	CookFire = { Name = "Cook Fire", Action = "Cook a meal", Range = 8 },
	Galley = { Name = "Galley", Action = "Cook a meal", Range = 11 },
	Infirmary = { Name = "Infirmary", Action = "Rest a while", Range = 11 },
	Workbench = {
		Name = "Workbench",
		Action = "Look",
		Range = 8,
		Note = "Saw, vise and a stack of planks. Later, the crew will craft supplies here from what they bring back from the islands.",
	},
	Workshop = {
		Name = "Workshop",
		Action = "Look",
		Range = 11,
		Note = "The forge is cold for now. Later, weapons and gear will be reforged and improved here between islands.",
	},
	RecruitBoard = {
		Name = "Recruit Board",
		Action = "Read",
		Range = 8,
		Note = "Old notices, nothing fresh. Later, new hands looking for a crew will be posted here for the captain to sign on.",
	},
	CrowsNest = {
		Name = "Crow's Nest",
		Action = "Look out",
		Range = 8,
		Note = "Nothing but sea today. Later, a lookout up here will spot what is waiting on the islands ahead before the crew votes.",
	},
	Cannon = {
		Name = "Cannon",
		Action = "Inspect",
		Range = 7,
		Note = "Loaded and lashed down. Later, the guns will open a fight at sea before the crew boards.",
	},
	Helm = {
		Name = "Helm",
		Action = "Take the wheel",
		Range = 8,
		Note = "The wheel is lashed until the crew agrees on a course. Pick an island at the chart table, then ring the ready bell.",
	},
} :: { [string]: Info }

-- One meal per visit to the ship. The galley (tier 2 and up) is better than the open cook fire.
StationInfo.Meals = {
	CookFire = { HealShare = 0.25, Resolve = -10, Text = "You fry up what there is over the brazier." },
	Galley = { HealShare = 0.4, Resolve = -20, Text = "A proper hot meal from the galley stove." },
} :: { [string]: Meal }

-- One rest in the infirmary per visit.
StationInfo.InfirmaryResolve = -60

return StationInfo
