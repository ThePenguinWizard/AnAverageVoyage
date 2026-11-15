--!strict
-- The narrated events for Event islands, and the short texts for Rest, Treasure and Port islands.
-- Server only: the client is sent the title, the text, the choice labels, costs and odds, never the outcomes.
--
-- Writing rules: second person, a sincere sea adventure with some dry humour, for teens and adults, set in the
-- game's own pirate world (no names or terms from any existing series).
--
-- A choice with Odds is a gamble: the odds are shown to the player, Success happens on a win and Fail on a loss.
-- A choice without Odds always gives Success. The LAST choice of every event must be safe (no odds, no fight):
-- it is what happens if nobody answers in time.

export type Fight = {
	Kind: string, -- "Battle" or "Elite"
	Enemies: { string }?, -- enemy ids from Shared.Combat.Moves; nil picks a normal encounter of that kind
}

export type Outcome = {
	Text: string,
	Gold: { number }?, -- { least, most }; negative numbers take gold away (never below 0)
	Item: number?, -- gives one item of this loot quality (1 common, 2 good, 3 fine)
	Heal: number?, -- share of MaxHP restored
	Resolve: number?, -- stress change; negative relieves it
	Fight: Fight?, -- starts a fight after the card is closed
}

export type Choice = {
	Label: string,
	Cost: number?, -- gold paid up front; the choice is refused if the player cannot afford it
	Odds: number?, -- chance of Success, 0-1
	Success: Outcome,
	Fail: Outcome?,
}

export type Event = {
	Id: string,
	Title: string,
	Text: string,
	Choices: { Choice },
}

local Events = {}

