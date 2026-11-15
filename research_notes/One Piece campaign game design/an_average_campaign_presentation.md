# An Average Campaign (Roblox): Presentation, UI, Art Style, Vibe and Reception

Research date: 14 Nov 2026. Method: Roblox game page and public Roblox games API, stats trackers (Rolimons, RoWatcher), the community Miraheze wiki and fan wikis, YouTube search results and comments, and **direct visual inspection** of the 8 official Roblox thumbnails and frames from a full-run YouTube video ("I Beat An Average Campaign!", Wetlag, uploaded about Oct 2026, so it shows roughly v0.5.x). Statements marked "observed" are my own descriptions of those images or frames. I did not play the game.

---

## 0. Identity check: is this the right game, and is there really "Undertale-style bullet-hell dodging"?

### Takeaway
The game is **"An Average Campaign [Alpha v0.5.2]"** (place ID 80734098185936, universe 7359962123), owned by the Roblox group "An Average Campaign" (ID 35729591). It is a **turn-based D&D-style roguelite with 3D Roblox combat scenes and 2D ScreenGui menus**. I found **no evidence of an Undertale-style bullet-hell dodge box**. Dodging and blocking are stat-based dice rolls. The brief's "bullet-hell" premise looks like a mix-up, probably with the separate, older game *Average Roblox Undertale Game (ARUG)*, or a generic "An Average ___" title.

