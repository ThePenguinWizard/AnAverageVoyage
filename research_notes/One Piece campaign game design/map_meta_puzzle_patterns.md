# Run/Map Progression, Meta-Progression, and Puzzle Design Patterns (Inscryption, Darkest Dungeon, Slay the Spire, and related roguelites), for a One Piece Roblox co-op RPG

Scope note: this file covers the structure around combat: the map, the run, the meta loop, and puzzles. Moment-to-moment combat is covered by another researcher. Several primary wikis (inscryption.fandom.com, inscryption.wiki.gg, primagames, techraptor, thinkygames) blocked automated fetches (HTTP 401/402/403). Where a detail comes only from a search-result summary rather than a fetched page, it is marked "(search summary)". Things I believe from general knowledge but could not verify this session are kept in the Gaps sections, labelled "unverified".

---

## 1. Inscryption: Act 1 map, nodes, diegetic presentation, cabin puzzles, Acts 2/3, meta framing, deathcards

### Takeaway
Inscryption Act 1 is a Slay-the-Spire-style branching node map (4 maps: 3 bosses, then Leshy), but it is presented physically as a board game on Leshy's table, and the player can stand up between turns to solve escape-room puzzles in the cabin. Those puzzles carry persistent progress across failed runs. Mullins said this was a deliberate way to give a roguelike persistent progression. Deathcards turn a failed run into content for future runs. Acts 2 and 3 swap the node map for a Pokémon-like overworld and an Isaac-like room grid with checkpoints, which shows the same card core can sit under very different map shells.

