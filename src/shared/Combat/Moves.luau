--!strict
-- Combat data: player moves, enemy moves, enemies, ready-made encounters, afflictions and virtues, and the text of
-- the fail close-ups. Every number here is a starting value to tune in playtests.
--
-- ENEMY IDS (the keys of Moves.Enemies; pass these to CombatService.startBattle):
--   Regular:  Deckhand, Swordsman, Gunner, Bomber, Brute, Harpooner
--   Elite:    Duelist, Cannoneer
--   Boss:     CaptainRedtide (Sea 1), CommodoreVane (Sea 2), StormAdmiral (Sea 3)
--
-- READY-MADE ENCOUNTERS (Moves.Encounters), so the voyage can pick a fight without knowing enemy details:
--   Moves.Encounters.Battle     a list of encounters, ordered from easiest to hardest; each one is a list of enemy ids
--   Moves.Encounters.Elite      a list of encounters, same shape
--   Moves.Encounters.Boss.Sea1  one encounter (a list of enemy ids); also .Sea2 and .Sea3
-- Example: CombatService.startBattle(player, { Kind = "Elite", Enemies = Moves.Encounters.Elite[1] })
-- An encounter holds at most six enemies (a front line and a back line of three).
--
-- Player moves are graded by an attack minigame (decision D3): Perfect 130%, Good 100%, Fail 0%.
-- Enemy moves are patterns drawn on the parchment dodge card (D6, D13).

local Moves = {}

Moves.PlayerMaxHP = 60
Moves.GradeMultiplier = { Perfect = 1.3, Good = 1, Fail = 0 }

-- Brace: skip attacking to take about a third less damage from the enemy attacks that follow this round.
Moves.BraceMultiplier = 0.67

-- Resolve is stress (D4), 0 to Max. At Break the character rolls a Virtue or an Affliction, which lasts until Resolve
-- drops below Clear.
Moves.Resolve = {
	Max = 200,
	Break = 100,
	Clear = 50,
	VirtueChance = 0.4,
	FailAttack = 10, -- a failed attack minigame
	PerHit = 5, -- each hit taken in the dodge box
	PerAttackCap = 15, -- most Resolve the hits of one enemy attack can add
	BadDodge = 5, -- extra when one enemy attack takes BadDodgeFraction of MaxHP or more
	CleanDodge = -3, -- an enemy attack dodged without a single hit
}
Moves.BadDodgeFraction = 0.25

-- Dodge box tuning. Positions and sizes are fractions of the square field; times are seconds.
Moves.Dodge = {
	Warn = 0.8, -- how long a shape is shown pale before it hurts
	Hurt = 0.22, -- how long it stays dark and can hurt
	Invulnerable = 0.6, -- safe time after a hit
	Tail = 0.45, -- quiet time after the last shape
	SoulSpeed = 0.95, -- field widths per second
	SoulRadius = 0.035,
}

------------------------------------------------------------------------------------------------------------------
-- Player moves
------------------------------------------------------------------------------------------------------------------

export type PlayerMove = {
	Name: string,
	Weapon: string,
	Game: string,
	Damage: number,
	Label: string,
	Hint: string,
	Tuning: { [string]: number },
}