Events.List = {
	{
		Id = "KnockingBarrel",
		Title = "The Knocking Barrel",
		Text = "A barrel drifts alongside, lashed shut with good rope. Something inside it knocks, twice, politely.",
		Choices = {
			{
				Label = "Haul it aboard and pry it open",
				Odds = 0.6,
				Success = {
					Text = "Salt pork, a dry purse, and a ship's cat that has plainly been captain of this barrel for some time. It accepts your surrender.",
					Gold = { 20, 35 },
					Item = 1,
				},
				Fail = {
					Text = "The eel inside was not knocking to be let out. It was knocking to be left alone. You respect that now.",
					Resolve = 12,
				},
			},
			{
				Label = "Knock back",
				Success = {
					Text = "You knock twice. It knocks three times. Nobody is sure who won, but the crew sleeps oddly well tonight.",
					Resolve = -10,
				},
			},
			{
				Label = "Let it drift",
				Success = { Text = "It bobs away astern, knocking at nobody in particular." },
			},
		},
	},
	{
		Id = "FogBell",
		Title = "A Bell in the Fog",
		Text = "Fog closes in, thick as wool. Somewhere ahead a ship's bell tolls, slow and even, though no hull shows and nobody hails you.",
		Choices = {
			{
				Label = "Steer for the bell",
				Odds = 0.5,
				Success = {
					Text = "A wreck, hard on a reef, her bell swinging with the swell. Her strongbox has no further use for her.",
					Gold = { 30, 50 },
					Item = 2,
				},
				Fail = {
					Text = "The bell hangs from a raft, and the raft belongs to people with cutlasses. They seem pleased you could make it.",
					Fight = { Kind = "Battle" },
				},
			},
			{
				Label = "Drop anchor until it lifts",
				Success = {
					Text = "You wait. By noon the fog is gone, and the bell with it. Nobody mentions it at supper.",
					Heal = 0.15,
					Resolve = -5,
				},
			},
		},
	},
	{
		Id = "TollCutter",
		Title = "The Toll Cutter",
		Text = "A Navy cutter crosses your bow and runs up a flag you don't recognise. Her lieutenant calls it a passage levy. He has a ledger and a look of terrible patience.",
		Choices = {
			{
				Label = "Argue the paperwork",
				Odds = 0.45,
				Success = {
					Text = "You ask to see the statute. There is a long pause. He remembers an urgent appointment elsewhere and leaves you a pamphlet on maritime courtesy.",
					Resolve = -15,
				},
				Fail = {
					Text = "He has the statute. He has all the statutes. The levy is now a fine.",
					Gold = { -40, -40 },
					Resolve = 10,
				},
			},
			{
				Label = "Run out the guns",
				Success = {
					Text = "The lieutenant sighs, closes the ledger, and draws steel.",
					Fight = { Kind = "Battle", Enemies = { "Swordsman", "Gunner" } },
				},
			},
			{
				Label = "Pay the levy",
				Cost = 25,
				Success = {
					Text = "He counts it twice, writes you a receipt, and wishes you a lawful day. The receipt is very nicely lettered.",
					Resolve = -5,
				},
			},
		},
	},
	{
		Id = "HermitStew",
		Title = "The Hermit's Stew",
		Text = "On a rock the size of a supper table sit a hermit, a pot and a small fire. He waves you over as if he has been expecting you since Tuesday.",
		Choices = {
			{
				Label = "Share the stew",
				Odds = 0.75,
				Success = {
					Text = "It is hot, peppery and very good. He won't say what is in it. You find you don't need to know.",
					Heal = 0.4,
					Resolve = -10,
				},
				Fail = {
					Text = "It was not stew. He is as surprised as you are.",
					Resolve = 15,
				},
			},
			{
				Label = "Buy something from his coat",
				Cost = 15,
				Success = {
					Text = "He produces it with great ceremony and calls it lucky. It may even be useful.",
					Item = 2,
				},
			},
			{
				Label = "Wave and sail on",
				Success = { Text = "He waves back with the ladle. The smell follows you for a mile." },
			},
		},
	},
	{
		Id = "MessageGull",
		Title = "The Message Gull",
		Text = "A gull lands on the rail with a waterlogged letter tied to its leg. Most of the ink has run, but you can make out a sketch of an islet and the words 'under the split rock'.",
		Choices = {
			{
				Label = "Follow the directions",
				Odds = 0.55,
				Success = {
					Text = "The split rock is real, and so is the chest beneath it. Someone's bad luck with gulls is your good afternoon.",
					Gold = { 35, 60 },
				},
				Fail = {
					Text = "You dig under four split rocks. The fifth has a crab under it, and the crab has opinions.",
					Resolve = 12,
				},
			},
			{
				Label = "Feed the gull and keep the letter",
				Success = {
					Text = "The gull stays for a biscuit, then for the afternoon. The crew names it. Morale is unreasonably high.",
					Resolve = -12,
				},
			},
		},
	},
	{
		Id = "Becalmed",
		Title = "Becalmed",
		Text = "The wind dies at dawn and does not come back. The sails hang like laundry. By the second day the crew has started inventing games, which is always a warning.",
		Choices = {
			{
				Label = "Whistle for a wind",
				Odds = 0.5,
				Success = {
					Text = "Every sailor knows you never whistle at sea. Today every sailor is wrong. A fair breeze fills the canvas inside the hour.",
					Heal = 0.1,
					Resolve = -20,
				},
				Fail = {
					Text = "You get wind. You get all of it at once, from the wrong side, with hail.",
					Resolve = 18,
				},
			},
			{
				Label = "Break out the sweeps and row",
				Success = {
					Text = "Slow, blistering work, but you fish a drifting crate out of the flat water on the way. Rowing has its compensations.",
					Gold = { 15, 25 },
					Resolve = 8,
				},
			},
			{
				Label = "Hold a deck tournament",
				Success = {
					Text = "Arm wrestling, knot racing and a pie contest with no pies. Nobody wins. Everybody feels better.",
					Resolve = -15,
				},
			},
		},
	},
	{
		Id = "SandbarDuellist",
		Title = "The Sandbar Duellist",
		Text = "A sandbar barely clears the tide, and on it stands a Navy fencing master with his coat folded beside him. 'On leave,' he calls. 'Bored. Would anyone care for a bout?'",
		Choices = {
			{
				Label = "Accept the bout",
				Success = {
					Text = "He salutes, smiles, and stops looking bored.",
					Fight = { Kind = "Elite", Enemies = { "Duelist" } },
				},
			},
			{
				Label = "Offer him dice instead",
				Odds = 0.5,
				Success = {
					Text = "Dice, it turns out, are not his weapon. He pays up like a gentleman.",
					Gold = { 25, 40 },
				},
				Fail = {
					Text = "Dice, it turns out, are also his weapon.",
					Gold = { -20, -20 },
				},
			},
			{
				Label = "Decline, and toss him a biscuit",
				Success = {
					Text = "He catches it on the point of his blade without looking. You sail on, quietly glad you declined.",
					Resolve = -5,
				},
			},
		},
	},
	{
		Id = "WishingMast",
		Title = "The Wishing Mast",
		Text = "A drowned mast stands out of the shallows, studded from top to waterline with coins. Sailors nail one on for luck. It has clearly been a lucky place for a long while.",
		Choices = {
			{
				Label = "Pry a few coins loose",
				Odds = 0.6,
				Success = {
					Text = "They come away easily. Too easily, the bosun says, but the bosun says that about everything.",
					Gold = { 30, 45 },
				},
				Fail = {
					Text = "The mast groans, long and low, in a way that sounds a little like your name. You put the coins back. Most of them.",
					Gold = { 5, 5 },
					Resolve = 20,
				},
			},
			{
				Label = "Nail on a coin of your own",
				Cost = 10,
				Success = {
					Text = "The coin goes in clean on the first blow. Nothing happens, in the particular way that feels as if something did.",
					Resolve = -20,
				},
			},
			{
				Label = "Leave it be",
				Success = { Text = "You tip your hat to the mast, feel slightly foolish, and sail on." },
			},
		},
	},
	{
		Id = "FriendlyWager",
		Title = "A Friendly Wager",
		Text = "Another crew pulls alongside, all grins and patched sails. Their captain proposes a race around the next rock, loser pays. Her ship looks fast. So does her smile.",
		Choices = {
			{
				Label = "Take the race",
				Cost = 20,
				Odds = 0.5,
				Success = {
					Text = "You round the rock half a length ahead. She pays without complaint and asks who trims your sails.",
					Gold = { 45, 55 },
				},
				Fail = {
					Text = "She wins by a full length and waves the whole way round. It is hard to stay angry. You manage.",
					Resolve = 8,
				},
			},
			{
				Label = "Board them while they're laughing",
				Success = {
					Text = "The grins vanish. The cutlasses do not.",
					Fight = { Kind = "Battle" },
				},
			},
			{
				Label = "Decline with dignity",
				Success = { Text = "'Wise,' she says, and is over the horizon before you have finished feeling wise." },
			},
		},
	},
} :: { Event }

