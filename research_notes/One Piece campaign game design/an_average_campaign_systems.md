# An Average Campaign (Roblox): Gameplay Systems Breakdown

Research date: 2026-11-14. Live version at time of research: **Alpha v0.5.2** ("Cauldro's Return", released 2026-10-26). Many detailed numbers come from fan wikis that were written for older builds (v0.3 to v0.4.6), and each is labelled with its version. The game is in Alpha and has no granular public patch log, so treat every number as subject to change.

**IMPORTANT PREMISE CORRECTION:** The brief says the game mixes turn-based party combat with "Undertale-style bullet-hell dodging." I found **no evidence** of any bullet-hell, soul-box, or real-time dodging phase in An Average Campaign. Every source describes **purely turn-based, stat- and RNG-driven combat**: block and dodge are percentage chances rolled per hit, and there is no player-controlled dodge. The game's own description names Dungeons & Dragons, Arcane Lineage and Slay the Spire as inspirations, not Undertale. If the developer needs the bullet-hell layer, it will have to come from a different reference game (see Gaps under Combat).

---

## 1. Identity: confirming the right game

### Takeaway
"An Average Campaign" is Roblox universe **7359962123** (root place **80734098185936**). It is owned by the Roblox group **"An Average Campaign" (group ID 35729591, owner `huhuzh`, display name "iBliz")**, which fan sites and press call "Regicide Studio". It was created 2025-03-10 and is a large, active title: about 64.4M visits and 288.5K favorites on 2026-11-14. A separate "[TESTING]" place exists and should not be confused with the main game.