-- Game: which minigame grades the move, and what its Tuning numbers mean.
--   Timing: stop the sweeping blade in the middle of the bar.
--           Speed = sweeps per second, Good / Perfect = half-width of each zone (fraction of the bar),
--           Passes = sweeps before the chance is lost.
--   Aim:    fire while the drifting crosshair is over the mark.
--           Speed = drift speed, Good / Perfect = radius of each ring (fraction of the box), Time = seconds allowed.
--   Rhythm: press on every beat.
--           Beats = how many, Interval = seconds between beats, Good / Perfect = allowed error in seconds.
Moves.Player = {
	Slash = {
		Name = "Slash",
		Weapon = "Sword",
		Game = "Timing",
		Damage = 9,
		Label = "Cutlass  ·  slash",
		Hint = "Stop the blade in the middle.",
		Tuning = { Speed = 1.1, Good = 0.2, Perfect = 0.06, Passes = 4 },
	},
	Cleave = {
		Name = "Heavy Cleave",
		Weapon = "Sword",
		Game = "Timing",
		Damage = 15,
		Label = "Cutlass  ·  heavy cleave",
		Hint = "A faster blade and a narrower mark.",
		Tuning = { Speed = 1.7, Good = 0.12, Perfect = 0.04, Passes = 3 },
	},
	AimedShot = {
		Name = "Aimed Shot",
		Weapon = "Gun",
		Game = "Aim",
		Damage = 8,
		Label = "Flintlock  ·  aimed shot",
		Hint = "Fire when the crosshair is on the mark.",
		Tuning = { Speed = 1, Good = 0.16, Perfect = 0.06, Time = 8 },
	},
	Deadeye = {
		Name = "Deadeye",
		Weapon = "Gun",
		Game = "Aim",
		Damage = 14,
		Label = "Flintlock  ·  deadeye",
		Hint = "A quicker drift and a smaller mark.",
		Tuning = { Speed = 1.5, Good = 0.11, Perfect = 0.045, Time = 6 },
	},
	Combo = {
		Name = "Combo",
		Weapon = "Fist",
		Game = "Rhythm",
		Damage = 10,
		Label = "Fists  ·  four-hit combo",
		Hint = "Strike on each of the four beats.",
		Tuning = { Beats = 4, Interval = 0.55, Good = 0.16, Perfect = 0.06 },
	},
	Flurry = {
		Name = "Flurry",
		Weapon = "Fist",
		Game = "Rhythm",
		Damage = 16,
		Label = "Fists  ·  six-hit flurry",
		Hint = "Six quick beats. Miss one and it all falls apart.",
		Tuning = { Beats = 6, Interval = 0.4, Good = 0.12, Perfect = 0.05 },
	},
} :: { [string]: PlayerMove }
Moves.PlayerOrder = { "Slash", "Cleave", "AimedShot", "Deadeye", "Combo", "Flurry" }

-- Each weapon style's moves: the basic one first, then the stronger, harder one.
Moves.Weapons = {
	Sword = { "Slash", "Cleave" },
	Gun = { "AimedShot", "Deadeye" },
	Fist = { "Combo", "Flurry" },
} :: { [string]: { string } }

-- The moves a player with this Weapon attribute may use. Every move if the weapon is missing or unknown.
function Moves.movesFor(weapon: any): { string }
	if type(weapon) == "string" then
		local list = Moves.Weapons[weapon]
		if list then
			return table.clone(list)
		end
	end
	return table.clone(Moves.PlayerOrder)
end

------------------------------------------------------------------------------------------------------------------
-- Enemy moves
------------------------------------------------------------------------------------------------------------------

-- A pattern is a list of elements. Every element warns first (drawn pale with a red outline for Warn seconds, counted
-- from At), then turns dark for Hurt seconds, which is when it hurts.
--   Arc:   a blade sweep from one side of the card. Side = Left | Right | Top | Bottom. Reach = how far it reaches
--          (0.56 covers a little more than half the card; two opposite arcs at 0.4 leave a lane down the middle).
--   Shot:  a straight line across the card. Axis "H" runs left to right (its position is a height), "V" runs top to
--          bottom. Aim = "Soul" (where the soul is when the warning appears), "Random", or "Fixed" (uses Pos).
--          Offset shifts an aimed shot, for a second line beside the first. Width = its thickness (default 0.09).
--   Blast: a round burst. Aim = "Soul", "Random" or "Fixed" (uses X, Y). Radius = its size.
--   Rail:  not an attack. For `For` seconds the soul rides a rail and can only move along Axis ("H" or "V").
export type Element = {
	Kind: string,
	At: number,
	Warn: number?,
	Hurt: number?,
	Side: string?,
	Reach: number?,
	Axis: string?,
	Aim: string?,
	Pos: number?,
	Offset: number?,
	Width: number?,
	X: number?,
	Y: number?,
	Radius: number?,
	For: number?,
}
export type EnemyMove = { Label: string, Damage: number, Pattern: { Element } }

local function arc(at: number, side: string, reach: number?, warn: number?): Element
	return { Kind = "Arc", At = at, Side = side, Reach = reach, Warn = warn }
end