-- Rest islands: heal part of HP and relieve Resolve.
Events.Rest = {
	Title = "A Quiet Cove",
	HealShare = 0.35,
	Resolve = -30,
	Texts = {
		"You drop anchor in a cove with clear water and no opinions. The crew swims, sleeps, and argues gently about nothing.",
		"A sandy inlet, a driftwood fire, and a night with nobody on watch who minds being on watch. You wake up feeling almost respectable.",
		"Someone finds a freshwater spring behind the beach. By evening every wound is washed, every shirt is drying, and the cook has stopped muttering.",
	},
}

-- Treasure islands: gold and one good item.
Events.Treasure = {
	Title = "Buried Fortune",
	Gold = { 30, 50 },
	Item = 2,
	Texts = {
		"The chest is exactly where the old chart said it would be, which has never once happened before. The crew digs in suspicious silence until the lid comes up.",
		"A wreck lies broken across the reef with her hold open to the sky. You take what the sea has not, and thank her politely.",
		"Under a cairn of white stones you find a strongbox and a note that reads 'well done'. No signature. The gold is real enough.",
	},
}

-- Ports: full restore before the boss.
Events.Port = {
	Title = "Safe Harbour",
	Texts = {
		"A harbour town with lanterns on the quay and a tavern that asks no questions. Hot food, clean bandages and a real bed. Tomorrow can wait until tomorrow.",
		"The harbourmaster looks at your flag, then at your crew, then decides not to have seen either. You sleep ashore, eat twice, and mend everything that can be mended.",
	},
}

return Events