### Cited Findings
- Official Roblox API record: name "An Average Campaign [Alpha v0.5.2]"; creator type Group, ID 35729591, name "An Average Campaign"; rootPlaceId 80734098185936; created 2025-03-10T21:35:29Z; updated 2026-11-14T07:31:56Z; visits 64,384,618; playing 1,912 (at fetch time); maxPlayers **50** (server size); favoritedCount 288,540; genre RPG / Turn-based RPG; **createVipServersAllowed: false** (no private servers) — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7359962123)
- The game description, summarized: a simple, classic roguelike for **3–4 players that supports 1–5**, with inside jokes and references, inspired by **Dungeons & Dragons, Arcane Lineage, and Slay The Spire**. It is in Alpha with known bugs and warns: "This game is intended to be difficult and may be frustrating to some people." — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7359962123)
- Group 35729591 "An Average Campaign": owner huhuzh ("iBliz", verified badge), 45,009 members — [Roblox Groups API](https://groups.roblox.com/v1/groups/35729591)
- Destructoid (Oct 2025) links the same group ID under the URL slug "Regicide-Studio" and names Regicide Studio as the developer. The group has apparently been renamed since. — [Destructoid](https://www.destructoid.com/an-average-campaign-trello/)
- A fan guide lists the Regicide Studio members as huhuzh, Kario777, Yuml_I, and FringleMeench — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Rotrends tracker: v0.5.2, created Mar 10 2025, **94.4% rating from 99.8K votes**, peak 9.6K CCU, **0 gamepasses, 18 developer products** — [Rotrends](https://www.rotrends.com/game/7359962123/An-Average-Campaign-Alpha-v051)
- A separate "An Average Campaign [TESTING]" place (universe 8988844066) exists, with about 7K visits per tracker snippets — [Rotrends TESTING](https://www.rotrends.com/game/8988844066/An-Average-Campaign-TESTING)
- Official resources: Trello board `trello.com/b/12spe143` and the Regicide Studio Discord. The developers have released no official wiki. — [Destructoid](https://www.destructoid.com/an-average-campaign-trello/). The most detailed community wiki is the Miraheze AAC wiki, last edited 2026-11-14 — [Miraheze Main Page](https://anaveragecampaign.miraheze.org/wiki/Main_Page)

### Inferences
- The game title on Roblox carries the version string ("[Alpha v0.x.x]"), which is why trackers show several "different" titles (v0.4.5, v0.4.6, v0.5.0, v0.5.1). These are all the same experience.

### Gaps
- I could not retrieve a full Roblox web page render or the exact public release date. The created date (2025-03-10) may be earlier than the public launch. Version History suggests public updates were heavy from v0.3 (2025-10-31) onward.

---

## 2. Core loop, session structure, and party formation

### Takeaway
The loop is a **Slay the Spire-style roguelite run in a D&D wrapper**. In the lobby you pick a class, race, boons and skill tree, then form a party of 1–5 at an NPC and start a run. The run is a sequence of **combat rounds**. After each one the party chooses among **3 random encounters, a Scavenge, or a Short Rest**. Players level up, loot and craft during the run, and fight area bosses. The run ends when the **entire party falls** or the final boss is beaten. Permanent currency (**Cealts**) and class Prestige carry over between runs.

### Cited Findings
- Party size: designed for 3–4, supports 1–5. Solo is described as "extremely difficult." — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Lobby flow: choose a base class and an available race, review Boons and the class Skill Tree, then create or join a party — [AAC Wiki (pages.dev) v0.5.0](https://an-average-campaign-wiki.pages.dev/)
- Lobby NPCs (v0.4.6): **Magic Mirror** (classes, races, Skill Tree), **Tavern Master** (Boons, bought with Cealts), **Aura Farmer** ("Form or join a party; start the campaign"), and **Puppet** (event boons) — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- The current wiki also lists Illinivich, Battle Master, The Veteran, and Noble as lobby NPCs, without stating their functions — [Miraheze NPCs](https://anaveragecampaign.miraheze.org/wiki/NPCs)
- Server size is 50 (lobby), and private (VIP) servers are not allowed — [Roblox Games API](https://games.roblox.com/v1/games?universeIds=7359962123)
- Run flow: "After each round (a fight against enemies), you're offered three Encounters," or you may choose **Scavenge** or a **Short Rest** — [Miraheze Encounters](https://anaveragecampaign.miraheze.org/wiki/Encounters)
- A v0.4.6-era guide gives the same flow: after each combat you reach camp and choose one of three random encounters, rated by difficulty stars — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- "If your entire party falls, the run ends." There is no in-game tutorial. — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- At the end of combat, loot can be shared through a **shared Stash** that holds items and Gold — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/). "Party gold" was added in v0.4.1.3 (2026-04-01). — [Miraheze Version History](https://anaveragecampaign.miraheze.org/wiki/Version_History)
- **Rejoining** (reconnecting to a run in progress) was added in v0.4.2.1 (2026-05-18) — [Miraheze Version History](https://anaveragecampaign.miraheze.org/wiki/Version_History)
- A full completion earns about **70 Cealts**, and the Sewer adds none (v0.4.6) — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)

### Inferences
- Parties form only in the shared 50-player lobby (no VIP servers). Friends group up by joining the same public server and using the Aura Farmer NPC. There is no evidence of cross-server matchmaking.
- A standard full run has about 20 combat rounds (Forest 8 + Dungeon 12), plus optional branches (see Section 6), so a session is long. Rejoining was added to protect that time investment.

### Gaps
- Exact party-formation UI (invite, public listing, ready check), whether runs teleport to a separate reserved server, and run time in minutes were not documented in any source I could access.

---

## 3. Combat: turns, actions, defense, offense (no bullet-hell)

### Takeaway
Combat is **fully turn-based, with no real-time input**. Turn order comes from an **Initiative** roll. On a turn a character picks **Fight** (an ability or attack), **Items**, or **Focus** (gain Energy). You **cannot flee or skip**. Abilities cost **Energy** (NRG) and have **cooldowns (CD)**. Defense is passive and probabilistic: each hit rolls separately against **Block** chance (reduces damage by Block DR) and **Dodge** chance (negates the hit). Enemies also bank Energy and unleash bigger attacks at high Energy, which acts as a turn-based "telegraph".

### Cited Findings
**Turn structure and actions**
- "Fully turn-based. You cannot flee or skip turns." Actions: **Fight** (attacks/spells), **Items** (consumables and scrolls), **Focus** (regenerates Energy) — [an-average-campaign.pages.dev (v0.4.6)](https://an-average-campaign.pages.dev/)
- Initiative: higher acts first; +1 to min/max per level and per 20 DEX; **summons always act last** — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/). Gamepur also says turn order is decided by each character's Initiative (search snippet only; the page returned 403) — [Gamepur](https://www.gamepur.com/roblox/an-average-campaign-beginners-guide)
- Energy gain: a **chance** for +1 Energy at turn start — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/). The Genyosei race's perk is "guaranteed 2 energy per turn; energy cap 8", which implies default gain is probabilistic and capped — [Miraheze Customization](https://anaveragecampaign.miraheze.org/wiki/Customization)
- One community wiki snippet says Focus grants more energy "at the cost of vulnerability" (unverified; search snippet only) — [anaveragecampaign.wiki](https://anaveragecampaign.wiki/). The Status Effects page lists a status named **Focused: +30% damage taken** — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)
- Ability format: each ability lists Energy cost (NRG), cooldown (CD), damage type, base damage, and stat-scaling coefficients. Example: **Lunge (Linked Sword): 2 NRG, 6 CD, 11 base damage, STR scaling 0.015, applies 3 Vulnerable** — [Miraheze Equipment](https://anaveragecampaign.miraheze.org/wiki/Equipment)
- Some subclasses pay **HP instead of Energy**, for example Bloodkin Warlock — [AllThings.How (v0.3)](https://allthings.how/an-average-campaign-classes-and-subclasses-ranked-for-v0-3/)
- Main-class abilities cap at Lv5 and subclass abilities at Lv8 — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)

**Defense: block, dodge, guard (all stat/RNG based)**
- "Multi-hit: Each hit rolls Block and Dodge separately." — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- STR adds Block chance (+0.375%/pt), DEX adds Dodge (+0.175%/pt), and CON adds Block Reduction (+0.375%/pt) (v0.4.6) — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- **Guard**: "enters a stance that blocks any incoming attack and increases Block DR by 30%," and can block unblockable attacks at half effectiveness. **Guardbroken** halves Block DR — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)
- Dodge cap is **80%**, rising to **85%** with the Flow State boon — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects). This conflicts with another fan wiki's claim that dodge "asymptotes near 60%" (search snippet only) — [an-average-campaign.wiki stat breakpoint guide](https://an-average-campaign.wiki/guides/stat-breakpoint-guide/)
- Accuracy debuffs give enemies a miss chance, for example Blinded 15% and Mental Instability 10%. **Counter** stacks counterattack "when hit or dodging." — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)
- The Status Effects page describes every mechanic in turns and mentions no timing-based or real-time inputs — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)

**Damage model**
- Formula: `Damage × StatScaling × (1 + ΣAdditive) × (ΠMultiplicative) × (1 + ΣReplication)` — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)
- **16 damage types**: True, Chaos, Physical, Force, Psychic, Fire, Cold, Bleed, Holy, Poison, Acid, Thunder, Lightning, Necrotic, Dark, Void. Enemy families carry resistance tags, for example Demonic takes 2x Holy, Skeletal and Construct are immune to Bleed, and Ethereal is immune to Poison. True damage bypasses block and resistances — [Miraheze Damage Modifiers](https://anaveragecampaign.miraheze.org/wiki/Damage_Modifiers)
- DoTs tick at the **start of the afflicted target's turn** (healing first, then DoT). Duration statuses lose 1 at the start of the afflicted target's turn. Stack statuses don't decay. **Permanent** statuses persist between fights for the whole run — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)
- DoT formulas: Bleed 2 + 0.5x; Burn 2.8 + 0.2x; Poison 1 + HP×0.025 + X×0.5. Stunned: cannot act or gain energy, then **2 turns of stun immunity** — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)
- Crit from STR/DEX/INT/LCK; Lifesteal heals a % of damage dealt — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)

**Enemy behavior and telegraphing**
- The Giant boss uses "Pummel/double-strike at 2 Energy; sweeping edge at high Energy." Bone Drake has an opening window of about 1.5 turns before "Dreadlord's Call" — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- The Fear status notes that "Bosses, mini-bosses, and trainers gain only 1 energy per turn" — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)

**Multiplayer scaling (v0.4.6)**
- Each extra player adds **+12.5% enemy ATK and +50% enemy HP**. Solo gets **-5% enemy Dodge/Block** — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)

### Inferences
- The "attack pattern presentation" that a bullet-hell game would show as projectiles appears here as **enemy Energy accumulation** (big moves at high Energy) and boss phase windows. Players answer with Guard and other buffs, debuffs (Blind, Fear, Stun), and target priority, not with movement.
- Player offense also has no timing minigame or aim bar. Output is determined by ability base damage, stat scaling, crit rolls, and stacking buffs and debuffs.

### Gaps
- **The Undertale-style bullet-hell element could not be found for An Average Campaign at all.** The brief's premise may come from a different game. A search turned up unrelated Roblox candidates with Undertale-style systems: The Campgrounds, Undertale Multiverse Madness, and Eternal Star (a DevForum thread about building an Undertale-style battle system). None was confirmed as a turn-based party RPG with bullet-hell dodging — [DevForum: The Campgrounds](https://devforum.roblox.com/t/the-campgrounds-2d-rpg-story-game-roblox-undertale/2131536); [DevForum: Undertale-style battle system](https://devforum.roblox.com/t/how-would-i-go-about-making-an-undertale-style-battle-system/4028030)
- I could not watch gameplay video, so the absence of any minor timing element is confirmed by sources' silence and turn-only descriptions, not by direct observation.
- Whether **Guard** is a menu action or only an ability or status, and the default Energy cap and exact per-turn gain chance, are undocumented. A v0.4.1.2 note mentions "regeneration and guarding changes" without detail.
- No information on how enemies choose targets (aggro rules), beyond Knight taunts and the Gloom Stalker "Shrouded" status dropping aggro.

---

## 4. Classes, subclasses, races, and party roles

### Takeaway
There are **7 base classes** (Warrior, Rogue, Mage, Priest, Brawler, Ranger, Bard), each tied to two primary stats. Each has **2–3 subclasses** (18–19 total) that are **unlocked mid-run by meeting a trainer encounter in a specific area** and last the rest of the run. **Races** are account-level modifiers bought or unlocked with achievements. Roles follow tank, DPS, healer and support lines, but the defining hook is **area-gated subclass choice** during the run.

### Cited Findings
- Class stat pairs (v0.4.6): Warrior STR+CON; Rogue DEX+LCK; Mage INT+LCK; Priest FTH+CON; Brawler STR+DEX; Ranger DEX+INT; Bard CHA+INT — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Subclasses by unlocking region (v0.4.6):
  - Warrior: Rampager (Forest), Knight (Dungeon), Grudge Settler (Mines)
  - Rogue: Assassin (Forest), Drifter (Dungeon), Shade (Dungeon/special, via Void Herald)
  - Mage: Bloodkin Warlock (Forest), Necromancer (Dungeon), Artificer (Mines)
  - Priest: Druid (Forest), Zealot (Dungeon), Occultist (Sewer)
  - Brawler: Elementalist (Forest), Beast (Dungeon), Evolved (Sewer)
  - Ranger: Fey Wanderer (Forest), Gloom Stalker (Dungeon)
  - Bard: Bard of Valor (Forest), Bard of Whispers (Mines)
  - "Subclasses last the entire run." Trainer encounters include Powerful Stranger, Strange Man, Resting Druid, Meditating Man, Wild Beast, and A Vat of Acid. Entering the Dungeon lets you pre-select any previously unlocked subclass.
  - [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Conflict: Miraheze places Bard of Whisper in the Dungeon, not the Mines — [Miraheze Customization](https://anaveragecampaign.miraheze.org/wiki/Customization). The current wiki counts 19 subclasses — [AAC Wiki (pages.dev)](https://an-average-campaign-wiki.pages.dev/)
- The official Trello Fey Wanderer card: choosing to learn from the man "changes your class from Ranger to Fey Wanderer" — [Official Trello JSON](https://trello.com/b/12spe143.json)
- Role and ability examples (v0.3, Jan 2026):
  - Warrior: frontline tank or support bruiser. Rampager's Overpowering Slash stuns; Knight has Bulwark Rush, Warlord Strike (Fear), and taunts.
  - Priest: healer and buffer. Druid gives party regen and a bear companion; Zealot deals AoE Holy damage and Blinds.
  - Mage: glass cannon. Necromancer has single-summon skeletons; Bloodkin Warlock pays HP for its skills.
  - Ranger: Gloom Stalker's Hunter's Mark and Shrouded; Fey Wanderer's Fey Wisp summon.
  - Brawler: Beast's Unleash gives lifesteal; Elementalist has 4 stances (Water, Fire, Wind, Earth).
  - Rogue: Assassin builds Bleed stacks; Drifter has High Noon, which pays gold on kills, and Pocket Sand.
  - [AllThings.How (v0.3)](https://allthings.how/an-average-campaign-classes-and-subclasses-ranked-for-v0-3/)
- **Jack of All Trades** is a 1-slot, 200-Cealt Boon, not a class. It disables subclasses and the Skill Tree and starts at +35 HP — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/); [AAC Wiki (pages.dev)](https://an-average-campaign-wiki.pages.dev/)
- Races (current wiki lists 14, some unobtainable). Examples:
  - Human (default): an extra stat point every other level, highest stat ×1.05.
  - Elf: unlocked by beating the Giant, 50 Cealts.
  - Dwarf: unlocked by beating the Mines boss, 50 Cealts; ×1.1 max HP, crafting bonus.
  - Kobold: 200 Cealts.
  - Withered: 300 Cealts; regenerates 8% of missing HP per turn.
  - Lunaeia: 200 Cealts; lifesteal per bleed stack.
  - Drakai: unlocked by the Timestream true ending.
  - Nyvari: unlocked by an achievement.
  - Gaia Dweller: ability set depends on equipped weapon type.
  - Dullahan: unlocked by all 11 Cauldro's Return 2026 achievements.
  - [Miraheze Customization](https://anaveragecampaign.miraheze.org/wiki/Customization)
- Older values conflict (v0.4.6): Withered regenerated 10% and was reduced from 500 to 300 Cealts; Lunaeia cost 500 Cealts through a 5-step quest; only 4 races existed then — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Generic guide advice suggests 1–2 tanks, 2–3 DPS and 1–2 supports. This source is low-specificity and describes boons inaccurately (as world drops), so treat it as low reliability — [Noleep (Nov 2025)](https://noleep.com/en/an-average-campaign-roblox-beginners-guide-best-classes-boons-and-team-strategies-explained)

### Inferences
- Subclass-by-encounter design means a run's route (which area and which encounter you take) determines your build. This is a strong roguelite hook that maps easily onto "meeting a mentor on an island".

### Gaps
- Full per-class ability lists with current (v0.5.x) energy costs were not retrievable. v0.5.1 had "major class expansions," which may have changed kits.

---

## 5. Progression: in-run and meta, death and wipe

### Takeaway
**In-run**: XP levels (cap about 25 per run, +3 stat points and +2 Max HP per level), gold, loot drops, crafting and equipment, and subclass unlocks. **None of the gear carries over.** **Meta**: Cealts (soft currency) buy Boons, Races and Prestige levels. **Prestige** (up to 25 per class) is a permanent class level that grants Skill Tree points. A **Game Modifiers** difficulty system trades difficulty for Cealt/XP multipliers. There is **permadeath per run**: a full party wipe ends it, but individuals can be revived with gold at specific encounters or with Robux.

### Cited Findings
- Leveling: +3 stat points and +2 Max HP per level; skills unlock at set levels; per-run cap about 25 (v0.4.6) — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Stats per point (v0.4.6):
  - STR: Crit +0.125%, Crit DMG +0.2%, Block +0.375%
  - DEX: Crit +0.15%, Crit DMG +0.25%, Dodge +0.175%
  - CON: +1 Max HP, Incoming Healing +0.25%, Block Reduction +0.375%
  - INT: Energy Gain +0.2%, Crit +0.075%, Crit DMG +0.15%
  - FTH: Energy Gain +0.2%, Outgoing Healing +0.7%
  - LCK: Crit +0.3%, Crit DMG +0.5%
  - CHA: Bard support scaling
  - [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Equipment:
  - 11 weapon types: Swords, Greatswords, Hammers, Daggers, Pistols, Fists, Bows, Staffs, Bloodcraft, Tomes, Instruments. Weapons can carry built-in abilities and passives.
  - 4 armor slots: Helmet, Chestpiece, Leggings, Boots.
  - Charm-type slots: Charms, Vials, Quivers, Shards, Spell Scrolls.
  - Sources: crafting, Souls, Scavenge, merchants, enemy drops, bosses.
  - [Miraheze Equipment](https://anaveragecampaign.miraheze.org/wiki/Equipment)
- One **consumable slot**, auto-activated at fight start. Crafted gear "lasts only for the current run". Bosses drop **Souls**, used as crafting components that reveal hidden recipes — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Consumables include Healing Potion (12% Max HP + 20 HP), Energy Potion (2 Energized), and foods such as Goblin Feast — [Miraheze Items](https://anaveragecampaign.miraheze.org/wiki/Items)
- Meta currency: **Cealts** are earned from runs and spent on Boons, Races, and Prestige. Prestige max is 25 and costs about 1,625 Cealts to buy all levels. Each Prestige level gives 3 Skill Points. A Skill Tree reset costs 50 Cealts (v0.4.6) — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- Skill Tree: 7 unlockable abilities per class. Reach level 3/5 on a node to open adjacent nodes; nodes go to Tier 5. "Prestige is essentially your permanent level in a specific class," gained through EXP or by buying it — [Miraheze Customization](https://anaveragecampaign.miraheze.org/wiki/Customization)
- **Boons**: **5 slots**, each boon costing 1–5 slots, bought with Cealts at the Tavern Master; most need an achievement first. Examples:
  - Force of Will (1 slot, 30 Cealts): survive one fatal hit per encounter at 5 HP.
  - Flow State (3 slots, 100): stacking crit damage and dodge per dodge.
  - Overtime (3 slots, 100): 0.7x/0.8x/0.9x damage on turns 1–3, then 1.2x and +1 energy.
  - Potential: Bunny (5 slots, 300): 0.25x damage plus a Bunny companion.
  - Pay to Win (2 slots, 50): spends up to 500 in-run gold per combat for buffs.
  - [Miraheze Customization](https://anaveragecampaign.miraheze.org/wiki/Customization)
- **Game Modifiers** (difficulty): "positive" modifiers make the run harder and raise Cealt/XP gain; "negative" ones make it easier, lower gains, and disable achievements. Examples:
  - Towering Forces: enemy max HP ×1.35, +20% Cealt.
  - Glass Soul: damage taken ×1.25, +20% Cealt.
  - Level 1: boons and skill trees disabled.
  - Surprise Round: enemies gain +100 initiative.
  - Waning Evil: enemy HP ×0.75, -30% Cealt.
  - [Miraheze Game Modifiers](https://anaveragecampaign.miraheze.org/wiki/Game_Modifiers)
- Death and wipe: a full party wipe ends the run. Revival options:
  - **Altar** (Dungeon, 250 Gold): full revive and full heal.
  - **Travelling Necromancer** (Dungeon, 100 Gold): revive at partial HP.
  - [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
  - A **"Revive in a run"** developer product costs 50 Robux — [Roblox Developer Products API](https://apis.roblox.com/developer-products/v2/universes/7359962123/developerproducts?limit=50)

### Inferences
- What persists is power options (Boons, Races, Prestige skill points), not items. This is a Hades/Slay the Spire-style meta layer that keeps each run's itemization fresh.
- Game Modifiers work as a Hades "Heat"-style ascension system for replayability.

### Gaps
- Whether a dead player stays dead for the rest of the run absent revival, or auto-revives at the next area or boss, is not stated. Exact level-cap behavior in v0.5.x and XP per fight are also undocumented.

---

## 6. World and map structure, areas, bosses

### Takeaway
The structure is a **linear, two-act campaign with optional branch areas**, not an open hub or node graph. Each act is a fixed number of **stages (rounds)**. Between stages the party picks from **3 weighted-random encounters**, so the route is procedurally varied but area order is fixed. Act 1 is the **Forest** (8 stages, boss: the Giant), with an optional **Dwarven Mines** branch (7 stages, boss: Piloted Hearth Monarch). Act 2 is the **Dungeon** (12 stages, boss: Bone Drake), with an optional **Sewer** branch (5 stages, boss: Scientist). A permanent separate one-shot mode, **Timestream Entanglement**, has its own linear route and true ending.

### Cited Findings
- Areas table: Forest (Main, 8 stages, Giant, 20 unique encounters); Dwarven Mines (Forest sub-area, 7 stages, Piloted Hearth Monarch, 12); Dungeon (Main, 12 stages, Bone Drake, 21); Sewer (Dungeon sub-area, 5 stages, Scientist, 9) — [Miraheze Areas](https://anaveragecampaign.miraheze.org/wiki/Areas)
- Branch access:
  - Mines are entered by fighting the Dwarves at the **Elven Camp** encounter, which appears in rounds 4–7.
  - Completing the Forest **or** the Mines unlocks the Dungeon.
  - The Sewer is reached through the **Ominous Manhole** encounter, which appears in rounds 3–8.
  - [Miraheze Areas](https://anaveragecampaign.miraheze.org/wiki/Areas); [Miraheze Encounters](https://anaveragecampaign.miraheze.org/wiki/Encounters)
- Dungeon mini-bosses: Devilman, Mr Bones and Baby can appear from stage 3, and The Master from stage 4 — [Miraheze Areas](https://anaveragecampaign.miraheze.org/wiki/Areas). Mr. Bones requires a Mysterious Key or a Rogue in the party — [Miraheze NPCs](https://anaveragecampaign.miraheze.org/wiki/NPCs)
- **Void Herald** is a Dungeon portal boss, used to unlock Shade — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/). The current wiki lists 13 bosses and 4 faction-aligned biomes — [AAC Wiki (pages.dev)](https://an-average-campaign-wiki.pages.dev/)
- Encounter weighting:
  - Each encounter has a weight ("Wt").
  - Class raises some weights: a Warrior raises A Powerful Stranger and Knight's Caravan to 7.
  - Items raise some weights: Adventurer's Compass raises Elven Camp and Ominous Manhole to 30; Summoning Star raises Portal in the Dungeon to 20.
  - Boons raise some weights: The Chosen One raises The Sword in the Stone.
  - [Miraheze Encounters](https://anaveragecampaign.miraheze.org/wiki/Encounters)
- **Timestream Entanglement One-Shot** (v0.5.0, Aug 2026, permanent):
  - Areas: Empire, Thieves' Den, Ancient Battlefield, Ancient Ruins, Timestream.
  - Main bosses: The Snatcher, The Duelist, and **Aion** (final). Optional bosses: Galdamir (fighting pits) and twisted Alar (Ancient Ruins).
  - **True ending**: kill all optional and main bosses in one run, so Aion spawns as "Aion, Son of the World Tree" with Temporal Reset. Rewards: Drakai race, Master of Time title, Time Keeper's Mask.
  - Fixed upgrade points (for example, a subclass upgrade at Empire 4/5) and fixed shops (Tavern, E'Tali Shop 1/2).
  - [Miraheze Timestream Entanglement](https://anaveragecampaign.miraheze.org/wiki/Timestream_Entanglement); [Miraheze Events](https://anaveragecampaign.miraheze.org/wiki/Events)

### Inferences
- The structure is "linear acts with fixed stage counts, plus weighted-random encounter choices between fights, plus optional branch areas gated by rare encounters." It is very portable to a One Piece "island-to-island voyage" with optional detour islands.

### Gaps
- Whether entering a sub-area (Mines or Sewer) replaces the remaining main-area stages or adds to them is not explicit. Whether the Bone Drake is the final boss of the standard campaign, or there is a further final area in v0.5.x, is unconfirmed.

---

## 7. Non-combat encounters: events, skill checks, shops, rests, NPCs

### Takeaway
Between fights, the party chooses from **narrative "Encounters"**: shops, **stat skill checks** (percentage success that scales with a party member's stat), **subclass trainers**, healing and buff events, mini-boss challenges, and sub-area gateways. They can also pick **Scavenge** (area loot tables) or a **Short Rest** (heal). This is the "D&D" layer: text choices with stat-gated outcomes.

### Cited Findings
- Forest encounter mix: 3 shops, 6 normal, 4 skill checks (STR/DEX/INT/CHA), and 7 subclass trainers. Scavenge spots: The Thicket, The Camp, The Riverbank — [Miraheze Areas](https://anaveragecampaign.miraheze.org/wiki/Areas)
- Encounter rosters per area: Forest 21, Mines 12, Dungeon 23 (plus conditional), Sewer 9 (for example Mystic River, Grandma's House, Potion Seller, Wizard Tower, The Altar, Carnival, Rat King's Hideaway) — [Miraheze Encounters](https://anaveragecampaign.miraheze.org/wiki/Encounters)
- Skill-check formulas from the **official Trello**:
  - Potion Seller: needs a teammate with 20+ INT; success = 20% + INT×4%; failure risks instant death.
  - Busted Caravan: success = 10% + STR×3.5%; success pays 30 gold; failure triggers a fight with 2 Rifle goblins and a Noble goblin.
  - Wizard Tower: success = -10% + DEX×3%; loot includes spell scrolls and staves.
  - [Official Trello JSON](https://trello.com/b/12spe143.json)
- Buff and heal events (Trello):
  - Mystic River: swimming gives a full HP heal.
  - A Meditating Man: +2% Energy Gain.
  - Strange Man: +5% Crit Chance.
  - A Powerful Stranger: chasing a butterfly gives +1 Stat Point.
  - Several events (Strange Man, Void Interloper) end in a forced fight.
  - [Official Trello JSON](https://trello.com/b/12spe143.json)
- Rest: heal 10 HP or 15% Max HP, whichever is higher; rest nodes heal more when the party lacks a healer (v0.4.6) — [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- In-run vendors and services: Wanderer's Wares, The Gob-Stop, Travelling Merchant, Grob's Emporium, The Unblinking Eyes, and Crimson Forge (crafting), plus the Altar and Necromancer revive services — [Miraheze Encounters](https://anaveragecampaign.miraheze.org/wiki/Encounters); [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
- "Scavenging" as a system was added in v0.4.2.1 (May 2026) — [Miraheze Version History](https://anaveragecampaign.miraheze.org/wiki/Version_History)

### Inferences
- There are no real "puzzles". The non-combat layer is choice-plus-stat-roll vignettes, which are cheap to author and highly replayable.

### Gaps
- The meaning of the difficulty stars on encounters, Scavenge reward tables, and Short Rest numbers in v0.5.x are not documented. The Trello snapshot date is unknown, so those formulas may be outdated.

---

## 8. Stress, sanity, morale, and other resources

### Takeaway
I found **no stress, sanity, or morale meter** of the Darkest Dungeon type. The resource economy is **HP, Energy** (per-turn chance plus the Focus action), **in-run Gold** (shops, revives, the Pay to Win boon), **crafting materials and Souls**, and **meta Cealts**. Morale-like effects exist only as combat statuses.

### Cited Findings
- Morale-like statuses:
  - Rallied: +20% damage, 0.9x damage taken.
  - Psyched: +35% damage.
  - Demoralized: -5% damage.
  - Fear: 0.9x damage and no natural energy gain.
  - Exhaustion: up to 3 stacks that reduce damage, healing, and max HP.
  - Permanent statuses persist across the run.
  - [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)
- Energy modifiers: Energized, Uplifted (+1 energy per turn), Null Essence (sets energy to 0), and Ballad of Blood (sets enemy energy chance to 0%) — [Miraheze Status Effects](https://anaveragecampaign.miraheze.org/wiki/Status_Effects)

### Inferences
- Energy is the game's central tactical resource: it is a randomized trickle that Focus can force, and abilities spend it against cooldowns.

### Gaps
- I found no source mentioning any sanity or stress system, which is consistent with the game having none.

---

## 9. Monetization and update history

### Takeaway
There are **no gamepasses**. All monetization is through **18 developer products**: Cealt bundles (with sale variants), a single-run Revive, consumable "Blessings", "Karmic Dice", and a novelty "Jumpscare Everyone." Updates come roughly every 2–6 weeks, with seasonal limited-time events and a permanent one-shot mode added in 2026.

### Cited Findings
- Developer products (Robux):
  - Cealt 1–5: 30 / 80 / 150 / 300 / 500 (sale versions 15 / 40 / 75 / 150 / 250)
  - Revive ("Revive in a run"): 50
  - Blessing of Insight: 80
  - Blessing of Wrath: 60
  - Blessing of Revival: 100
  - Karmic Dice: 1 for 25, 10 for 200, 25 for 400
  - "Jumpscare" Everyone ("Put up a random image... on everyone's screens"): 19
  - [Roblox Developer Products API](https://apis.roblox.com/developer-products/v2/universes/7359962123/developerproducts?limit=50)
- 0 gamepasses — [Rotrends](https://www.rotrends.com/game/7359962123/An-Average-Campaign-Alpha-v051)
- Exclusive or limited content: E'tali race (content-creator exclusive), Snapshot boon (Medal collaboration), event-exclusive boons such as Haunted Embers and Sugar Rush, and several unobtainable races and boons from past events — [Miraheze Customization](https://anaveragecampaign.miraheze.org/wiki/Customization)
- Version timeline (selected):
  - v0.3 Halloween (2025-10-31)
  - v0.3.3 combat UI rework (2025-11-04)
  - v0.4 class and Bone Drake reworks (2025-12-12)
  - v0.4.1 redesigned Bone Drake and Sanguine gear (2026-03-16)
  - v0.4.1.2 AoE rework and guarding changes (2026-03-19)
  - v0.4.2.1 status reworks, four new races, rejoining, Scavenging (2026-05-18)
  - v0.4.4 QoL, Devilman and Baby reworks (2026-06-15)
  - v0.4.5 Elementalist rework (2026-06-21)
  - v0.5.0 Timestream Entanglement one-shot (2026-08-17)
  - v0.5.1 class expansions and DoT changes (2026-09-15)
  - v0.5.1.4 Anniversary (2026-10-10)
  - **v0.5.2 "Cauldro's Return" (2026-10-26)**
  - [Miraheze Version History](https://anaveragecampaign.miraheze.org/wiki/Version_History)
- Events:
  - Halloween 2025 (Cauldro accessory).
  - Blood Moon (late 2025; Normal and Honor modes).
  - April Fools 2026 (Normal and True Power modes; Robloxian boon).
  - Event rules: standard Boons and Skill Trees disabled, event-exclusive weapons, sometimes an Upgrade system.
  - [an-average-campaign.pages.dev](https://an-average-campaign.pages.dev/)
  - Cauldro's Return (Halloween 2026) now lists as "Unavailable"; Timestream is "Permanent" — [Miraheze Events](https://anaveragecampaign.miraheze.org/wiki/Events)

### Inferences
- The model sells convenience and progression (Cealts skip grind for Boons, Races and Prestige; Revive), not exclusive power gamepasses. Blessings and Karmic Dice are probably run-start buffs or reroll consumables, but this is **unverified**.

### Gaps
- I could not find the effects of **Blessing of Insight, Wrath, Revival** or **Karmic Dice** in any accessible source. A search returned only unrelated Baldur's Gate 3 "Karmic Dice" pages. There is no public roadmap. The Trello was only partially readable (7M-character JSON), and no developer Discord announcements were publicly mirrored.