-- where: nil aims at the soul, "Random" picks a random spot, a number is a fixed position.
local function shot(at: number, axis: string, where: (number | string)?, warn: number?, offset: number?): Element
	local e: Element = { Kind = "Shot", At = at, Axis = axis, Aim = "Soul", Warn = warn, Offset = offset }
	if type(where) == "number" then
		e.Aim = "Fixed"
		e.Pos = where
	elseif where == "Random" then
		e.Aim = "Random"
	end
	return e
end

-- where: nil aims at the soul, "Random" picks a random spot, a Vector2 is a fixed spot.
local function blast(at: number, where: (Vector2 | string)?, radius: number?, warn: number?): Element
	local e: Element = { Kind = "Blast", At = at, Aim = "Soul", Radius = radius, Warn = warn }
	if typeof(where) == "Vector2" then
		e.Aim = "Fixed"
		e.X = where.X
		e.Y = where.Y
	elseif where == "Random" then
		e.Aim = "Random"
	end
	return e
end

local function rail(at: number, axis: string, duration: number): Element
	return { Kind = "Rail", At = at, Axis = axis, For = duration }
end

-- A row of fixed shots that land together, leaving lanes between them. The shots are thinner than a normal shot so
-- the lanes are wide enough to stand in.
local function wave(at: number, axis: string, positions: { number }, warn: number?): { Element }
	local list: { Element } = {}
	for _, pos in positions do
		local e = shot(at, axis, pos, warn)
		e.Width = 0.06
		table.insert(list, e)
	end
	return list
end

-- Builds a pattern from elements and lists of elements.
local function pattern(...: any): { Element }
	local list: { Element } = {}
	for _, item in { ... } do
		if item.Kind then
			table.insert(list, item)
		else
			for _, sub in item do
				table.insert(list, sub)
			end
		end
	end
	return list
end

-- Two broadside rows that cover each other's lanes.
local LANES_A = { 0.125, 0.375, 0.625, 0.875 }
local LANES_B = { 0, 0.25, 0.5, 0.75, 1 }