### Cited Findings
- Official title: "An Average Campaign [Alpha v0.5.2]". Creator: group "An Average Campaign". Maturity: Mild (light/unrealistic blood, repeated mild violence). Genre RPG, subgenre Turn-based RPG. Server size 50. Voice chat and camera not supported. — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)
- Roblox API: universe 7359962123, created **2025-03-10**, updated 2026-11-14, `universeAvatarType: "MorphToR6"` (all players are forced into blocky R6 rigs), `createVipServersAllowed: false` (no private servers), genre_l1 RPG / genre_l2 Turn-based RPG. — [Roblox games API](https://games.roblox.com/v1/games?universeIds=7359962123)
- Credits in the description: huhuzh (scripting, UI), Kario777 (modeling), Yuml_I (modeling), FringleMeench (animations, VFX). — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign); [Rolimons](https://www.rolimons.com/game/80734098185936)
- Fan wikis credit the studio as "Regicide Studio" (the same four people). The official description does not use that name. — [anaveragecampaign.wiki](https://anaveragecampaign.wiki/); [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Associated places: "Dungeon", "DungeonTest" and "Dungeon Tutorial". There is also a separate "[TESTING]" experience (universe 8988844066). — [Rolimons](https://www.rolimons.com/game/80734098185936); [RoWatcher TESTING](https://rowatcher.com/games/8988844066/an-average-campaign-testing)
- How combat works, per the fan wikis: each turn you choose **Fight, Items or Focus**. You "cannot flee or skip turns". Initiative sets turn order. **Each incoming hit rolls Block and Dodge separately.** Neither wiki describes a bullet-hell box, QTE or parry minigame. — [anaveragecampaign.wiki](https://anaveragecampaign.wiki/); [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- The in-game Equipment stat sheet shows "Block Chance", "Block Damage Reduction" and "Dodge Chance" as percentages, which fits RNG-based defence. Observed in frame. — [Wetlag video, ~0:40](https://www.youtube.com/watch?v=e83JrLu2YZA&t=40s)
- None of the combat frames I inspected (Forest Giant fight, Sewer fights at ~27:30 and ~1:23:00) shows a soul/heart box or projectile arena. — [Wetlag video](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1640s)
- A YouTube commenter on a critical review said: "It's supposed to be more similar to D&D which is why it's rng based". — [Eclipse review, comments](https://www.youtube.com/watch?v=VYNmn4Tp1Jo)
- A different game, **Average Roblox Undertale Game (ARUG)**, by RobloxNoobDX (Feb 2022, about 1.2 to 1.4M visits), is a satire of the "Sans vs Sans" genre and is a bullet-hell Undertale game. — [RoWatcher ARUG](https://rowatcher.com/games/3346730273/balance-overhaul-average-roblox-undertale-game); [Bloxodes ARUG](https://bloxodes.com/stats/games/average-roblox-undertale-game-3346730273)
- Players note that "An Average ___" has become a naming genre on Roblox: "I have no idea why 'an average _' has become a genre on roblox" (871 likes). — [Eclipse review, comments](https://www.youtube.com/watch?v=VYNmn4Tp1Jo)

### Inferences
- If the One Piece game is meant to have Undertale-style dodging, that is the developer's **own addition**, not something taken from AAC. AAC's defence is passive (stats and dice). It still reads as tense, because enemy "telegraphs" and ability-name banners tell players what is coming.
- The "An Average ___" naming is a known meme-genre. A title like "An Average One Piece" will be read as part of that self-deprecating tradition.

### Gaps
- I could not watch every update. A timed-defence minigame could have been added in v0.5.2 (26 Oct 2026, "Cauldro's Return") without appearing in the wiki changelog. Nothing I found suggests it was, but this is not 100% excluded.

---

## 1. UI: battle screen, camp/route screen, menus, dialogue, lobby, fonts, palette, input

### Takeaway
AAC uses **flat, utilitarian, dark-gray translucent ScreenGui panels with a chunky pixel/bitmap font**, layered over a **live 3D Roblox scene**. It looks like a "debug-chic" or tabletop-character-sheet interface, not a polished JRPG skin. The battle HUD is MMO-like:
- a turn-order list on the left
- a unit inspector under it
- your own HP/energy plate at the bottom centre
- status icons with tooltips
- a big centred band that announces each ability or item name

Floating name/HP/energy plates sit under every 3D combatant. Outside combat there is no free-roam overworld. Progress is a **party-vote "Where To Next?" screen of three cards**, plus **full-screen text-adventure event panels** with voted choices.

### Cited Findings
**Battle screen** (all observed in frames from a Sept/Oct 2026 build):
- **Top-left:** a "Turn N" header (e.g. "Turn 4", "Turn 9"). Below it is a **vertical initiative/turn-order list** of every combatant, players and enemies mixed. Each entry shows the name, a number in parentheses (likely initiative), and two thin bars: red HP and blue energy. Examples: "GODZ6523 (11)", "creedbut (7)", "Giant (1)", "Bunny? (0)". — [Wetlag video ~27:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1620s)
- **Left, under the turn list:** an **inspector panel** for the selected or targeted unit (e.g. "Giant": red HP bar "107.3/279", blue bar "1/6"). It has a row of square status-effect icons with stack numbers (e.g. "2 2 2"). — [Wetlag video ~27:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1620s)
- **Bottom-centre:** the player's own plate.
  - One line reads "Warrior Lvl 7 (23/94)", i.e. class, level and XP. Another frame shows "Knight Lvl 13 (56/203)".
  - Below that are a wide **red HP bar** (e.g. "104/113.1") and a **blue energy bar** (e.g. "1/6").
  - On the right is a **gold counter with a coin icon** (e.g. "17", "101", "144").
  — [Wetlag video ~27:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1620s); [~1:23:30](https://www.youtube.com/watch?v=e83JrLu2YZA&t=5000s)
- **Bottom-right:** a row of buff/debuff icons with stack counts. Hovering one shows a gray tooltip box, for example:
  - "Fear: Deal 0.9x less damage. Cannot naturally gain energy. Bosses, mini-bosses, and trainers have their energy gain reduced to 1 per turn."
  - "Fervor: Deal 1.2x ability damage and take 1.1x ability damage."
  — [Wetlag video ~27:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1620s); [~1:23:15](https://www.youtube.com/watch?v=e83JrLu2YZA&t=4995s)
- **Centre-screen ability/item banner:** when any unit acts, a semi-transparent horizontal band across the middle of the screen shows the action name in the pixel font (e.g. "Minor Healing Potion", "Mutated Nibble"). — [Wetlag video ~1:24:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=5040s); [~1:23:44](https://www.youtube.com/watch?v=e83JrLu2YZA&t=5024s)
- **Top-right:** the area and progress counter, e.g. "Forest (5/8)", "Dungeon (3/12)", "Sewer (5/…)". It is red during combat and white at camp. — [Wetlag video](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1620s)
- **In the 3D world:** every combatant has a small **BillboardGui plate under or near its feet**, with the name plus mini HP (red) and energy (blue) bars and tiny status icons.
  - Party members stand clustered on the **left** of a 3D arena and enemies on the **right**, under a three-quarter overhead camera. This is a classic JRPG side-vs-side layout, staged in 3D.
  - Observed. — [Wetlag video ~27:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1620s)
- Fan wikis name the turn menu options **Fight / Items / Focus**. Energy pays for abilities and Focus restores it. Enemies "telegraph" attacks. — [anaveragecampaign.wiki](https://anaveragecampaign.wiki/)
- The patch history includes a "Combat UI rework" in v0.3.3 (4 Nov 2025) and "system/UI improvements" in v0.4 (12 Dec 2025), so pre-Nov-2025 footage shows an older combat UI. — [Miraheze Version History](https://anaveragecampaign.miraheze.org/wiki/Version_History)

**Route/encounter selection ("Where To Next?")**, observed:
- Three tall cards sit side by side in **muted slate-blue, dusty maroon and sage-green** under a gray title plaque reading "Where To Next?". Each card has:
  - a title (e.g. "A Resting Druid", "Elven Camp", "An Upsidedown Individual")
  - a square **3D-render preview image** of the encounter
  - a one-line second-person flavour sentence ("You spot a camp full of elves", "You spot a strange man hanging from a tree")
  - "Votes: N"
  - a difficulty rating of 2 to 4 four-point **star/sparkle glyphs**
- Under the cards are **"Scavenge (0)"**, a **countdown timer** ("18s") and **"Short Rest [3] (0)"**. Behind it the camp is blurred: a low-poly night forest with tents and a campfire. — [Wetlag video ~25:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1500s); [Roblox thumbnail "Choose your path"](https://tr.rbxcdn.com/180DAY-f5e7ca4def451e00ffbb3035fa6dc2ed/768/432/Image/Webp/noFilter)
- The fan wiki says that after each fight you return to camp and pick one of three random encounters marked with difficulty stars. — [anaveragecampaign.wiki](https://anaveragecampaign.wiki/)

**Narrative event / dialogue panel** (text-adventure style), observed:
- It is a near-full-screen dark-gray panel. On the left is a square 3D-render illustration of the scene with a timer under it. On the right is a **bold pixel-font title** (e.g. "Into the Dungeon", "An Ancient Envoy"), then a paragraph of **second-person narration in white pixel text**, then full-width gray **choice buttons with live vote counts**.
- Example narration: "As the giant falls before you, and the doors to the infamous dungeon begin to creek open, a wonderous light pours out, filling you with inspiration." with a single choice "… (2)".
- Another event has choices "Leave this place (0)" and "Continue onward (4)".
- Sources: [Wetlag video ~28:20](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1700s); [~1:55:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=6900s)
- NPC encounters use dialogue options, and picking certain options starts combat. Examples: "Assault the Paladin", "We know you're in there!", "Pick the lock to the cell (Rogue)", which is class-gated, and "Can you grant me power?". — [Miraheze NPCs](https://anaveragecampaign.miraheze.org/wiki/NPCs)

**Inventory / Equipment / Stash / Craft screen** (camp, between fights), observed:
- **Left column:** a scrolling item list grouped by collapsible category headers (e.g. "Boots (3) –", "Chestpiece (3)", "Charms (1)", "Swords (0)"). Each item is a gray button in the pixel font with tiny "Craft" and "Inspect" sub-buttons. "Stash" and "Craft" tabs sit next to it, with a gold total and "Transfer Gold" underneath.
- **Centre:** an "Inventory" panel with a "Search…" bar, a big empty grid area and an item-description pane ("Stats:", "Sell Price: 50 Gold"). Side tabs read "Inventory" and "Abilities", plus a "Consumable: Empty" slot.
- **Right:** an "Equipment" panel with gear slots (Helmet, Chestpiece, Leggings, Greaves, Weapon e.g. "Simple Sword", Charm 1/2/3) and a **D&D-style stat sheet**:
  - "HP 76.1/81.6", "Energy 6", "Level 4 (21/50)"
  - STR / DEX / CON / INT / FTH / CHA / LCK
  - Initiative, Crit Chance, Crit Damage, Block Chance, Block Damage Reduction, Dodge Chance, Aggro, Lifesteal, Energy Gain
  - an "Invest Points (0)" button
- **Bottom:** a party-wide **"Ready (1/4)"** button and a "Hide" button.
- Sources: [Wetlag video ~0:40](https://www.youtube.com/watch?v=e83JrLu2YZA&t=40s); [~10:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=600s); [~45:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=2700s)
- Host chat commands exist: `/cmds`, `/gamespeed`, `/stashcraft`. — [Miraheze About](https://anaveragecampaign.miraheze.org/wiki/About)

**Lobby/hub:**
- The lobby is a **tavern hub** with these NPCs:
  - Magic Mirror: class, race, appearance and skill trees
  - Tavern Master at the bar: Boons
  - Aura Farmer near the entrance: party formation and starting the run
  - Puppet: Lunaeia-related Boons
  - others: Illinivich, Battle Master, The Veteran, Noble
  — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/); [Miraheze NPCs](https://anaveragecampaign.miraheze.org/wiki/NPCs)
- Observed (mobile video thumbnail, v0.3): the lobby is a large **timber-framed tavern hall** with exposed dark-wood beams, warm orange lantern light, plank floors and stone/plaster walls, explored by walking a 3D avatar. — [Mobile gameplay video thumbnail](https://i.ytimg.com/vi/bPZ0RXOgNf8/hqdefault.jpg) (video: [YouTube](https://www.youtube.com/watch?v=bPZ0RXOgNf8))
- Lobby servers hold up to 50 players (Rolimons average about 22 per server). Runs are 1 to 5 players, with 3 to 4 recommended. — [Rolimons](https://www.rolimons.com/game/80734098185936); [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)

**Branding font:**
- The marketing thumbnails use a chunky **orange pixel "AAC" logo** and orange pixel-font captions with a black outline ("Choose your path", "Join the battle with your friends"). The key art uses a **hand-lettered script** "an average campaign" logo on a parchment ribbon or in the corner. Observed. — [thumbnail: route select](https://tr.rbxcdn.com/180DAY-f5e7ca4def451e00ffbb3035fa6dc2ed/768/432/Image/Webp/noFilter); [thumbnail: class roster](https://tr.rbxcdn.com/180DAY-5bafb54e908f3925a5a4d24f322e0d3a/768/432/Image/Webp/noFilter)

**Platforms:**
- A no-commentary **Android mobile gameplay** video of v0.3 exists, so the game is playable on phones. — [YouTube: An Average Campaign - Roblox Mobile Gameplay](https://www.youtube.com/watch?v=bPZ0RXOgNf8)

### Inferences
- **Palette:** charcoal and mid-gray panels (roughly #3a3a3a to #5a5a5a) with lighter gray buttons and thin outlines, white text, **red HP / blue energy** bars, a yellow gold icon, and red area labels in combat. The colour comes from the 3D scene and the encounter cards, not the chrome. The UI is deliberately low-ornament, almost spreadsheet-like. That fits the "character sheet / tabletop" fantasy and keeps it cheap to iterate during alpha.
- **The font looks like a pixel/bitmap face resembling Roblox's built-in "Arcade" font** (impression only; not confirmed). It is used everywhere: titles, list items, tooltips.
- **Hybrid 2D/3D:**
  - 2D ScreenGui: route select, events, inventory, turn list, tooltips.
  - 3D: actual combat staging, BillboardGui unit plates, the lobby and camp.
  - Camp menus are drawn over a blurred 3D camp scene.
- **Multiplayer consensus is a core UI pattern.** Votes on route cards, votes on event choices, "Ready (x/4)", and countdown timers all keep a 3 to 5 player party in sync. This is directly reusable for a crew-based One Piece game (e.g. voting on the next island).
- No damage-number pop-ups were visible in the sampled frames. Damage seems to be read from bar changes and the action banner. This is not confirmed (see Gaps).
- The UI is click/tap driven (buttons, cards, list items), so it works on touch in principle. The small pixel text and dense stat sheets probably read poorly on phones (my inference, not a cited complaint).

### Gaps
- I did not capture a frame of the **Fight / Items / Focus action menu** or the target-selection flow during a player's own turn, so their exact placement and look are unverified. Older footage shows small icon buttons right of the player plate that may be the ability bar, but this is not confirmed.
- I could not confirm floating damage numbers, crit popups or miss/block/dodge text.
- I found no shop UI footage. Fan wikis mention a Tavern Master and trainers, but the shop layout is unknown.
- **Mobile-specific layout, controller support and keybinds are undocumented** in the wikis and the changelog. Roblox's supported-devices list was not readable from the page.
- The skill tree and Magic Mirror UI were not inspected.

---

## 2. Art style

### Takeaway
There are **two very different visual layers**:
- **In-game:** stock-feeling **3D low-poly Roblox** environments with moody lighting (night forest camp, mossy stone ruins, teal-lit sewers) and **blocky R6 avatars** (forced via MorphToR6). Enemies are mostly custom blocky models: a giant swordsman, a bone dragon, a slime cube, rat-men.
- **Marketing:** high-effort **painted / anime-style key art** in a dark-fantasy register (ink-wash monochrome, blood-red and black), reminiscent of Limbus Company and Darkest Dungeon, plus a cozy campfire illustration of Roblox avatars.

There are no 2D sprites in combat.

### Cited Findings
- The avatar type is **MorphToR6**: every player is converted to classic blocky R6. — [Roblox games API](https://games.roblox.com/v1/games?universeIds=7359962123)
- Credits list two modelers and one animator/VFX artist, so enemies, gear and VFX are custom-built. — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)
- The 8 official thumbnails (as of 14 Nov 2026), observed:
  1. A **painted anime-style portrait**: a scarred, brown-haired young man in a dark cloak conjuring swirling red magic, almost black-and-red. [img](https://tr.rbxcdn.com/180DAY-9015a459882eef1fca3bf48261badc37/768/432/Image/Webp/noFilter)
  2. **Ink-wash monochrome key art** in a manga-panel style: a huge skeletal dragon (the "Bone Drake" boss) looming over a party of **blocky Roblox avatar silhouettes**, with a hand-lettered "An Average Campaign" in the corner. [img](https://tr.rbxcdn.com/180DAY-9544a65b006601e9d6486e8f6bfdbbc6/768/432/Image/Webp/noFilter)
  3. **Stark red-and-black splash art** of an armoured knight with a spiked halo/sun behind his head, a greatsword and a shield. [img](https://tr.rbxcdn.com/180DAY-a27def8c871f15c29d1a23f3d2dc7055/768/432/Image/Webp/noFilter)
  4. A **cozy painterly campfire scene**: classic yellow-skinned **Roblox avatars** in adventurer gear (wizard hat, armour, hooded rogue, a girl reading a book) around a fire in a forest at night, with tents and glowing butterflies. [img](https://tr.rbxcdn.com/180DAY-f0b0808c6e364f3db4ea0237be87f84d/768/432/Image/Webp/noFilter)
  5. A **class roster in anime style**: seven vertical colour-coded panels (red, orange, gold, green, teal, blue, purple) with **anime-style humanized portraits** above circular class icons labelled BRAWLER, RANGER, PRIEST, BARD, WARRIOR, MAGE, ROGUE, under a parchment banner reading "an average campaign". [img](https://tr.rbxcdn.com/180DAY-5bafb54e908f3925a5a4d24f322e0d3a/768/432/Image/Webp/noFilter)
  6. An **in-game UI screenshot** of the "Where To Next?" route vote, captioned "Choose your path". [img](https://tr.rbxcdn.com/180DAY-f5e7ca4def451e00ffbb3035fa6dc2ed/768/432/Image/Webp/noFilter)
  7. An **in-game combat collage** captioned "Join the battle with your friends":
     - blocky avatars with name and HP plates, yellow slash VFX, on a low-poly grass arena
     - a muscular blond figure labelled "Ancient Vampire"
     - a pale skeletal dragon in a green-lit cave
     [img](https://tr.rbxcdn.com/180DAY-82837418f9da8b0dd523c4695aece158/768/432/Image/Webp/noFilter)
  8. A **meme image**: a round fluffy dog captioned "Hello foenem, please donate a few bands." [img](https://tr.rbxcdn.com/180DAY-c2632735420c98d2891ac30dfac703c8/768/432/Image/Webp/noFilter)
- In-game environments, observed in the Wetlag run:
  - Forest: low-poly trees, mossy stone walls and ruins, large wooden gates, dark green grass, dusk lighting.
  - Camp: night, with tents, a campfire and a cobbled ground.
  - Sewer: brick tunnels with teal glowing water channels, lanterns and barrels.
  - Enemies include a giant blocky gray swordsman ("Giant"), a white rabbit ("Bunny?"), a translucent glowing **green slime cube**, mutated rats and a lab-coat "Skyward Scientist".
  - Player characters are blocky R6 avatars wearing class armour.
  — [Wetlag video ~27:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1620s); [~1:23:15](https://www.youtube.com/watch?v=e83JrLu2YZA&t=4995s)
- The changelog mentions "new equipment/trainer models" (v0.3.4) and "cosmetics" (v0.4.2.1), and the Magic Mirror sets "appearance". — [Miraheze Version History](https://anaveragecampaign.miraheze.org/wiki/Version_History); [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)

### Inferences
- The **gap between the key art and the in-game look** is deliberate and effective. Anime and dark-fantasy splash art sells mood and characters, while the game itself stays cheap and readable: blocky avatars and flat UI. A One Piece take could copy this: commissioned anime-style crew art for thumbnails, blocky R6 avatars in-game.
- Visual touchstones, as impressions:
  - **Limbus Company / Project Moon** (red-black splash art, scarred anime portrait). Fan wikis list it as an inspiration.
  - **Darkest Dungeon** (ink-wash monochrome boss art, grim tone).
  - **D&D tabletop** (campfire party art, stat sheet).
  - **Slay the Spire** (three-path node choice).
  - **Arcane Lineage** (Roblox turn-based 3D combat with blocky avatars).
  - There is no Undertale, Deltarune or Paper Mario look.
- In-game lighting is moody and desaturated rather than bright and cartoony. The UI's colour-coded cards and red/blue bars give the main colour accents.

### Gaps
- Exact lighting technology (Future vs ShadowMap) and any post-processing were not verifiable.
- I don't know who painted the key art (no artist credit in the description).
- I did not inspect the boss arenas for The Giant, Bone Drake or the Void Herald in-game, apart from the thumbnail collage.

---

## 3. Tone, vibe, writing and framing

### Takeaway
The tone is **"grim dark-fantasy dungeon crawl delivered with shitpost energy"**:
- **Serious, atmospheric second-person narration** in events.
- **Meme-heavy names, inside jokes and pop-culture references** everywhere else.
- A **self-deprecating "average" title**.
- **Proudly punishing, info-hiding design** ("information is key").

The tabletop framing comes from the D&D-style stat sheet, class/race picks, "Natural 20"-style references, camp rests and narrated events. I found **no explicit Dungeon Master/narrator character**: the narration is anonymous second-person text.

### Cited Findings
- From the official description: it promises a "classic, simplistic roguelike adventure full of inside jokes, references, and other random stuff". It is "intended to be difficult and may be frustrating to some people", and "Losing a run should be expected and information is key." — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)
- Wiki framing: "deliberately difficult and vague", "packed with inside jokes, references, and unpredictable encounters". — [Miraheze About](https://anaveragecampaign.miraheze.org/wiki/About); [Miraheze Main Page](https://anaveragecampaign.miraheze.org/wiki/Main_Page)
- Narration is second-person and earnest. Examples:
  - "As the giant falls before you, and the doors to the infamous dungeon begin to creek open, a wonderous light pours out, filling you with inspiration."
  - "As you wander down an old hallway, the normal torchlight that lets you explore fades into a deep crimson glow that invites you onward."
  - Route cards: "You spot a strange man hanging from a tree".
  - Observed. — [Wetlag video](https://www.youtube.com/watch?v=e83JrLu2YZA&t=1700s); [~1:55:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=6900s)
- Meme and joke naming:
  - The lobby NPC "Aura Farmer" uses Gen-Z slang.
  - NPCs named "Kowalski", "Private", "Rico" and "Skipper" look like Penguins of Madagascar references.
  - Others: "Illinivich", "Goblinaacreal", "Grimblyaac".
  - Mini-bosses include "Baby" ("Allow what will be to be") and "Devilman".
  — [Miraheze NPCs](https://anaveragecampaign.miraheze.org/wiki/NPCs)
- Boon names, as listed in a guide's chapter list, include:
  - "Natural 20" (a D&D reference)
  - "Ourpled" (a FNaF "ourple" meme)
  - "Potential: Bunny", "The Chosen One", "Test Subject"
  - "poop"
  — [RoadToKing "Complete BOON GUIDE"](https://www.youtube.com/watch?v=2XCZI5O-358)
- An event called "April Fools 2026" was a "chaotic meme-themed campaign". — [anaveragecampaign.wiki](https://anaveragecampaign.wiki/)
- An "Ancient Vampire" trainer appears as a muscular blond figure, which looks like a JoJo/DIO nod. This is my visual impression and is not confirmed. — [thumbnail](https://tr.rbxcdn.com/180DAY-82837418f9da8b0dd523c4695aece158/768/432/Image/Webp/noFilter)
- The official thumbnails mix grim art with a meme dog asking players to "donate a few bands". — [thumbnail](https://tr.rbxcdn.com/180DAY-c2632735420c98d2891ac30dfac703c8/768/432/Image/Webp/noFilter)
- The game has **no in-game tutorial** per one fan wiki. Note that Rolimons lists a "Dungeon Tutorial" place, updated about a month ago, which suggests one may have been added since. — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/); [Rolimons](https://www.rolimons.com/game/80734098185936)
- Some choices are class-gated, e.g. "Pick the lock to the cell (Rogue)", which echoes D&D skill checks. — [Miraheze NPCs](https://anaveragecampaign.miraheze.org/wiki/NPCs)
- The community voice matches the game's irreverence: creator video descriptions say things like "i hate this game and i dont want to edit frick you". — [YouTube search results, RoadToKing](https://www.youtube.com/results?search_query=%22An+Average+Campaign%22+roblox&sp=CAM%253D)

### Inferences
- The "campaign" framing works through **systems and presentation** rather than a DM avatar:
  - party camp between fights
  - narrated choice events with group votes
  - attribute sheet (STR/DEX/CON/INT/FTH/CHA/LCK)
  - races and classes chosen at a magic mirror
  - a tavern hub
- A One Piece version could add the missing DM/narrator voice as a differentiator. Ideas: a log-pose "chronicler", a news coo bird delivering events, or a Den Den Mushi narrator.
- The humour layer is mostly **names, NPCs and secrets**. The core prose stays sincere, so the world still feels dangerous.

### Gaps
- I found no explicit lore/story bible or cutscenes. The story is apparently delivered only through event text and NPC dialogue.
- I don't know whether any narrator or DM persona appears in the newer "Timestream" one-shot content (v0.5.x).

---

## 4. Audio

### Takeaway
I found **no original soundtrack or composer credit**. The Roblox page's "Top Songs" list suggests the game uses **licensed or library tracks**, with a mixed palette: lo-fi, aggressive rock/metal, carnival.

### Cited Findings
- "Top Songs in An Average Campaign [Alpha v0.5.2]" on the Roblox page: **"Spooky LoFi" (NojikoFM)**, **"Devil Trigger" (Iron Reich)** and **"Carnival" (Kosinus Arts)**. — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)
- The game description, the Miraheze wiki and the changelog contain no music credit or soundtrack mention. — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign); [Miraheze Version History](https://anaveragecampaign.miraheze.org/wiki/Version_History)

### Inferences
- The track names suggest a **meme-adjacent mix**: chill lo-fi, probably for camp or lobby; a high-energy "Devil Trigger" track, likely boss music, whose title evokes the famous Devil May Cry 5 song; and a carnival theme. This fits the "references and random stuff" brief. Which track plays where is my guess.
- The game likely relies on Roblox's licensed music catalogue rather than commissioned music, which suits a 4-person team.

### Gaps
- I could not hear in-game audio. SFX style (hit sounds, UI clicks, dice sounds) is unverified.
- I could not confirm whether "Devil Trigger" here is the Devil May Cry 5 song or an unrelated library track with the same title.
- No composer was found.

---

## 5. Reception: numbers, praise, complaints and what stands out

### Takeaway
AAC is a **mid-to-large hit with a very high approval rating**:
- about **64.4M visits**, about **288.5K favourites**, **94.4% likes**
- an all-time peak of about **9.6 to 10K CCU (May 2026)**
- about 2 to 3.7K CCU daily in Nov 2026

It has a strong guide-creator ecosystem (several videos with 100K to 400K views). Praise centres on its depth, co-op D&D feel and replayability. Criticism, most visibly from YouTuber Eclipse, targets **RNG-heavy combat, hidden information and trial-and-error, matchmaking friction and difficulty**. The fanbase defended the game loudly in the comments.

### Cited Findings
**Statistics (14 Nov 2026 unless noted):**
- Rolimons:
  - 64,383,537 visits; 288,534 favourites
  - **94,152 up / 5,610 down (94.38%)**
  - 2,069 playing at capture; **all-time peak 9,633 CCU (31 May 2026)**; 30-day peak 5,866; 7-day peak 4,121; 24h peak 3,677
  - average playtime **26.06 min**; average 22 players per server
  - no gamepasses or badges listed
  — [Rolimons](https://www.rolimons.com/game/80734098185936)
- Roblox page: 1,912 active; 288,540 favourites; 64.3M+ visits; 94K+ likes and 5,610 dislikes. — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)
- RoWatcher:
  - all-time peak about 10K (May 2026), "Tier 1", 93rd-percentile RPG
  - **estimated** about $24,965 per month in revenue at 60% confidence (an estimate, not verified)
  - its overview block also shows stale figures (18.2M visits, 95.02% likes) that conflict with its own current list
  — [RoWatcher](https://rowatcher.com/games/7359962123/an-average-campaign-alpha-v0-5-1)
- Timeline: experience created 10 Mar 2025. The earliest dated changelog entry is v0.3 (31 Oct 2025). An "Anniversary" patch v0.5.1.4 shipped on 10 Oct 2026, suggesting a public launch around Oct 2025. Updates are frequent, about 25 versions in 12 months. — [Roblox games API](https://games.roblox.com/v1/games?universeIds=7359962123); [Miraheze Version History](https://anaveragecampaign.miraheze.org/wiki/Version_History)

**YouTube ecosystem** (sorted by views at 14 Nov 2026):
- RoadToKing "(OUTDATED) The ULTIMATE Minmax Class Guide": 412K, 7 months ago
- Pandrew "What Happens If You Survive The MONK For 99 Turns?!": 379K, 2 months ago
- RoadToKing "Complete BOON GUIDE": 160K
- RoadToKing "ULTIMATE BEGINNERS GUIDE": 156K
- Pandrew "How To Unlock Potential: Bunny Solo!": 154K
- Jericho "GETTING SHADE SOLO": 127K
- Dripply "This class makes 2x look easy": 127K
- **Eclipse "ROBLOX's Average Campaign Is Everything I CAN'T STAND With Turn Based Games": 112K, 11 months ago**
- Most top videos are guides or minmax builds.
- Source: [YouTube search, sorted by views](https://www.youtube.com/results?search_query=%22An+Average+Campaign%22+roblox&sp=CAM%253D)
- Community infrastructure: an official Trello ("an-average-campaign-official-trello"), a game Discord, a separate community boon Discord ("Above Average Campaign"), and a Miraheze wiki (530 articles, 657 users, about 9.5K edits). — [YouTube search results (descriptions)](https://www.youtube.com/results?search_query=%22An+Average+Campaign%22+roblox&sp=CAM%253D); [Miraheze Main Page](https://anaveragecampaign.miraheze.org/wiki/Main_Page)
- Third-party guide sites (ProGameGuides, Gamezebo, AllThings.How, BloxInformer, DeltiaGaming) all publish tier lists and guides, a sign of mainstream Roblox attention. — [AllThings.How](https://allthings.how/an-average-campaign-classes-and-subclasses-ranked-for-v0-3/); [Gamezebo](https://www.gamezebo.com/walkthroughs/an-average-campaign-tier-list/); [ProGameGuides](https://progameguides.com/roblox/an-average-campaign-class-tier-list/)

**Criticism:**
- Eclipse's video description reads: "This was so annoying to play it's actually kinda crazy". YouTube's auto-generated summary (AI, so treat with caution) lists his complaints as **party matchmaking issues, RNG-heavy combat, and a trial-and-error loop requiring knowledge of NPCs to progress**. — [Eclipse review](https://www.youtube.com/watch?v=VYNmn4Tp1Jo); [YouTube search summary](https://www.youtube.com/results?search_query=%22An+Average+Campaign%22+roblox&sp=CAM%253D)
- From comments, he was frustrated that one NPC choice ("Reject his offer") gave nothing while another ("Learn his techniques") gave a reward. He also complained that the vampire gave no buff "because I didn't know", that secret achievements exist, and that turn-based combat "takes no skill". — [Eclipse review, comments](https://www.youtube.com/watch?v=VYNmn4Tp1Jo)
- Even fans conceded some tropes "are flawed" (344 likes). — [Eclipse review, comments](https://www.youtube.com/watch?v=VYNmn4Tp1Jo)
- The description itself warns: "intended to be difficult and may be frustrating", alpha, "bugs that may stall/freeze your game". — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)
- A Wetlag run caption joked "Why you so sexy?" about the item UI, a casual sign that the UI layout was confusing at first (anecdotal). — [Wetlag video ~10:00](https://www.youtube.com/watch?v=e83JrLu2YZA&t=600s)

**Praise and defence:**
- The Eclipse video drew 1,652 comments, mostly defending the game. Top comments:
  - "Remember guys, you have free will…" (1.1K likes)
  - "I feel like they were going for a d&d style game which is why it would recommend a group of people and explains how the game works" (721)
  - "so many people were able to play this game … for hours and hours … the turn based combat is fun and while it's not insanely complicated it's still good" (208)
  - "the game literally says it should be multiple runs and information is from each one is needed" (395)
  — [Eclipse review, comments](https://www.youtube.com/watch?v=VYNmn4Tp1Jo)
- Video framings: "They made D&D in Roblox!" (title), and "if Arcane Lineage merged with a dungeon crawler" (search snippet description of a co-op video). — [YouTube: They made D&D in Roblox!](https://www.youtube.com/watch?v=LVZSnK2I-Ko); [YouTube: An Average Campaign Roblox But It's Not Average](https://www.youtube.com/watch?v=EETKDtuCd6Q)
- AllThings.How says the game is "built around dying, learning, and trying again". In its framing, the right class makes a "brutal boss" manageable, while a poor pick ends runs early. — [AllThings.How](https://allthings.how/an-average-campaign-classes-and-subclasses-ranked-for-v0-3/)

**Monetization:**
- No gamepasses or badges are listed on Rolimons. Private servers are disabled. — [Rolimons](https://www.rolimons.com/game/80734098185936); [Roblox games API](https://games.roblox.com/v1/games?universeIds=7359962123)

### Inferences
- **What makes it stand out** among Roblox RPGs:
  1. Genuine **co-op tabletop structure**: party votes, camp, narrated events and class-gated choices.
  2. **Roguelite run structure** (Slay the Spire paths) instead of an open-world grind.
  3. **Hard, secret-laden design** that feeds a big guide/minmax YouTube scene. Secrets like Shade, Potential: Bunny, Void progression and Artificer unlocks are content in their own right.
  4. **Very light monetization**, which likely helps the 94% approval.
  5. **Strong marketing art** for a game with simple in-game visuals.
- The main risks to avoid in a derivative: opaque NPC outcomes, RNG that feels unfair without visual feedback, matchmaking friction for solo players, and alpha bugs.
- CCU peaked in May 2026 (around v0.4.2.1/0.4.3) and now runs at about 20 to 40% of peak. That is healthy but past its peak. Content drops, e.g. the 31 May 2026 peak right after v0.4.3 on 30 May, clearly drive spikes.

### Gaps
- Reddit returned no threads in search. I could not access Discord, so sentiment there is unmeasured.
- Roblox's own review/comment section is not public text.
- I found no professional press reviews; coverage is guides and YouTube.
- The Store tab contents (developer products or donation items) could not be confirmed. The "donate a few bands" thumbnail hints at a donation product.
- I found no specific player complaints about mobile UI.

---

## 6. Developer statements on inspirations and design intent

### Takeaway
The only first-party statement found is the **Roblox description**: inspired by **Dungeons & Dragons, Arcane Lineage and Slay the Spire**, meant for 3 to 4 players, designed to be difficult, and "information is key". Fan wikis add **Limbus Company**, which the official description does not state.

### Cited Findings
- "Inspired by Dungeons & Dragons, Arcane Lineage, and Slay The Spire." — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)
- Design intent: difficulty, expected losses, information gathering, 3 to 4 player co-op, alpha status. — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign)
- Fan wikis list Limbus Company as an inspiration too. — [anaveragecampaign.wiki](https://anaveragecampaign.wiki/); [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- huhuzh owns the group and is credited with scripting and UI, so the utilitarian UI is a solo-programmer design. — [Roblox game page](https://www.roblox.com/games/80734098185936/An-Average-Campaign); [Rolimons group](https://www.rolimons.com/group/35729591)

### Inferences
- The red/black anime key art (thumbnails 1 and 3) fits the Limbus Company influence the fans cite, though the developers have not confirmed it.

### Gaps
- I found no developer interviews, DevForum posts, Twitter/X or TikTok statements, and the Discord and Trello were not accessible. I could not verify any design-intent quotes beyond the game description.