### Cited Findings
**Act 1 run structure**
- Act 1 is "a roguelike deck-builder with four randomly generated maps, similar to Slay the Spire." Nodes offer battles, card changes, or consumable items. The first three maps end in bosses and the fourth ends with Leshy. — [Wikipedia: Inscryption](https://en.wikipedia.org/wiki/Inscryption)
- Lives are candles. Per Wikipedia, losing twice on a map, or once to a boss, ends the run and turns the player character into a "death card" that can reappear in later runs. — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption). A beginner's guide gives the same 2-candle model: the stick has two candles, and when the second is snuffed out the run restarts from the beginning. — [PC Invasion beginner's guide](https://pcinvasion.com/inscryption-beginners-guide-card-upgrades-vendors/2) (search summary)
- The map is a branching path. You move bottom to top and pick one option at each step. — [Prima Games: Act 1 map symbols](https://primagames.com/gaming/inscryption-map-symbols-act-1-guide) (search summary)
- Node types (search summary across guides; the fetched Ludo guide confirms Campfire, Trapper, Mycologist, Wood Carver, and Trader):
  - **Regular battle**: skull icon, a normal card fight against Leshy.
  - **Totem battle**: the opponent's cards get a totem buff.
  - **Campfire**: upgrade a card's stats "at a risk" (repeated use can lose the card).
  - **Mycologists**: fuse two identical cards into one stronger card.
  - **Trader**: exchange pelts for cards.
  - **Trapper**: buy pelts with teeth (currency).
  - **Wood Carver**: grants totem pieces, which the player assembles into their own buff totem.
  - **Deathcard node**: lets you pick a Deathcard. One guide says it may only appear after about 5 deaths.
  - **Boss**: a large unique icon at the top of each map.
  - Sources: [Ludo.guide map progression](https://www.ludo.guide/guide/inscryption/overview/map-progression-events); [Prima Games](https://primagames.com/gaming/inscryption-map-symbols-act-1-guide); [Kosgames Act 1 map icons](https://kosgames.com/inscryption-act1-map-icons-for-new-players-9441/)
- In Kaycee's Mod (the endless Act 1 mode), Mycologists cannot be reached on Map 1. This is a node-gating rule that keeps power spikes out of the first map. It is a mod-specific note. — [Kaycee's Mod general info: map nodes](https://sites.google.com/view/kaycees-mod-general-info/tips/map-nodes)
- Battles use a 3x4 lane grid (3x5 in Act III). Damage tips a scale, and you win by tipping it by 5 "teeth". — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)

**Cabin escape-room puzzles and how they interleave with runs**
- "Between battles, the player explores the cabin and solves escape-room-style puzzles." — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)
- Mullins on why: "Persistent progression is a common feature of modern roguelikes; despite each run being a fresh start… I think the cabin puzzles were a way of facilitating this persistent progression." He also said the puzzles suited the first-person view of the card game. — [Game Developer: How a game jam on "sacrifices" became Inscryption](https://www.gamedeveloper.com/design/how-game-jam-sacrifices-became-inscryption)
- Mullins: "much of what continues to draw the player into Inscryption exists outside of the rules of the game," meaning the mysterious antagonist, the strange cabin fixtures, and the talking cards. — [Game Developer](https://www.gamedeveloper.com/design/how-game-jam-sacrifices-became-inscryption)
- The puzzles are gated by run progress:
  - **Safe**: the code (2-7-3) is written in red ink beside the Mighty Leap entry in the rulebook, and that entry only becomes available after a few games. Opening the safe gives the Stinkbug card and a key. Entering the code before discovering it just gives "a clump of meat". — [GameSpot: cabin safe guide](https://www.gamespot.com/articles/inscryption-cabin-safe-guide-where-to-find-the-safe-combination/1100-6497509/) (search summary)
  - **Sliding puzzles**: the key opens a cabinet holding 4 sliding puzzles. — [GamesRadar: sliding puzzle solution](https://www.gamesradar.com/inscryption-sliding-puzzle-solution) (search summary)
  - **Cuckoo clock**: it sits behind the player's seat, has 3 knobs (one per hand), and has the most stages of any cabin puzzle. Most other puzzles must be done first. Its reward (a ring) is needed for the endgame. — [GameSpot: cuckoo clock guide](https://gamespot.com/articles/inscryption-cuckoo-clock-guide-how-to-solve-the-clock-puzzle/1100-6497524/) (search summary)
  - **Drawers**: 4 drawers hold rewards. The first is opened by moving all the notches to the attack row and ringing the bell, which teaches combat UI through a puzzle. — (search summary across [Prima cabin guide](https://primagames.com/gaming/inscryption-cabin-puzzle-guide-cuckoo-clock-painting) and related guides)
  - **Caged wolf**: a figurine next to the skull that is critical for escaping the cabin. — [PC Invasion: caged wolf and eyeballs](https://pcinvasion.com/inscryption-cabin-puzzle-guide-cuckoo-clock-painting/4) (search summary)

**Deathcards (failure turned into content)**
- When a run is lost, the player is shown three random cards from their deck. Deathcards, talking cards, and the Caged Wolf are excluded. The 1st pick sets the **cost** (a pelt makes it free), the 2nd sets **power/health** (variable stats like Ants copy over), and the 3rd sets **sigils** (all sigils copy). The player names the card, and it can appear in future runs. — [Inscryption Wiki: Deathcard](https://inscryption.fandom.com/wiki/Deathcard) (search summary); [Prima: best cards, deathcards, sigils](https://primagames.com/gaming/inscryption-best-cards-deathcards-sigils) (search summary)
- In Act III, enemies can use death cards from earlier runs. — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)

**Acts 2 and 3: the map shell changes**
- **Act II**: a top-down pixel-art RPG "similar to Pokémon". The player collects card packs and challenges four Scrybes (gym-leader-like bosses with distinct themes). Losing has no penalty. — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)
- **Act III**: P03's factory. It is a roguelike deckbuilder with rooms in a grid "similar to The Binding of Isaac", and battles happen between rooms. Losing resets the player to the last checkpoint (antenna towers) instead of ending the game. — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)

**Meta "game within a game" framing**
- The game is framed as found footage recorded by Luke Carder ("The Lucky Carder"), a card-game YouTuber. The ending involves an in-game "OLD_DATA" file. An ARG expands the story. — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)
- It began as a Ludum Dare 43 (2018) 48-hour jam game on the theme "Sacrifices Must Be Made". The core rules (tug-of-war scale, sacrifice cost, lanes) were built in the jam. — [Game Developer](https://www.gamedeveloper.com/design/how-game-jam-sacrifices-became-inscryption); [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)
- Legibility lesson: because of the low render resolution, Mullins dropped all card text except the name and used sigil icons instead. — [Game Developer](https://www.gamedeveloper.com/design/how-game-jam-sacrifices-became-inscryption)
- Kaycee's Mod (beta December 2021, full release March 17, 2022) makes Act 1 endlessly replayable with unlockable cards and starting challenges. The base game sold over 1M copies by January 2022. It won GDC Awards Game of the Year and the IGF Seumas McNally Grand Prize, the first game to win both. — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)
- Mullins gave a GDC 2022 Independent Games Summit post-mortem, "Sacrifices Were Made: The 'Inscryption' Post-Mortem". — [GDC Vault](https://gdcvault.com/play/1027609/Independent-Games-Summit-Sacrifices-Were)

### Inferences
- **Diegetic map = the strongest borrowable idea.** Leshy's board, with a figurine moving across a hand-drawn map, maps directly onto One Piece. The sea chart can be spread on the ship's galley or navigation table, with a Going-Merry or Thousand-Sunny-style figurine moving between island tokens. The "game master" role (Leshy) could be an in-world narrator, such as a mysterious storyteller in a bar or a Den Den Mushi voice. That narrator can comment on choices, which is cheap content that adds personality.
- **Cabin = the ship between islands.** Inscryption puts puzzles in the space between battles and keeps their progress when a run fails. For a 20–40 min Roblox session, ship-interior puzzles (Poneglyph rubbings, a locked captain's chest, a log book with a hidden code) can be open while the ship "sails" (during map travel or loading), and they persist across failed runs. This gives players who lose a run something permanent: "we died, but we decoded another Poneglyph line."
- **Gate puzzle clues behind run events** (as the safe code appears in the rulebook only after Mighty Leap is seen). This ties the two loops together: you need to reach Island X in a run to see a clue that solves a ship puzzle, which unlocks a new starting item.
- **Deathcard → "Wanted Poster" / "Fallen Crew" system.** When a party wipes, the players compose a bounty poster (one player picks the face/visual, one picks the stat line, one picks the ability), and it reappears in later runs or in other servers' runs as a rival pirate or Marine. This also gives multiplayer a shared creative moment at the end of a failed run, and it suits a 3–4 player party splitting 3 picks.
- **Two-life candle model** (2 losses per map, or 1 to a boss) is simpler and more forgiving than permadeath. It suits short sessions.
- **Act 2/3 lesson**: the same combat core can sit under a node map (Act 1), a free-roam overworld (Act 2), or a room grid with checkpoints (Act 3). A One Piece game could vary the shell per saga: an open-sea node chart for East Blue, a Grand Line Log-Pose chain, and room-grid "dungeon islands" like Enies Lobby or Thriller Bark.
- **Pitfall**: Inscryption's cabin puzzles are one-time solves. In a multiplayer Roblox game, the first player to look up a solution spoils it for everyone else. Randomize per-server or per-crew parameters (codes, symbol orders) where possible.

### Gaps
- I could not fetch any Inscryption wiki page directly (fandom 402, wiki.gg 401), so exact node counts per map, node weightings, and region names are unverified. **Unverified recollection** (check before use): the three Act 1 maps are Woodlands, Wetlands, and Snow Line; the bosses are the Prospector, the Angler, and the Trapper/Trader, then Leshy; card-choice nodes come in variants (random 3-choose-1, cost-based, tribe-based); other nodes include the Bone Lord (offers bones for a card), Mysterious Stones (sacrifice altar), and boulder/backpack item nodes.
- The GDC talk's contents (slides or transcript) were not accessible, so Mullins's direct statements on map design are missing.
- Full cabin puzzle list (paintings, Ouroboros, film roll, Squirrel head) and their exact rewards were not captured from a primary source (the guides returned 403).

---

## 2. Comparison map designs: Slay the Spire (1 and 2), Monster Train, Darkest Dungeon 2, An Average Campaign

### Takeaway
Slay the Spire's map is a small, fully generated DAG of 7 columns by 15 rows, with about 6 intertwined paths. It is fully visible and has hard placement rules (no early elites or rests, treasure mid-act, rest before the boss, branches must lead to different node types), so every fork is a real risk/reward choice. Monster Train shrinks this to a binary left/right choice between rings. DD2 adds road hazards and fog-of-war with scouting. An Average Campaign, the Roblox reference, uses a "pick 1 of 3 starred encounters" model, which is simpler and better for multiplayer.

### Cited Findings
**Slay the Spire (1)**
- 15 floors per act plus the boss. The map is a DAG generated bottom-up: paths branch and merge but never go down. It has 6 starting nodes and 1 boss at the top. Paths are visible from the start of the act. — [Game mechanics wiki: StS map and nodes](https://saschb2b.github.io/game-mechanics/games/slay-the-spire/map-and-nodes)
- Generation uses a 7x15 grid. The generator picks a Floor-1 room and connects it to one of the 3 nearest rooms on the next floor, floor by floor, repeated several times (the fetched summary said "seven generations"; the 6-starting-node figure above suggests 6 paths, so treat the exact count as uncertain). Paths may not cross. The first two starting rooms must differ, so there are always at least 2 starts. Rooms with no path are pruned. — [Kosgames: StS map generation guide](https://kosgames.com/slay-the-spire-map-generation-guide-26769/)
- Fixed floors: Floor 1 is all Monster, Floor 9 is all Treasure, and Floor 15 is all Rest Site (before the boss). — [Kosgames](https://kosgames.com/slay-the-spire-map-generation-guide-26769/). **Conflict:** the game-mechanics wiki says "Floor 6 is always a Treasure, Floor 9 is always a Rest Site, first 4 floors never have an Elite" — [saschb2b](https://saschb2b.github.io/game-mechanics/games/slay-the-spire/map-and-nodes). The Kosgames version (treasure F9, rest F15) matches the widely reported algorithm; I believe saschb2b is in error but could not verify against the source code.
- Override rules: (1) no Elite or Rest Site below Floor 6; (2) Elite, Merchant, and Rest Site cannot connect directly to another of the same type; (3) a room with 2 or more outgoing paths must lead to rooms of different types; (4) no Rest Site on Floor 14 (since 15 is all rest). The boss is chosen randomly from 3 for the act and every Floor-15 room connects to it. — [Kosgames](https://kosgames.com/slay-the-spire-map-generation-guide-26769/)
- Probabilities: at higher Ascension, Elite chance rises from 8% to 16% and Monster falls from 53% to 45%. Other percentages were only in images. — [Kosgames](https://kosgames.com/slay-the-spire-map-generation-guide-26769/)
- Rewards per node type:
  - **Monster**: 10–20 gold plus a 3-card draft (pick 1 or skip).
  - **Elite**: always a relic, 25–35 gold, and a card draft.
  - **Rest**: heal 30% max HP or upgrade a card.
  - **Shop**: also offers card removal.
  - **Event "?"**: can resolve as an Event, Monster, Shop, or Treasure. The event chance grows the longer it has been since the last event, then resets.
  - **Boss**: choice of rare cards plus boss relics.
  - Source: [saschb2b](https://saschb2b.github.io/game-mechanics/games/slay-the-spire/map-and-nodes)

**Slay the Spire 2 (co-op relevant)**
- A third-party patch guide says StS2's map is cleaned up after generation. If generation leaves two empty edge columns on one side, the map shifts back toward the center. — [StS2 patch guide (fan site)](https://sts2-calculator.pages.dev/v101-map-system-changes) (search summary; low-authority source)
- Co-op (up to 4 players):
  - The party follows one path. At each fork every player votes, and a **roulette-style randomizer picks the winner, weighted by votes**.
  - Players can **draw on the map**, and the markings persist for the act.
  - Shared: path and encounters.
  - Individual: deck, gold, card rewards, and merchant inventory (each player sees different stock).
  - Rest sites are per player, with no competition for slots. The "Mend" option heals a teammate.
  - Chest relics: each player is offered one, and duplicate claims are settled by an automatic rock-paper-scissors.
  - A player at 0 HP sits out the rest of the fight and returns at 1 HP.
  - Saves are tied to the host and can be resumed later.
  - Source: [AllThings.How: StS2 co-op rules](https://allthings.how/slay-the-spire-2-co-op-multiplayer-every-mechanic-and-rule-explained/)

**Monster Train**
- A run covers 9 rings ("Circles") of Hell and 3 bosses. — [Boss Rush review](https://bossrush.net/2023/03/05/game-review-race-through-rings-of-hell-in-monster-train/)
- Between battles the route forks left or right, and the locations offer different benefits: upgrade your champion, recruit units, upgrade cards, gain passive bonuses, or duplicate a card. — [Monster Train fan wiki](https://monster-train.fandom.com/wiki/Monster_Train_Wiki?oldid=9250) (search summary). A patch note fixed the "Divine Hoard" reward so it shows the same artifacts whether on the left or right path. — (search summary, same wiki)
- There is one Merchant "in between the tracks" of Circle 8, reachable from either route. — [SuperCheats: where to find merchants](https://www.supercheats.com/monster-train-walkthrough-guide/where-to-find-merchants)
- Merchant of Trinkets: always 3 artifacts at 175–225 gold. Inventory can be re-rolled once per merchant for 50 gold. — [Gameplay.tips: merchant contents](https://gameplay.tips/guides/7842-monster-train.html)
- Before battles, the player can accept a harder "Trial" modifier for extra rewards. — [SuperCheats tips](https://www.supercheats.com/monster-train-cheats-tips) (search summary)

**Darkest Dungeon 2 (road map)**
- Each region is made of nodes linked by roads. There are 5 road types: Combat (a road battle), Hazardous (−1 Armor), Rough (−1 Wheel), Oblivion Tear (+1 Loathing), and Safe. Taking a Hazardous or Rough road without the matching stagecoach item triggers an ambush. Debris on roads can drop loot. — [DD wiki: Locations/Roads](https://darkestdungeon.wiki.gg/wiki/Roads)
- **Fog of war:** nodes and roads are either hidden or scouted. The Lair is always scouted. Visiting a Watchtower reveals all later locations in the region. Region modifiers change branching: "Maze" gives +200% path choices and "Trench Run" gives −50%. — [DD wiki: Roads](https://darkestdungeon.wiki.gg/wiki/Roads)
- Each main region ends with Oblivion's Rampart followed by an Inn. Node types include:
  - Shrine of Reflection
  - Hoarder
  - Field Hospital
  - Desperate Few
  - Resistance Encounter
  - Oblivion's Ingress
  - Creature Den
  - Oasis
  - Watchtower
  - Academic's Cache and Academic's Study
  - Chirurgeon's Table
  - Source: [DD wiki: Roads](https://darkestdungeon.wiki.gg/wiki/Roads)
- **Region goals** (one per region) give optional objectives such as "Fight in 2 or less Resistance Encounters", "Fight in 4 or more Road Fights", or "Keep the Flame above 40". They reward candles, mastery, trinkets, or items. — [DD wiki: Roads](https://darkestdungeon.wiki.gg/wiki/Roads)

**An Average Campaign (Roblox reference)**
- The required route is Forest (8 areas, ending at The Giant), then Dungeon (12 areas, ending at Bone Drake). The optional branches are hidden behind specific encounters: Dwarven Mines (7 areas, via an "Elven Camp" encounter in the Forest) and Sewer (5 areas, via an "Ominous Manhole" encounter in the Dungeon). — [An Average Campaign community wiki](https://an-average-campaign.pages.dev/)
- After each combat the party goes to camp, then picks 1 of 3 random encounters, each marked with difficulty stars (more stars means harder fights and often better rewards). Between encounters the party heals the higher of 10 HP or 15% max HP. Paid revive events exist: an Altar (250 gold, full revive and heal) and a Necromancer (100 gold, partial revive). — [AAC wiki](https://an-average-campaign.pages.dev/)
- It is designed for 3–4 players, supports 1–5, and is "deliberately difficult" with no in-game tutorial. — [AAC wiki](https://an-average-campaign.pages.dev/); [BloxInformer](https://bloxinformer.com/wikis/an-average-campaign)

### Inferences
- **Recommended One Piece map skeleton (per "saga" act).** About 8–10 rows by 5 columns (smaller than StS's 15x7, to fit 20–40 min). Fixed rows:
  - Row 1: always a fight (a Marine patrol or a pirate skirmish).
  - Mid-act: always a "Treasure" island.
  - Last row before the boss: always a "Port / Floating Restaurant" (rest or upgrade, the Baratie as campfire).
  - Copy StS's rules: no elite or rest before about 40% of the act; no back-to-back elite, shop, or rest; and every fork must lead to different node types. The last rule is what makes each choice meaningful.
- **Elite = "Bounty Target" island** (visible bounty amount gives a clear risk/reward signal, as StS elites always drop a relic).
- **Log Pose as a map mechanic.** Normally you can only see the next 1–2 rows (fog, DD2-style). An "Eternal Pose" item, like DD2's Watchtower, reveals the whole act or lets you lock in a destination. Scouting is a strong co-op role: the navigator player can spend a resource to reveal nodes.
- **DD2 "roads" → sea lanes.** Edges between islands carry hazards: a storm (hull damage, like DD2's Armor/Wheel), a Sea King (combat), a calm belt (lose turns or food), or a whirlpool. A ship item negates each hazard. This adds a provisioning decision to the map without adding nodes.
- **Hidden branch islands** (AAC's Elven Camp → Mines) are ideal for One Piece's optional arcs. For example, an event on a normal island reveals a route to Skypiea, which leads to a bonus mini-act with its own boss.
- **Monster Train's binary fork** is the simplest co-op-friendly structure: one vote per ring, two clearly labelled reward bundles. A good fallback if the full node map tests as too slow for groups.

### Gaps
- Exact StS node probabilities (shop, rest, event, treasure) were only in images. The exact path count (6 vs 7) and the floor of the treasure/rest rows conflict between sources.
- Monster Train: I could not confirm whether both forks' contents are visible before choosing, or the exact per-ring node layout.
- DD2: node and fight counts per region, and the Flame mechanic's exact rules (max Flame, drain per road), were not found. **Unverified recollection**: Flame is a 0–100 meter that drains while travelling and raises stress and enemy strength when low.
- I found no primary-source designer commentary (Mega Crit talk or blog) on why the map rules exist. The rationale above is inference.

---

## 3. Darkest Dungeon meta loop: DD1 Hamlet, roster, permadeath, provisioning, room/corridor exploration, curios; DD2 Road/Inn/Altar of Hope/Candles

### Takeaway
DD1 runs a "company management" meta: gold and heirlooms from expeditions upgrade Hamlet buildings, and heroes are disposable, permadeath-prone, stress-damaged assets that need paid recovery. Expeditions are short, medium, or long, with pre-bought provisions (food, torches, shovels, keys, and cures) and a light meter that trades risk for reward. DD2 replaced this with one long stagecoach run (regions → Inn → Mountain) and a candle currency spent at the Altar of Hope on unlocks. This is closer to a classic roguelite meta and better suited to short sessions.

### Cited Findings
**DD1 Hamlet (meta hub)**
- The Hamlet's buildings are Abbey, Blacksmith, Guild, Nomad Wagon, Sanitarium, Stage Coach, Survivalist, and Tavern. Districts (from the later DLC/update) instead give passive bonuses, such as free items or a stronger torch. — [DD wiki: Districts](https://darkestdungeon.wiki.gg/wiki/Districts) (search summary)
- The Abbey and Tavern cost the same and relieve the same stress. The Abbey is lower-variance, while the Tavern more often applies negative quirks or conditions but also has more positive outcomes. — [DD wiki: Abbey](https://darkestdungeon.wiki.gg/wiki/Abbey) (search summary)
- Upgrading the Stage Coach increases recruits available and roster size. Upgrading the Sanitarium adds quirk-treatment slots and lowers costs. A common community upgrade order is Stage Coach > Guild > Blacksmith > Sanitarium > Survivalist > Abbey > Tavern. — [SegmentNext: best building upgrades](https://segmentnext.com/darkest-dungeon-building-upgrades) (search summary)
- Town Events reward specific quest types. For example, the Ruins "Gather" quest triggers "All Saints Day" (free Abbey treatments), and "Activate" quests give +33% Resolve gain and a +15% damage buff for the week. — [DD wiki: Expedition](https://darkestdungeon.wiki.gg/wiki/Expedition)

**DD1 Expedition structure**
- Lengths:
  - **Short**: a handful of rooms, no camping.
  - **Medium**: branching, 1 Firewood (one camp). Boss missions are always medium.
  - **Long**: "extreme branching", 2 Firewood.
  - Source: [DD wiki: Expedition](https://darkestdungeon.wiki.gg/wiki/Expedition)
- Objectives:
  - **Cleanse**: win every room fight (corridor fights don't count).
  - **Explore**: enter 90% of rooms.
  - **Gather**: collect quest items from curios.
  - **Activate**: use given items on special curios.
  - **Boss**: kill the dungeon boss.
  - Source: [DD wiki: Expedition](https://darkestdungeon.wiki.gg/wiki/Expedition)
- **Level-band gating** stops veterans from farming easy content. Heroes 2 or more levels above the expedition level refuse to go. Under-levelled heroes take 20 stress per level below. — [DD wiki: Expedition](https://darkestdungeon.wiki.gg/wiki/Expedition)
- **Boss unlock progress per mission** (excess carries over):
  - Apprentice: short 50%, medium 75%, long 100%.
  - Veteran: 33%, 50%, 67%.
  - Champion: 20%, 30%, 40%.
  - Resolve XP: Apprentice 2/3/4, Veteran 4/6/8, Champion 8/12/16 (short/medium/long).
  - Source: [DD wiki: Expedition](https://darkestdungeon.wiki.gg/wiki/Expedition)
- **Light meter**: light drops for every corridor segment and room entrance, more slowly in explored corridors. Low light can trigger ambushes. Backtracking is slower and adds stress. — [DD wiki: Expedition](https://darkestdungeon.wiki.gg/wiki/Expedition). Each torch adds 25 light. — [SegmentNext: provisions](https://segmentnext.com/darkest-dungeon-provisions) (search summary)
- **Scouting**: there is a chance to scout on entering a room (after combat if there is one). Curios can trigger scouting, and trinkets or camp skills raise the chance. — [DD wiki: Expedition](https://darkestdungeon.wiki.gg/wiki/Expedition)
- **Retreat and failure**: retreating from combat returns the party to the previous explored section with heavy stress, and it can fail. Aborting keeps loot but forfeits the quest reward. Aborting a Darkest Dungeon mission kills one hero to cover the retreat. A total party kill loses the loot, and equipped trinkets go to "The Shrieker" (a recoverable-loss hook). — [DD wiki: Expedition](https://darkestdungeon.wiki.gg/wiki/Expedition)
- **Provisioning** (community baselines; numbers vary by player and version):
  - **Short**: about 8 food, 6–8 torches, 1–2 shovels, 1–2 keys.
  - **Medium**: about 16 food, 10–12 torches, 2–3 shovels, around 3 keys, 2 antivenom, 3 bandages.
  - **Long**: about 24 food, 12–16 torches, 3–4 shovels, 4 antivenom, 5 bandages.
  - Region-specific cures: antivenom and bandages for the Weald and Warrens, holy water and keys for the Ruins.
  - Shovels clear obstacles without damage.
  - Source: [Escapist beginner guide](https://escapistmagazine.com/?p=60144); [Steam discussion](https://steamcommunity.com/app/262060/discussions/0/135508833659754831); [GameSkinny provisioning guide](https://www.gameskinny.com/tips/darkest-dungeon-provisioning-guide/) (search summary)

**DD2 run and meta structure**
- Each expedition begins and ends at the **Altar of Hope**. The player picks a Confession (a campaign with a different boss), assembles a party at The Crossroads, and travels regions → Mountain (Confession boss). Main regions are The Foetor, The Tangle, The Sprawl, and The Shroud, plus The Valley (tutorial) and the bonus regions The Sluice and The Catacombs. — [DD wiki: Roads](https://darkestdungeon.wiki.gg/wiki/Roads); [DD wiki: Altar of Hope](https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope)
- **Altar of Hope locations** (each mirrors a region):
  - **Intrepid Coast**: stagecoach and expedition-wide upgrades.
  - **Living City**: new heroes, hero attributes, and hero trinkets.
  - **Working Fields**: most item unlocks.
  - **Timeless Wood**: "Memories", which are bonuses that persist for a hero across expeditions.
  - **Mountain**: cosmetics, with 3 skins and 3 outfits per hero.
  - **Recollection**: a catalogue of unlocked items. Some must be discovered in a run first.
  - **The Dam**: run modifiers toggled on or off, such as retreat enabled (+2 Loathing and +2 stress), extended Acts 1/2, and more battle modifiers.
  - Source: [DD wiki: Altar of Hope](https://darkestdungeon.wiki.gg/wiki/Altar_of_Hope)
- **Candles of Hope earned:**
  - Region completion (awarded on entering the Inn): Valley 2, Sluice 4, 1st region 8, 2nd region 20, 3rd region 36.
  - Lairs: 4 / 10 / 20.
  - Mountain: 6 for entering, 20 for beating the Confession boss, and 2 per surviving hero.
  - Region goals have a 20% chance to pay 3–5 candles.
  - Individual nodes have a 25–77% chance to drop 1 candle, with Lairs and Dens highest. The chance can be raised via the Intrepid Coast.
  - The steep back-loading (8 → 20 → 36) rewards pushing deeper, but even a failed run in region 1 still pays.
  - Source: [DD wiki: Candles of Hope](https://darkestdungeon.wiki.gg/wiki/Candles_of_Hope)
- **Candle costs** (Working Fields unlock tiers):
  - Trinkets: 16 → 24 → 32
  - Combat items: 6 → 8 → 12
  - Stagecoach items: 16 → 24 → 32
  - Inn items: 4 → 8 → 12 → 16 → 20 → 24
  - Quirk rerolls: 6 → 9 → 12 → 16 → 20 → 24
  - At end game, candles can also be spent at nodes during a run, for example 8–10 candles at "The Desperate Few" for +30 Flame plus items.
  - Source: [DD wiki: Candles of Hope](https://darkestdungeon.wiki.gg/wiki/Candles_of_Hope)
- The Altar of Hope was a post-launch replacement of DD2's original meta, which press described as a necessary "metagame reboot". — [Epic Games Store news: "Darkest Dungeon 2's metagame reboot was expected and necessary"](https://store.epicgames.com/news/darkest-dungeon-2s-metagame-reboot-was-expected-and-necessary) (headline only; article body not fetched)

### Inferences
- **Hamlet → the Pirate Ship as hub** (DD1-style persistent upgrades, but party-shared):
  - The galley/kitchen acts as the Tavern (stress or "morale" relief, with variance).
  - The infirmary (Chopper) acts as the Sanitarium (removes negative quirks or "injuries/traumas").
  - The workshop (Franky/Usopp) acts as Blacksmith/Guild.
  - The crow's nest adds scouting.
  - The Den Den Mushi "recruitment board" acts as the Stage Coach. Recruiting crew (NPC companions) suits solo players or filling an empty slot in co-op.
  - In multiplayer, each player owns their character, so the DD1 roster-of-disposable-heroes concept translates best to **NPC crew/companions** or **unlockable alt characters**, not to players' main avatars.
- **Permadeath vs. Roblox audience.** Full DD1 permadeath of a player's main character is likely to cause churn on Roblox (sessions are short and casual users leave in under 2 minutes; see section 5). Better options:
  - DD2-style: everything resets per run and only the meta currency persists.
  - DD1-style permadeath limited to recruitable NPC crew or temporary "bounty hunter" hires.
- **Provisioning → ship supplies** before setting sail: meat or food (prevents starvation debuffs on long voyages), cola or fuel (for the ship's special moves or skipping a hazard edge), bandages, an antidote, a "Log Pose" (scouting), and "Den Den Mushi" (call for help or rescue = retreat). A short/medium/long voyage choice, with 0/1/2 camps, is a clean way to offer 20/30/40-minute runs.
- **Light meter → "Weather/Morale" meter.** It drains per sea-lane travelled, high values give scouting and loot bonuses, low values give ambush chance and stronger enemies. It is refilled by a consumable (like torches) or by events (a crew party/feast).
- **Candles → "Bounty Berries" or "Legacy/Will of D." points**, back-loaded like DD2 (2 / 8 / 20 / 36 per region), so even a failed 15-minute run earns some, but finishing earns far more. Spend them at ship locations that mirror visited islands (DD2's Altar regions mirror world regions, which is good for lore cohesion).
- **The Dam (toggleable run modifiers)** = a Roblox-friendly "challenge settings" hub, a lightweight way to add difficulty tiers without new content.
- **Level-band gating** (DD1 heroes refuse low-level quests) is a good anti-carry rule for matchmaking. It can be softened to "rewards scale down if your level is far above the voyage tier."

### Gaps
- Exact DD1 building upgrade costs, stagecoach roster numbers, curio list and outcomes, hunger-check cadence, and provision prices and stack sizes were not captured from a primary source.
- DD2's Inn mechanics (inn items, relationship events), the Flame meter's numbers, and the Confession count were not captured.
- No Red Hook GDC talk or developer interview was fetched. Design rationale for the meta reboot is unsourced beyond the headline.

---

## 4. Puzzle integration in RPGs and roguelites, and co-op puzzle design

### Takeaway
Puzzles survive inside a fast run loop when they are either (a) **outside the run and persistent** (Inscryption's cabin), (b) **short, chunked, and self-contained** (Golden Idol designs scene by scene rather than one huge mystery), or (c) **light, character-driven gags that set pacing rather than block it** (Undertale's Papyrus puzzles). Long knowledge-gated secrets (Tunic's manual) work across the whole game, not within a run. In co-op, the proven pattern is **asymmetric information plus a constrained communication channel** (We Were Here walkie-talkies, inspired by Keep Talking and Nobody Explodes).

### Cited Findings
**Inscryption** (see section 1): the cabin puzzles exist to provide persistent progression in a roguelike. — [Game Developer](https://www.gamedeveloper.com/design/how-game-jam-sacrifices-became-inscryption)

**The Case of the Golden Idol**
- It was designed puzzle by puzzle and chapter by chapter, which distinguished it from Obra Dinn, where the player solves one big mystery over the whole game. — [Thinky Games feature on Golden Idol](https://thinkygames.com/features/how-the-case-of-the-golden-idol-developers-made-one-of-the-decades-best-detective-games-twice/) (search summary)
- Quality-of-life features: the word bank is automatically sorted into names, nouns, and verbs. — [Thinky Games](https://thinkygames.com/features/how-the-case-of-the-golden-idol-developers-made-one-of-the-decades-best-detective-games-twice/) (search summary)

**Tunic (manual as puzzle)**
- The in-game instruction manual is found page by page and is written partly in a "trippy glyph language" the fox can't read. Shouldice drew on childhood memories of flipping through manuals he didn't fully understand. — [Game Developer: How TUNIC weaves wondrous worlds](https://www.gamedeveloper.com/road-to-igf-2023/how-tunic-weaves-wondrous-unknowable-worlds-inspired-by-inscrutable-nes-manuals); [Red Bull interview](https://www.redbull.com/int-en/tunic-video-game-developer-interview)
- Some secrets can only be found by reading the manual, as in old games. — [Game Informer: Tracing Threads, The Making of Tunic](https://www.gameinformer.com/2022/05/30/tracing-threads-the-making-of-tunic)

**Undertale puzzle rooms**
- A critical-play analysis says Undertale uses the RPG trope of pointless puzzles detached from story, played for humor by making them unexpectedly easy. Papyrus's traps are "largely ineffectual as roadblocks." — [Medium: Critical Play, Puzzles in Undertale](https://medium.com/game-design-fundamentals/critical-play-puzzles-in-undertale-5c27b9e6dcc8); [Undertale wiki mirror: Snowdin puzzles](https://breezewiki.discard.no/undertale/wiki/Snowdin/Puzzles)
- The puzzles express character (Papyrus's earnest naivety) rather than challenge. — [Mechanics of Magic critical play](https://mechanicsofmagic.com/2024/06/06/makeup-critical-play-puzzle-design/) (search summary)
- Counterpoint: a level-design review calls the areas "very linear, straightforward" and says the puzzles "don't offer deep level design aspects". — [Game Developer: The hidden level design of Undertale](https://gamedeveloper.com/design/the-hidden-level-design-of-undertale) (search summary)

**Co-op asymmetric puzzles (We Were Here, Keep Talking and Nobody Explodes)**
- Total Mayhem Games (We Were Here) liked games that make players depend on each other and named Keep Talking and Nobody Explodes as an inspiration. They chose an asymmetric design over Portal 2's shared view because each player experiencing a different side is "the essence". — [Escapist Magazine](https://www.escapistmagazine.com/?p=43661) (search summary); [Premortem.games interview](https://premortem.games/2022/05/31/total-mayhem-games-are-masters-of-the-asymmetrical-puzzler/)
- In We Were Here, two players are separated and can only talk by walkie-talkie, taking turns to describe what they see. The voice channel is the main puzzle input. They prototyped this communication loop before writing the story. — [Premortem.games](https://premortem.games/2022/05/31/total-mayhem-games-are-masters-of-the-asymmetrical-puzzler/)
- Their process: some puzzles come from the location and others are mechanic-first with a location added later. Ideas are filtered internally for "fun, too hard, too easy" or "really dreadful", go through focus-group iterations, are re-checked in place in the world, and every puzzle is played weekly by the devs. Players alternate between a "theoretical" role and a "practical" role. — [Premortem.games](https://premortem.games/2022/05/31/total-mayhem-games-are-masters-of-the-asymmetrical-puzzler/)
- KTANE's split: the defuser sees the bomb but not the rules, and the experts hold the manual but can't see the bomb. — [Pixel Poppers capsule review](https://pixelpoppers.com/review/keep-talking-and-nobody-explodes/) (search summary)

### Inferences
- **Three-tier puzzle placement for a 20–40 min run:**
  1. **In-run micro-puzzles (30–90 s)**: island events such as a pressure-plate room, a lever order, or a Papyrus-style gag puzzle themed to a comic villain (Buggy, Foxy). They must never block the run. Give a skip or "brute force" option that costs HP, supplies, or time.
  2. **Per-island "dungeon" puzzle (3–6 min)**: Zelda-style, optional, on an Elite/Treasure node. Golden-Idol-style chunking: one self-contained scene per island.
  3. **Meta puzzles (persistent, across runs)**: Poneglyph decipherment in the Tunic/Inscryption-cabin mode. Each run can yield fragments (glyphs, rubbings), and decoding them in the ship hub unlocks lore, starting items, or new routes (for example "Road Poneglyph" → access to a secret final island). This is where "complicated puzzles" belong, because failing a run doesn't erase them. Chants of Sennaar's language-deduction structure would fit the Poneglyph script (see Gaps).
- **Co-op asymmetric puzzles fit One Piece canon well:** crews frequently split up (Skypiea, Enies Lobby, Thriller Bark), and the Den Den Mushi is a ready-made in-world walkie-talkie. Pattern: one player holds the "manual" (a Poneglyph key, a log-book page, a Marine codebook) shown only on their screen, while another stands at the mechanism. Roblox can show per-player GUI easily. Randomize the mapping per run so solutions can't be shared on YouTube or Discord.
- **Role-gated info**: give each class a puzzle "lens" (the Navigator sees currents or arrows, the Archaeologist reads glyphs, the Sniper sees distant switches). This makes every player necessary and works naturally with 3–4 players (We Were Here is 2 players; scaling beyond 2 needs more than one information holder).
- **Pitfalls:**
  - Puzzles inside a timed or competitive run stall groups. Keep in-run puzzles optional or skippable.
  - One-time-solution puzzles get spoiled in a multiplayer community (randomize).
  - One clever player solves while others idle (asymmetric info fixes this).
  - Undertale-style joke puzzles only work if the comedy is strong. Otherwise they read as filler, as the "very linear" critique shows.

### Gaps
- No sources were fetched for **Chants of Sennaar**, **Professor Layton** (picarats and hint coins, puzzle-as-node integration), or **Zelda** dungeon puzzle design (e.g., Mark Brown's "Boss Keys" series). These are relevant (Layton's hint-coin economy is a strong model for co-op hint spending) but unverified here.
- The Golden Idol feature page returned 403. Its "partial correctness feedback" mechanic (the game tells you when only a few blanks are wrong) is **unverified recollection**.
- No hard data on how puzzle difficulty affects roguelite retention or run abandonment was found.

---

## 5. Fitting these structures to multiplayer co-op and short Roblox sessions (path choice, voting, run length, mid-run saves)

### Takeaway
Roblox median session length is about 26 minutes (2025), and core users average about 37 minutes, so a 20–40 minute full run is the right target, with a natural checkpoint every 8–12 minutes. For path choice, StS2 co-op uses **vote-weighted random selection plus a persistent map-drawing tool**. This avoids a single leader dominating and avoids deadlock. Shared path with individual rewards (StS2) and "pick 1 of 3 starred encounters" (An Average Campaign) are the two proven co-op map models.

### Cited Findings
- **Roblox session data (GameAnalytics 2025 benchmark):**
  - Casual users leave in under 2 minutes, while core users average 37 minutes per session.
  - Median session length fell from 36 to 26 minutes between 2023 and 2025, while daily session frequency among the most active users rose by about a third.
  - Half of players log in multiple times a day, and the most active core users play up to 8 sessions daily.
  - Source: [GameAnalytics: 2025 Roblox report](https://www.gameanalytics.com/reports/2025-roblox-report) (search summary)
- Roblox's own analytics define average session length per experience (start of session to leaving). — [Roblox Creator Docs: analytics](https://create.roblox.com/docs/en-us/production/analytics/get-started) (search summary)
- **StS2 co-op path model** (see section 2 for full detail):
  - Votes are resolved by a weighted roulette.
  - Map drawings persist for the act.
  - Shared path and encounters, individual decks, gold, and shop stock.
  - Rest is per player, and "Mend" heals a teammate.
  - Relic conflicts are settled by an automatic rock-paper-scissors.
  - A downed player returns at 1 HP after the fight.
  - Saves are tied to the host and resumable.
  - Source: [AllThings.How](https://allthings.how/slay-the-spire-2-co-op-multiplayer-every-mechanic-and-rule-explained/)
- **An Average Campaign model**: after camp the party picks 1 of 3 random starred encounters. It is built for 3–4 players and supports 1–5. Meta-progression is Cealts (about 70 for a full completion) spent on Boons (5 slots, costing 1–5 each) and Races. There is per-class Prestige EXP (3 skill points per Prestige level, max 25). The run ends only when the entire party falls. Crafted gear lasts one run. — [AAC wiki](https://an-average-campaign.pages.dev/)
- **DD2 checkpoint cadence**: regions end at an Inn where the party recovers and candles are banked on entry. This is a natural save and quit point. — [DD wiki: Roads](https://darkestdungeon.wiki.gg/wiki/Roads); [DD wiki: Candles of Hope](https://darkestdungeon.wiki.gg/wiki/Candles_of_Hope)
- **Inscryption Act III** replaced run-ending death with respawn at the last checkpoint (antenna towers), a softer failure model. — [Wikipedia](https://en.wikipedia.org/wiki/Inscryption)

### Inferences
- **Recommended run shape (about 30 min, 3–4 players):**
  - 3 "seas" (acts) of about 8–10 minutes each.
  - Each sea has about 5–7 node choices plus a boss.
  - Each sea ends at a **port** (DD2 Inn equivalent) that banks meta currency and is a **save checkpoint**, so a party that must leave at minute 20 keeps 2/3 of its earnings and can resume.
  - Store mid-run state per party leader (as StS2 ties saves to the host), with "resume voyage" in the lobby. If a member is missing, fill the slot with an NPC crewmate.
- **Path-choice options, best for Roblox first:**
  1. **Vote-weighted random with a timer (StS2 model)**: 10–15 s vote window with live tallies on the 3D chart, ping or draw tools for discussion, and AFK votes counted as abstain. This prevents deadlock and griefing.
  2. **Rotating "Captain's call"**: the captain role rotates each sea, and the captain decides after a short advisory vote. This is good for roleplay but risks a dominant player.
  3. **Role ownership**: the Navigator class or player picks the route and others pick in their domains (the cook chooses the rest action, the shipwright the ship upgrade). This gives every role agency but needs careful balance.
  - Avoid "unanimous required" (it stalls) and "first to click wins" (griefing).
- **Individual rewards on a shared path** (StS2) prevents loot fights. Use per-player reward rolls and per-player shop stock, plus a tie-break mini-game (StS2 uses rock-paper-scissors) for unique items. A canon gag like a quick janken would be on-theme.
- **Downed-not-dead within a run** (StS2: out for the fight, return at 1 HP) keeps all players engaged in short sessions. Keep run-ending loss tied to a full-party wipe, as AAC does.
- **Back-loaded but non-zero rewards** (DD2's 2/8/20/36 candles; AAC's about 70 Cealts for a full clear) keep short, failed sessions feeling worthwhile, which matters given Roblox's large casual share (users leaving in under 2 minutes).
- **Asymmetric map info for co-op**: borrow DD2 fog plus Watchtower scouting. One role reveals the next row's node types, which turns path choice into a team discussion and makes the scout's job meaningful.
- **Which patterns suit co-op and short sessions:**
  - Strong fit: StS-style visible node map with a vote, AAC 3-starred-choices, DD2 Inn checkpoints and back-loaded meta currency, Inscryption-style persistent hub puzzles, deathcard/wanted-poster creation, and asymmetric-info puzzles.
  - Weaker fit, or needs adaptation: DD1 full permadeath of player characters, DD1 long expeditions (40+ min), dense single-run escape-room puzzles that block progress, and Monster Train-style single-player deck management (ok if per player).

### Gaps
- No public data was found on how An Average Campaign handles multiplayer path choice (vote vs. leader), its run duration, or whether it saves mid-run.
- StS2 co-op tie-breaking, vote timers, and disconnect handling were not documented in the fetched source.
- No sourced data was found on Roblox-specific retention effects of permadeath or run length. Platform session medians are the best available proxy.
- No sources were found on other co-op roguelite path systems (e.g., Ravenswatch, Wildfrost co-op mods, Gloomhaven digital) for broader comparison.