Moves.Enemy = {
	-- Pirate Deckhand
	CutlassSweep = { Label = "Cutlass  ·  sweep", Damage = 4, Pattern = pattern(arc(0, "Left")) },
	WildSwing = { Label = "Cutlass  ·  wild swing", Damage = 4, Pattern = pattern(arc(0, "Top"), arc(0.95, "Left")) },

	-- Navy Swordsman
	LeftRight = { Label = "Cutlass  ·  left, right", Damage = 4, Pattern = pattern(arc(0, "Left"), arc(1.15, "Right")) },
	UpDown = { Label = "Cutlass  ·  up, down", Damage = 4, Pattern = pattern(arc(0, "Top"), arc(1.15, "Bottom")) },

	-- Navy Gunner
	AimedShot = { Label = "Flintlock  ·  aimed shot", Damage = 5, Pattern = pattern(shot(0, "H")) },
	Volley = { Label = "Flintlock  ·  volley", Damage = 3, Pattern = pattern(shot(0, "H"), shot(0.5, "H"), shot(1, "H")) },

	-- Powder Monkey
	LobbedBomb = {
		Label = "Powder keg  ·  lobbed bombs",
		Damage = 5,
		Pattern = pattern(blast(0, nil, 0.26, 1), blast(1, nil, 0.26, 1), blast(2, nil, 0.3, 1)),
	},
	PowderScatter = {
		Label = "Powder keg  ·  scatter",
		Damage = 4,
		Pattern = pattern(
			blast(0, "Random", 0.2),
			blast(0.35, "Random", 0.2),
			blast(0.7, "Random", 0.2),
			blast(1.05, nil, 0.2),
			blast(1.8, "Random", 0.2),
			blast(2.15, nil, 0.2)
		),
	},

	-- Dock Brute
	Pincer = {
		Label = "Belaying pins  ·  pincer",
		Damage = 5,
		Pattern = pattern(
			arc(0, "Left", 0.4, 1),
			arc(0, "Right", 0.4, 1),
			shot(1.3, "V"),
			arc(2.3, "Top", 0.4, 0.9),
			arc(2.3, "Bottom", 0.4, 0.9)
		),
	},
	Overhead = {
		Label = "Belaying pins  ·  overhead",
		Damage = 6,
		Pattern = pattern(arc(0, "Top", 0.7, 1.1), arc(1.3, "Bottom", 0.7, 0.9), arc(2.5, "Top", 0.7, 0.9)),
	},

	-- Reef Harpooner
	HarpoonLine = {
		Label = "Harpoon  ·  on the line",
		Damage = 4,
		Pattern = pattern(
			rail(0, "H", 4.3),
			shot(0.5, "V"),
			shot(1.3, "V"),
			shot(2.1, "V"),
			shot(2.1, "V", nil, nil, 0.2),
			shot(2.9, "V"),
			shot(2.9, "V", nil, nil, -0.2)
		),
	},
	NetToss = {
		Label = "Harpoon  ·  net and spear",
		Damage = 4,
		Pattern = pattern(blast(0, nil, 0.3, 1), shot(1.2, "H"), shot(1.7, "H"), blast(2.5, nil, 0.3, 0.9)),
	},

	-- Navy Duelist (elite)
	FencersFlurry = {
		Label = "Rapier  ·  fencer's flurry",
		Damage = 5,
		Pattern = pattern(
			arc(0, "Left", nil, 0.75),
			arc(0.85, "Top", nil, 0.75),
			arc(1.7, "Right", nil, 0.75),
			arc(2.55, "Bottom", nil, 0.75),
			arc(3.5, "Left", 0.4),
			arc(3.5, "Right", 0.4),
			shot(4.6, "H", nil, 0.6),
			shot(5.1, "V", nil, 0.6),
			arc(5.9, "Top", 0.4),
			arc(5.9, "Bottom", 0.4)
		),
	},
	Riposte = {
		Label = "Rapier  ·  riposte",
		Damage = 5,
		Pattern = pattern(
			arc(0, "Left", 0.4),
			arc(0, "Right", 0.4),
			arc(1.1, "Top", 0.4),
			arc(1.1, "Bottom", 0.4),
			shot(2.2, "H"),
			shot(2.7, "V"),
			arc(3.6, "Left", nil, 0.6),
			arc(4.3, "Right", nil, 0.6),
			arc(5, "Top", nil, 0.6)
		),
	},

	-- Master Cannoneer (elite)
	Barrage = {
		Label = "Deck gun  ·  barrage",
		Damage = 6,
		Pattern = pattern(
			blast(0, "Random", 0.22, 0.9),
			blast(0.4, "Random", 0.22, 0.9),
			blast(0.8, "Random", 0.22, 0.9),
			blast(1.2, nil, 0.22, 0.9),
			blast(1.9, "Random", 0.22, 0.9),
			blast(2.3, "Random", 0.22, 0.9),
			blast(2.7, nil, 0.22, 0.9),
			blast(3.4, "Random", 0.22, 0.9),
			blast(3.8, nil, 0.22, 0.9),
			blast(4.4, nil, 0.22, 0.9),
			blast(5, "Random", 0.22, 0.9),
			blast(5.4, nil, 0.22, 0.9)
		),
	},
	ChainShot = {
		Label = "Deck gun  ·  chain shot",
		Damage = 5,
		Pattern = pattern(
			rail(0, "V", 6.2),
			shot(0.5, "H"),
			shot(1.3, "H"),
			shot(2.1, "H"),
			shot(2.1, "H", nil, nil, 0.2),
			shot(2.9, "H"),
			shot(3.7, "H"),
			shot(3.7, "H", nil, nil, -0.2),
			shot(4.5, "H", nil, 0.55),
			shot(5, "H", nil, 0.55),
			shot(5.5, "H", nil, 0.55)
		),
	},

	-- Captain Redtide (boss, Sea 1)
	BraceOfPistols = {
		Label = "Brace of pistols  ·  double shots",
		Damage = 5,
		Pattern = pattern(
			shot(0, "H"),
			shot(0.4, "H", nil, 0.65),
			shot(1.5, "V"),
			shot(1.9, "V", nil, 0.65),
			shot(3, "H"),
			shot(3.4, "V", nil, 0.65),
			blast(4.4, nil, 0.28, 0.9)
		),
	},
	BoardingRush = {
		Label = "Cutlass  ·  boarding rush",
		Damage = 5,
		Pattern = pattern(
			arc(0, "Left"),
			arc(0.8, "Right"),
			arc(1.7, "Top", 0.4),
			arc(1.7, "Bottom", 0.4),
			blast(2.7, nil, 0.28),
			arc(3.4, "Top"),
			arc(4.1, "Bottom"),
			arc(5, "Left", 0.4),
			arc(5, "Right", 0.4)
		),
	},
	RedTide = {
		Label = "Signature  ·  the red tide",
		Damage = 6,
		Pattern = pattern(
			arc(0, "Left"),
			arc(0.8, "Right"),
			arc(1.6, "Top"),
			rail(2.7, "H", 3.4),
			shot(3, "V"),
			shot(3.6, "V"),
			shot(4.2, "V"),
			shot(4.2, "V", nil, nil, 0.2),
			shot(4.9, "V"),
			blast(6.3, nil, 0.24),
			blast(6.7, "Random", 0.24),
			blast(7.3, nil, 0.24),
			arc(8, "Left", 0.4),
			arc(8, "Right", 0.4),
			arc(8.9, "Top", 0.4),
			arc(8.9, "Bottom", 0.4)
		),
	},

	-- Commodore Vane (boss, Sea 2)
	Broadside = {
		Label = "Ship's guns  ·  broadside",
		Damage = 6,
		Pattern = pattern(
			wave(0, "H", LANES_A, 1),
			wave(1.1, "H", LANES_B, 0.9),
			wave(2.1, "V", LANES_A, 0.9),
			wave(3.1, "V", LANES_B, 0.9),
			blast(4.2, nil, 0.28)
		),
	},
	SabreDrill = {
		Label = "Sabre  ·  parade drill",
		Damage = 6,
		Pattern = pattern(
			arc(0, "Left", nil, 0.65),
			arc(0.7, "Right", nil, 0.65),
			arc(1.4, "Top", nil, 0.65),
			arc(2.1, "Bottom", nil, 0.65),
			arc(3, "Left", 0.4),
			arc(3, "Right", 0.4),
			arc(3.8, "Top", 0.4),
			arc(3.8, "Bottom", 0.4),
			arc(4.8, "Left", 0.7),
			arc(5.7, "Right", 0.7)
		),
	},
	FiringLine = {
		Label = "Signature  ·  the firing line",
		Damage = 6,
		Pattern = pattern(
			rail(0, "V", 4.6),
			shot(0.4, "H"),
			shot(1.1, "H"),
			shot(1.8, "H"),
			shot(1.8, "H", nil, nil, 0.2),
			shot(2.5, "H"),
			shot(3.2, "H"),
			shot(3.2, "H", nil, nil, -0.2),
			rail(5, "H", 4.6),
			shot(5.4, "V"),
			shot(6.1, "V"),
			shot(6.8, "V"),
			shot(6.8, "V", nil, nil, 0.2),
			shot(7.5, "V"),
			shot(8.2, "V"),
			shot(8.2, "V", nil, nil, -0.2),
			blast(9.8, nil, 0.3, 0.9)
		),
	},

	-- The Storm Admiral (boss, Sea 3)
	Lightning = {
		Label = "Storm  ·  lightning",
		Damage = 7,
		Pattern = pattern(
			shot(0, "V", "Random", 0.7),
			shot(0, "V", "Random", 0.7),
			shot(0, "V", nil, 0.7),
			shot(0.95, "V", "Random", 0.65),
			shot(0.95, "V", "Random", 0.65),
			shot(0.95, "V", nil, 0.65),
			shot(1.9, "H", "Random", 0.65),
			shot(1.9, "H", "Random", 0.65),
			shot(1.9, "H", nil, 0.65),
			shot(2.85, "V", "Random", 0.6),
			shot(2.85, "V", "Random", 0.6),
			shot(2.85, "V", nil, 0.6),
			shot(3.8, "H", "Random", 0.6),
			shot(3.8, "V", "Random", 0.6),
			shot(3.8, "H", nil, 0.6),
			blast(4.8, nil, 0.3, 0.9)
		),
	},
	Maelstrom = {
		Label = "Storm  ·  maelstrom",
		Damage = 7,
		Pattern = pattern(
			blast(0, Vector2.new(0.5, 0.5), 0.3, 0.9),
			arc(0.9, "Left", nil, 0.7),
			arc(1.5, "Top", nil, 0.7),
			arc(2.1, "Right", nil, 0.7),
			arc(2.7, "Bottom", nil, 0.7),
			blast(3.7, Vector2.new(0, 0), 0.42, 0.9),
			blast(3.7, Vector2.new(1, 0), 0.42, 0.9),
			blast(3.7, Vector2.new(0, 1), 0.42, 0.9),
			blast(3.7, Vector2.new(1, 1), 0.42, 0.9),
			blast(4.7, Vector2.new(0.5, 0.5), 0.36, 0.8),
			blast(5.5, "Random", 0.22),
			blast(5.8, "Random", 0.22),
			blast(6.1, "Random", 0.22),
			blast(6.5, nil, 0.24)
		),
	},
	DrownedFleet = {
		Label = "Signature  ·  the drowned fleet",
		Damage = 7,
		Pattern = pattern(
			wave(0, "H", LANES_A, 1),
			wave(0.95, "V", LANES_B, 0.85),
			wave(1.9, "H", LANES_B, 0.85),
			wave(2.85, "V", LANES_A, 0.85),
			rail(4.1, "H", 3.6),
			shot(4.4, "V"),
			shot(5, "V"),
			shot(5.6, "V"),
			shot(5.6, "V", nil, nil, 0.2),
			shot(6.2, "V"),
			shot(6.7, "V"),
			shot(6.7, "V", nil, nil, -0.2),
			arc(8, "Left", 0.4),
			arc(8, "Right", 0.4),
			arc(8.8, "Top", 0.4),
			arc(8.8, "Bottom", 0.4),
			blast(9.6, nil, 0.24),
			blast(10, nil, 0.24),
			blast(10.4, nil, 0.24),
			arc(10.9, "Top", 0.7)
		),
	},
} :: { [string]: EnemyMove }

-- How long a move's dodge lasts, in seconds.
function Moves.patternDuration(move: EnemyMove): number
	local last = 0
	for _, e in move.Pattern do
		local finish: number
		if e.Kind == "Rail" then
			finish = e.At + (e.For or 0)
		else
			finish = e.At + (e.Warn or Moves.Dodge.Warn) + (e.Hurt or Moves.Dodge.Hurt)
		end
		last = math.max(last, finish)
	end
	return last + Moves.Dodge.Tail
end

-- The most hits a move can land: each element hits at most once, and a hit makes the soul safe for a moment, so
-- shapes that land together count once. The server clamps the client's reported hit count to this.
function Moves.maxHits(move: EnemyMove): number
	local windows: { { number } } = {}
	for _, e in move.Pattern do
		if e.Kind ~= "Rail" then
			local start = e.At + (e.Warn or Moves.Dodge.Warn)
			table.insert(windows, { start, start + (e.Hurt or Moves.Dodge.Hurt) })
		end
	end
	table.sort(windows, function(a, b)
		if a[2] == b[2] then
			return a[1] < b[1]
		end
		return a[2] < b[2]
	end)
	local count = 0
	local nextFree = -math.huge
	for _, w in windows do
		local at = math.max(w[1], nextFree)
		if at <= w[2] then
			count += 1
			nextFree = at + Moves.Dodge.Invulnerable
		end
	end
	return count
end

------------------------------------------------------------------------------------------------------------------
-- Enemies and encounters
------------------------------------------------------------------------------------------------------------------

export type Enemy = {
	Name: string,
	Tier: string, -- "Regular", "Elite" or "Boss"
	MaxHP: number,
	Moves: { string }, -- ids in Moves.Enemy; one is picked for each attack
	Weapon: string, -- what the model holds: Cutlass, Flintlock, Bomb, Club, Harpoon, Rapier or Cannon
	Rank: number, -- preferred line on the enemy side (1 = front, 2 = back)
}

Moves.Enemies = {
	Deckhand = { Name = "Pirate Deckhand", Tier = "Regular", MaxHP = 20, Moves = { "CutlassSweep", "WildSwing" }, Weapon = "Cutlass", Rank = 1 },
	Swordsman = { Name = "Navy Swordsman", Tier = "Regular", MaxHP = 26, Moves = { "LeftRight", "UpDown" }, Weapon = "Cutlass", Rank = 1 },
	Gunner = { Name = "Navy Gunner", Tier = "Regular", MaxHP = 18, Moves = { "AimedShot", "Volley" }, Weapon = "Flintlock", Rank = 2 },
	Bomber = { Name = "Powder Monkey", Tier = "Regular", MaxHP = 16, Moves = { "LobbedBomb", "PowderScatter" }, Weapon = "Bomb", Rank = 2 },
	Brute = { Name = "Dock Brute", Tier = "Regular", MaxHP = 34, Moves = { "Pincer", "Overhead" }, Weapon = "Club", Rank = 1 },
	Harpooner = { Name = "Reef Harpooner", Tier = "Regular", MaxHP = 22, Moves = { "HarpoonLine", "NetToss" }, Weapon = "Harpoon", Rank = 2 },

	Duelist = { Name = "Navy Duelist", Tier = "Elite", MaxHP = 58, Moves = { "FencersFlurry", "Riposte" }, Weapon = "Rapier", Rank = 1 },
	Cannoneer = { Name = "Master Cannoneer", Tier = "Elite", MaxHP = 66, Moves = { "Barrage", "ChainShot" }, Weapon = "Cannon", Rank = 2 },

	CaptainRedtide = {
		Name = "Captain Redtide",
		Tier = "Boss",
		MaxHP = 80,
		Moves = { "BraceOfPistols", "BoardingRush", "RedTide" },
		Weapon = "Cutlass",
		Rank = 2,
	},
	CommodoreVane = {
		Name = "Commodore Vane",
		Tier = "Boss",
		MaxHP = 105,
		Moves = { "Broadside", "SabreDrill", "FiringLine" },
		Weapon = "Rapier",
		Rank = 2,
	},
	StormAdmiral = {
		Name = "The Storm Admiral",
		Tier = "Boss",
		MaxHP = 130,
		Moves = { "Lightning", "Maelstrom", "DrownedFleet" },
		Weapon = "Harpoon",
		Rank = 2,
	},
} :: { [string]: Enemy }

Moves.Encounters = {
	-- Ordered from easiest to hardest, so a voyage can pick early entries on Sea 1 and later ones on Sea 3.
	Battle = {
		{ "Deckhand", "Deckhand" },
		{ "Deckhand", "Swordsman" },
		{ "Deckhand", "Gunner" },
		{ "Deckhand", "Swordsman", "Gunner" },
		{ "Bomber", "Deckhand", "Deckhand" },
		{ "Swordsman", "Swordsman", "Gunner" },
		{ "Brute", "Gunner" },
		{ "Harpooner", "Bomber", "Deckhand" },
		{ "Brute", "Swordsman", "Bomber" },
		{ "Harpooner", "Harpooner", "Gunner" },
		{ "Brute", "Brute", "Bomber" },
		{ "Brute", "Harpooner", "Gunner", "Bomber" },
	},
	Elite = {
		{ "Duelist" },
		{ "Cannoneer" },
		{ "Duelist", "Gunner" },
		{ "Cannoneer", "Deckhand", "Deckhand" },
		{ "Duelist", "Cannoneer" },
	},
	Boss = {
		Sea1 = { "CaptainRedtide", "Deckhand", "Deckhand" },
		Sea2 = { "CommodoreVane", "Swordsman", "Gunner" },
		Sea3 = { "StormAdmiral", "Harpooner", "Bomber" },
	},
}

------------------------------------------------------------------------------------------------------------------
-- Afflictions and virtues (D5): number changes only. They never take a command away from the player.
------------------------------------------------------------------------------------------------------------------

export type Condition = {
	Name: string,
	Kind: string, -- "Affliction" or "Virtue"
	Summary: string, -- what it does, shown to the player
	Line: string, -- narrator line for the breaking-point close-up
	DamageDealt: number?, -- multiplies the player's attack damage
	DamageTaken: number?, -- multiplies damage taken in the dodge box
	SoulSpeed: number?, -- multiplies soul speed in the dodge box
	SoulRadius: number?, -- multiplies the soul's hitbox
	HealTaken: number?, -- multiplies healing received
	ResolveRelief: number?, -- multiplies Resolve relief (negative Resolve changes)
	NoBrace: boolean?, -- Brace is disabled
}

Moves.Conditions = {
	Panicked = {
		Name = "Panicked",
		Kind = "Affliction",
		Summary = "Soul moves 15% faster, but is 10% easier to hit.",
		Line = "The hands shake, the feet run ahead, and the mind follows at a distance.",
		SoulSpeed = 1.15,
		SoulRadius = 1.1,
	},
	Reckless = {
		Name = "Reckless",
		Kind = "Affliction",
		Summary = "Attacks deal 20% more damage, but Brace is disabled.",
		Line = "Caution goes over the side. It does not float.",
		DamageDealt = 1.2,
		NoBrace = true,
	},
	Paranoid = {
		Name = "Paranoid",
		Kind = "Affliction",
		Summary = "Healing is halved, but the soul is 12% harder to hit.",
		Line = "Every friendly hand looks like it is holding a knife.",
		HealTaken = 0.5,
		SoulRadius = 0.88,
	},
	Hopeless = {
		Name = "Hopeless",
		Kind = "Affliction",
		Summary = "Resolve recovers half as fast, but hits hurt 10% less.",
		Line = "The horizon is only more water. It always was.",
		ResolveRelief = 0.5,
		DamageTaken = 0.9,
	},
	FiredUp = {
		Name = "Fired Up",
		Kind = "Virtue",
		Summary = "Attacks deal 15% more damage.",
		Line = "The fear burns off like morning fog, and something brighter stands underneath.",
		DamageDealt = 1.15,
	},
	Steadfast = {
		Name = "Steadfast",
		Kind = "Virtue",
		Summary = "Hits hurt 20% less.",
		Line = "The storm leans on them. They lean back.",
		DamageTaken = 0.8,
	},
	ClearEyed = {
		Name = "Clear-Eyed",
		Kind = "Virtue",
		Summary = "The soul is 15% harder to hit.",
		Line = "For one cold moment every blade moves slowly, and the way through is plain.",
		SoulRadius = 0.85,
	},
} :: { [string]: Condition }
Moves.Afflictions = { "Panicked", "Reckless", "Paranoid", "Hopeless" }
Moves.Virtues = { "FiredUp", "Steadfast", "ClearEyed" }

------------------------------------------------------------------------------------------------------------------
-- Fail close-ups (D4): the stamped words and narrator lines.
------------------------------------------------------------------------------------------------------------------

export type CloseUpText = { Stamps: { string }, Lines: { string } }

Moves.CloseUps = {
	FailDuration = 1.8, -- seconds
	BreakDuration = 3.6,
	MaxPerRound = 2,

	-- A failed attack minigame, by the weapon style of the move.
	Attack = {
		Sword = {
			Stamps = { "DULL BLADE", "WIDE SWING" },
			Lines = {
				"The blade finds the deck and stays there. The deck does not mind.",
				"A fine swing. It will be remembered by no one it touched.",
			},
		},
		Gun = {
			Stamps = { "MISFIRE", "DAMP POWDER" },
			Lines = {
				"A dry click, and all the time in the world to regret it.",
				"The shot goes wide. Somewhere, a gull pays for it.",
			},
		},
		Fist = {
			Stamps = { "WHIFFED", "OFF BEAT" },
			Lines = {
				"A fist thrown with conviction at nothing in particular.",
				"The barrel never saw it coming. The enemy did.",
			},
		},
	} :: { [string]: CloseUpText },

	-- A badly failed dodge: one enemy attack took a quarter of MaxHP or more.
	Dodge = {
		Stamps = { "CUT DOWN", "BATTERED", "CAUGHT OUT" },
		Lines = {
			"Steel has a way of finding those who stand still to think.",
			"Pain is a patient teacher, and class is in session.",
			"The sea does not keep count. The surgeon will.",
		},
	} :: CloseUpText,

	-- Knocked out.
	Down = {
		Stamps = { "DOWN" },
		Lines = {
			"The deck rises to meet them, as it always meant to.",
			"Even the stubborn fall. The stubborn only take longer.",
		},
	} :: CloseUpText,
}

return Moves
