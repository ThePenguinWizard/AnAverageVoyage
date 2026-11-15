# Hybrid Combat Design Patterns: JRPG Party Combat + Undertale/Deltarune Bullet-Hell Defense + Darkest Dungeon Tactics/Stress

Scope note: These notes collect reusable mechanics from the source games and from hybrids that already combine them, for a multiplayer One Piece-themed Roblox RPG. Tags used throughout:
- **[MP-good]**: works as-is or nearly as-is with several human players in one battle
- **[MP-adapt]**: works in multiplayer with a specific change (the change is described)
- **[SP-only]**: depends on one player controlling the whole party; hard to carry over

Source-quality legend: wiki pages (deltarune.wiki, undertale.wiki, darkestdungeon.wiki.gg) are community-maintained but heavily data-mined, so they are the most precise numeric sources available. Search-result summaries that I could not open in full are marked "(snippet)". Steam forum numbers are player reports, not official data.

---

## 1. Undertale & Deltarune: SOUL/bullet box, SOUL modes, attack design, ACT/MERCY, TP/graze, party handling, FIGHT bar

### Takeaway
The Undertale/Deltarune model is: one small "bullet board" box, one heart (SOUL) that is the whole party's hitbox, short self-contained attack patterns built per enemy (and combined when enemies attack together), and a resource (TP) earned by *risky* play (grazing) or by *giving up a turn* (DEFEND) that pays for party spells. Deltarune's party layer is thin and deliberate: one SOUL dodges for everyone, while the enemy attack decides *which party member's HP* is lost (targeted / random / all). This targeting split is the key idea to borrow for multiplayer.

### Cited Findings

**Origin and design philosophy (Toby Fox)**
- Fox built the battle engine before anything else in Undertale ("Everything came from that"). He found standard RPG combat dull ("I have played so many RPGs that the basic motions... aren't fun to me now"), took the interactive-battle idea from Super Mario RPG, and drew on Touhou and WarioWare to make "bite-sized bullet patterns." — [Game Developer: Game Design Deep Dive, Undertale's action-based RPG battles](https://www.gamedeveloper.com/design/game-design-deep-dive-i-undertale-i-s-action-based-rpg-battles)
- Each enemy has a few attacks; when enemies attack together their bullet patterns combine, so each formation feels distinct. Fox says combined attacks also remove the need to watch every enemy's separate animation, which he calls "a slog in older RPGs." — [Game Developer deep dive](https://www.gamedeveloper.com/design/game-design-deep-dive-i-undertale-i-s-action-based-rpg-battles)
- Encounters rarely repeat; when battles felt repetitive he added more foes. Because players don't get much stronger, keeping battles fresh was "REALLY important," and "once you master a battle, you should be able to move on." — [Game Developer deep dive](https://www.gamedeveloper.com/design/game-design-deep-dive-i-undertale-i-s-action-based-rpg-battles)
- Fox admits ACT/SPARE often reduces to "simple trial and error" and isn't as "fun" or "fair" as it could be; the payoff is novelty/funny text. — [Game Developer deep dive](https://www.gamedeveloper.com/design/game-design-deep-dive-i-undertale-i-s-action-based-rpg-battles)
- "Every monster should feel like an individual"; Fox criticized typical RPG enemies that just attack, get healed, and die ("There's no meaning to that"). — [The Escapist: Undertale Dev "Every Monster Should Feel Like an Individual"](https://www.escapistmagazine.com/v2/undertale-dev-every-monster-should-feel-like-an-individual/)
- Attack patterns express personality, e.g. Tsunderplane's attack uses the character's "tsunderesness" as its mechanic. (snippet) — [The Mary Sue interview with Toby Fox](https://www.themarysue.com/interview-undertale-game-creator-toby-fox/)
- Fox reasoned that most players are not bullet-hell experts, so there is a limit to how far difficulty can be pushed with plain dodging; boss fights instead introduce a new gimmick. He also used fewer and larger projectiles than true bullet hell to stay approachable. (snippet; exact originating article not verified in full text, likely the PC Gamer making-of) — [PC Gamer: The making of Undertale](https://pcgamer.com/the-making-of-undertale)
- Fox on Deltarune: the "smart" way to make games is reusing what you can, but in Deltarune "everything in the game is simply a container for a never before seen gimmick." — [GamesRadar](https://www.gamesradar.com/games/rpg/toby-fox-says-the-smart-way-to-make-games-is-reusing-what-you-can-but-the-way-he-makes-deltarune-is-stupid-everything-in-the-game-is-simply-a-container-for-a-never-before-seen-gimmick)

**SOUL and bullet board basics**
- The SOUL moves freely inside the bullet board, whose border encloses it; moved with arrow keys/joystick. At 0 HP the SOUL shatters (Game Over). Papyrus's attacks cannot kill: he captures you at 1 HP instead. Touching overworld hazards (lasers, Undyne's spears) starts a brief encounter where the antagonist attacks the SOUL. — [undertale.wiki: SOUL](https://undertale.wiki/w/SOUL)
- In Deltarune, holding CANCEL slows the SOUL by 50% (precision mode). Multiple enemies' attacks can overlap on the board. — [deltarune.wiki: Target](https://deltarune.wiki/w/Target)

**SOUL modes (each one changes the verb set of the dodge phase)**
- Red (normal): free 8-direction movement, constant speed; hold CANCEL to slow. Madjick can invert controls. — [undertale.wiki: SOUL mode](https://undertale.wiki/w/SOUL_mode)
- Blue (jump/gravity): platformer gravity; pressing opposite to gravity jumps, holding longer jumps higher up to a per-attack max. Papyrus uses downward gravity only; Sans slams gravity in all four directions. — [undertale.wiki: SOUL mode](https://undertale.wiki/w/SOUL_mode)
- Green (shield): SOUL cannot move; player rotates a shield/spear to block arrows from whichever of 4 directions is pressed. Fleeing impossible. Undyne swaps the SOUL between green and red. — [undertale.wiki: SOUL mode](https://undertale.wiki/w/SOUL_mode)
- Yellow (shooter): SOUL flips upside down; CONFIRM fires a projectile that can destroy some bullets, detonate bombs, and sometimes damage the enemy. Used only vs. Mettaton/Mettaton EX and a Lost Soul variant. — [undertale.wiki: SOUL mode](https://undertale.wiki/w/SOUL_mode)
- Purple (trap): SOUL slides left/right on horizontal lines and switches lines with up/down; cannot slow down; spiders travel along lines. I-frames last longer unless Cloudy Glasses are equipped. Muffet uses it after filling the board. — [undertale.wiki: SOUL mode](https://undertale.wiki/w/SOUL_mode)
- Blue/Red split (Switch-only Mad Mew Mew): SOUL splits into two halves, one per analog stick. — [undertale.wiki: SOUL mode](https://undertale.wiki/w/SOUL_mode)
- Deltarune mostly uses red; other modes appear in Shadow Crystal bosses or specific main bosses. As of Chapter 5, red, yellow, green, purple and orange have appeared. — [undertale.wiki: SOUL mode](https://undertale.wiki/w/SOUL_mode)

**Deltarune TP (Tension Points) economy**
- TP displays 0–100% (internally 0–250). DEFEND gives +16% TP per character. A FIGHT gives TP = 1/10 of the accuracy score; a critical gives 15 internal (6%). Items: TensionBit 32%, TensionGem 50%, TensionMax 100%. — [deltarune.wiki: TP](https://deltarune.wiki/w/TP)
- DEFEND and TP items grant TP *immediately*, so later party members can spend it the same turn. Canonical combo: Kris and Susie DEFEND to fund Ralsei's Heal Prayer (32%). — [deltarune.wiki: TP](https://deltarune.wiki/w/TP)
- Spell costs show the price ladder: Ralsei Pacify 16%, Heal Prayer 32%, ReviveSong 84%; Susie Rude Buster 50% (40% with Devilsknife); Noelle IceShock 16%, SnowGrave 200%. Many boss-specific ACTs also cost TP (e.g. Kris "Courage" 25%, Thrash Machine SELF-FIX 20% rising +10%/use to 50%). — [deltarune.wiki: TP](https://deltarune.wiki/w/TP)
- Leftover TP converts to Dark Dollars at battle end (formula given on wiki as roughly floor(TP%/4) × chapter number; the page's formatting is ambiguous). — [deltarune.wiki: TP](https://deltarune.wiki/w/TP)

**Grazing (risk = reward, and skill = shorter downtime)**
- Each projectile has "graze points": awarded on first entering graze range, plus 1/30 of that per frame while it stays in range. Many attacks have 0 graze points. — [deltarune.wiki: TP](https://deltarune.wiki/w/TP)
- Grazing also has "time points": grazing shortens the enemy's attack turn. Duration reductions are disabled in the last 10 frames of an attack. Grazing is disabled during post-hit invincibility frames. — [deltarune.wiki: TP](https://deltarune.wiki/w/TP)
- Equipment tunes it: Pink Ribbon +20% graze range per dimension, TwinRibbon +25%; TensionBow +10% graze TP; Silver Watch +10% duration reduction. From Chapter 3, the range ribbons also cut graze TP and graze time by 20%/25% (nerf to stop range from dominating). — [deltarune.wiki: TP](https://deltarune.wiki/w/TP)
- Fight-specific overrides: "Darkness" fights (Ch. 4) set most projectiles' graze/time points to 0 and replace TP income with fight-specific sources (blocking projectiles, collecting treasure, converting attacks via a SOUL "shining" mode). — [deltarune.wiki: TP](https://deltarune.wiki/w/TP)

**Deltarune party-of-three handling**
- Each party member has a separate turn and is set to a command: FIGHT, ACT/MAGIC, ITEM, SPARE, DEFEND. On the enemy turn, the player moves Kris's SOUL to dodge for the whole party. — [deltarune.wiki: Gameplay](https://deltarune.wiki/w/Gameplay)
- Enemy attacks have three targeting modes: **Targeted** (a specific member; Chapter 1 showed a white TARGET reticle and faded the non-targeted members, removed in later chapters), **Random**, and **All** (every member loses HP when the SOUL is hit). — [deltarune.wiki: Target](https://deltarune.wiki/w/Target)
- DEFEND: a defending member takes 33% less damage (damage × 2/3, applied after DF and elemental reduction). — [deltarune.wiki: Target](https://deltarune.wiki/w/Target); [deltarune.wiki: Damaging](https://deltarune.wiki/w/Damaging)
- DOWN state: when damage exceeds remaining HP, HP is set to −50% of max HP. DOWN members cannot be targeted, skip their turn and regenerate 1/8 max HP per party turn; once above 0 they get up. Game Over only when *all* party members are down. — [deltarune.wiki: DOWN](https://deltarune.wiki/w/DOWN)
- Enemies can be recruited via ACTs or spared by casting Pacify on TIRED enemies; violent vs. peaceful outcomes feed the chapter route. — [deltarune.wiki: Gameplay](https://deltarune.wiki/w/Gameplay)

**FIGHT timing bar (Deltarune, multi-character)**
- After targeting, a cursor slides right-to-left across a meter; pressing CONFIRM nearer the target reticle does more damage and gives 2–6% TP; perfect alignment = critical (max damage, 6% TP, yellow cursor + stars + distinct sound). No input = MISS. — [deltarune.wiki: FIGHT](https://deltarune.wiki/w/FIGHT)
- With several attackers, each has its own cursor and CONFIRM always hits the leftmost one. The first cursor is 30 frames from its critical point; each later cursor starts 0, 12, or 18 frames after the previous one (equal odds); if three roll identical timing the last rerolls. — [deltarune.wiki: FIGHT](https://deltarune.wiki/w/FIGHT)

### Inferences
- **Attack-pattern principles to copy** (synthesized from Fox's statements above): (1) each enemy owns 2–4 short patterns that express its character (One Piece: Buggy's detached body parts flying around the box, Arlong's saw-nose charge lanes, Crocodile's sand drifting as gravity); (2) patterns from different enemies *combine* in a group fight instead of playing sequentially, which cuts enemy-turn time; (3) bosses get a *new verb* (SOUL mode) instead of more bullets; (4) fewer, larger, readable projectiles over density.
- **SOUL modes map well onto One Piece set pieces** [MP-good if each player has their own heart]: Blue/gravity for sky/ship-deck fights (Enel, Kizaru light jumps), Green/shield for "guard your crewmate" sequences (Usopp's ranged arrows from 4 sides), Yellow/shooter for counter-attack phases (Usopp/Franky), Purple/lines for rope/rigging fights (Doflamingo's strings fit almost exactly).
- **TP with immediate grant is the single best "team economy" mechanic for multiplayer** [MP-good]: one player DEFENDs (low-skill contribution) to fund another player's big special the same round. In a crew game this makes the "support" role meaningful. A shared crew-wide TP pool needs a rule for who spends first (e.g., action order or first-come, with a visible reservation).
- **Grazing shortening enemy turns** [MP-adapt] is a strong pacing tool: skilled play ends dodge phases early. In multiplayer, average or sum the time-reduction across players so one skilled grazer can't skip the phase for everyone.
- **Deltarune's DOWN rule** (−50% HP, auto-regen 1/8 per turn, untargetable) [MP-good] avoids the worst multiplayer problem (a dead player sitting idle for the rest of the fight) and keeps loss only on full-party wipe.
- **ACT/MERCY trial-and-error** is a known weak spot (Fox's own words). For a pirate setting, "Recruit/Spare" could become "Intimidate (Conqueror's Haki)/Bribe/Persuade," but give clear hints to avoid menu guessing, especially with several players voting.
- **FIGHT bar staggering (0/12/18 frames)** [SP-only as designed]: one player hits all cursors. In multiplayer, each player gets their own bar simultaneously, which removes the need for staggering.

### Gaps
- Undertale's FIGHT bar details, Karma (KR) in the Sans fight, and Undertale invincibility-frame counts were not covered by the pages fetched.
- Blue/orange "stop to dodge / move to dodge" bullet rules (well known from Undertale's Sans/Papyrus fights) were not documented on the pages I could open; unverified in this session.
- Deltarune's per-enemy MERCY percentage meter and exact ACT mercy amounts: the deltarune.wiki MERCY page returned 404 and the Fandom wikis returned HTTP 402, so no numbers were collected.
- No source gave Deltarune's base graze-hitbox size or SOUL movement speed in pixels/frame.

---

## 2. Darkest Dungeon 1 & 2: ranks, stress, Afflictions/Virtues, Death's Door, light, quirks, camping, bosses, DD2 relationships/road

### Takeaway
Darkest Dungeon turns a 4-slot line into the main tactical puzzle (skills are usable only from, and only against, certain ranks; shuffles and knockbacks break formations), and adds a second health bar (Stress, 0–200) that turns attrition into character drama. Its strongest reusable ideas for a party RPG are: the 100-stress Affliction/Virtue roll, Death's Door as a "last chance" state with a probabilistic deathblow, and the light meter as a player-controlled risk/reward dial (darker = more loot and crit, but more stress and enemy damage).

### Cited Findings

**Stress, Afflictions, Virtues, Heart Attack**
- At 100 stress a hero is checked: base 25% chance of a Virtue, 75% Affliction. Heroes under-leveled for the dungeon take −5% Virtue chance per level of difference; items like the Ancestor's Tentacle Idol give +20%. Which Affliction is chosen is weighted by the hero's past "Affliction History." — [darkestdungeon.wiki.gg: Virtue](https://darkestdungeon.wiki.gg/wiki/Virtue); [Gamepressure: Stress](https://www.gamepressure.com/darkestdungeon/stress/za759e)
- At 200 stress a hero suffers a Heart Attack: sent straight to Death's Door (or killed if already there). A Virtuous hero keeps the Virtue, falls to Death's Door, and has stress reset to 170. Heart Attack Recovery: −3 ACC, −10% DMG, −2 SPD, +15% Stress until end of quest. — [darkestdungeon.wiki.gg: Death's Door](https://darkestdungeon.wiki.gg/wiki/Death%27s_Door)

**Death's Door**
- At 0 HP a hero enters Death's Door; any further damage triggers a Deathblow check (base resistance 67%, i.e. 33% chance to die per hit; Flagellant 73%; capped at 87%). Healing ≥1 HP removes the state. — [darkestdungeon.wiki.gg: Death's Door](https://darkestdungeon.wiki.gg/wiki/Death%27s_Door)
- Each failed deathblow attempt lowers the hero's deathblow resistance by 15% until healed off Death's Door or dead (snippet). — [darkestdungeon.wiki.gg: Glossary](https://darkestdungeon.wiki.gg/wiki/Glossary)
- While on Death's Door: −10 ACC, −25% DMG, −5 SPD, +33% Stress. After recovering: "Death's Door Recovery" −2 ACC, −5% DMG, −1 SPD, +10% Stress until end of quest, removable only by specific camping skills (Crusader's Stand Tall, Occultist's Dark Ritual, Vestal's Sanctuary). — [darkestdungeon.wiki.gg: Death's Door](https://darkestdungeon.wiki.gg/wiki/Death%27s_Door)
- PvP mode (Butcher's Circus) raises base deathblow resistance to 75% (cap 95%) — evidence the developers tuned this number down-risk for PvP. — [darkestdungeon.wiki.gg: Death's Door](https://darkestdungeon.wiki.gg/wiki/Death%27s_Door)

**Light meter (risk/reward dial)**
- Light starts at 100, drops 1 per traversal of explored segments and 6 per newly explored area; players can lower it in 25-steps at will, raise it with Torches (1 per click, only on your turn). Camping refills it. — [darkestdungeon.wiki.gg: Light Meter](https://darkestdungeon.wiki.gg/wiki/Light_Meter)
- Tier table (Radiant difficulty):

| Tier | Scouting | Monsters surprised | Heroes surprised | Extra loot | Stress | Monster ACC/DMG/Crit | Hero dodge/crit |
|---|---|---|---|---|---|---|---|
| Radiant 76–100 | +15% | +25% | — | — | — | — | +7.5 dodge |
| Dim 51–75 | +7.5% | +15% | — | 25% | +10% | crit +1% | +4 dodge |
| Shadowy 26–50 | — | +10% | +15% | 50% | +20% | +5 / +10% / +2% | crit +1% |
| Dark 1–25 | — | +5% | +25% | 75% | +30% | +10 / +10% / +3% | crit +2% |
| Pitch 0 | — | — | +40% | 95%/75% | +40% | +12.5 / +12.5% / +5% | crit +3% |

  Source: [darkestdungeon.wiki.gg: Light Meter](https://darkestdungeon.wiki.gg/wiki/Light_Meter)
- At 0 light, hallway battles can be replaced by a Shambler (secret boss) ambush: 1% / 8% / 12% by dungeon level. — [darkestdungeon.wiki.gg: Light Meter](https://darkestdungeon.wiki.gg/wiki/Light_Meter)
- Quirks hook into light: e.g., "Warrior of Light" +10% DMG when torch > 75, "Early Riser" +2 SPD when torch > 75, "Lygophobia" +20% Stress when torch < 26. — [Gamepressure: Light level](https://www.gamepressure.com/darkestdungeon/light-level-and-its-influence/z28424); [darkestdungeon.wiki.gg: Quirk](https://darkestdungeon.wiki.gg/wiki/Quirk)

**Ranks, positioning, shuffle/knockback, bosses**
- Skills are rank-gated: if Arbalest or Musketeer (back-line ranged) are shuffled into the front ranks they cannot use most of their skills; the Shuffling Horror boss exists largely to scramble party order, and players counter with heroes whose skills work from many ranks (e.g., Jester's Finale). — [darkestdungeon.wiki.gg: Shuffling Horror](https://darkestdungeon.wiki.gg/wiki/Shuffling_Horror)
- Players value knockback/shuffle mainly for pushing a dangerous enemy out of the rank its strongest skill requires; stuns are seen as the most valuable part of most movement skills. (forum, snippet) — [Steam discussion](https://steamcommunity.com/app/262060/discussions/0/3168820451532321325)
- A class rebalance moved Crusader's Holy Lance from 1 to 2 ranks forward so he can recover rank 1 after shuffles — showing how movement skills are tuned against shuffling. (snippet) — [Steam Workshop changelog](https://steamcommunity.com/sharedfiles/filedetails/changelog/1281619108?p=5)
- DD2 example of position + debuff combo: Plague Doctor's Disorienting Blast hits back ranks, shuffles, dazes, and applies a Weak token (−50% next attack). DD2's Duelist has skills that move her forward and back, making her hard to displace. — [Fextralife DD2: Disorienting Blast](https://darkestdungeon2.wiki.fextralife.com/Disorienting+Blast); [darkestdungeon.wiki.gg: Duelist (DD2)](https://darkestdungeon.wiki.gg/wiki/Duelist_(Darkest_Dungeon_II))

**Camping**
- Camping refills light; specific camping skills are the only way to clear Death's Door Recovery penalties. — [darkestdungeon.wiki.gg: Light Meter](https://darkestdungeon.wiki.gg/wiki/Light_Meter); [darkestdungeon.wiki.gg: Death's Door](https://darkestdungeon.wiki.gg/wiki/Death%27s_Door)

**DD2 relationships, the Road and the Inn**
- Red Hook calls the hero-relationship system "Affinity." Upon leaving an Inn, each pair of heroes has a chance to form a relationship based on Affinity; relationships last one region and can re-form at the next Inn. A patch made affinity change only between inns, with buffs/debuffs applying on leaving the Inn. — [darkestdungeon.wiki.gg: Relationships](https://darkestdungeon.wiki.gg/wiki/Relationships); [PCGamesN: DD2 relationship overhaul](https://www.pcgamesn.com/darkest-dungeon-2/update-relationship-system)
- Inn items (pipeweed, whiskey, playing cards) are the levers for managing affinity; Red Hook said a rework reduced the number of "big moments" during a run. — [Gamenguides: Affinity system](https://www.gamenguides.com/how-does-relationships-and-affinity-system-work-in-darkest-dungeon-ii); [PCGamesN](https://www.pcgamesn.com/darkest-dungeon-2/update-relationship-system)

### Inferences
- **Rank system for a ship crew** [MP-good]: a 4-slot line (Front: Zoro/Luffy brawlers; Back: Usopp/Nami/Robin) with skills gated by rank creates role identity per player with zero real-time skill. Knockback/pull enemies (Luffy's Gomu Gomu pulls; Franky's shoves) out of their skill ranks = a positioning puzzle that is fully turn-based and lag-proof. In multiplayer, position swaps need consent or a rule (swap costs the turn of the player who initiates).
- **Stress → "Morale" or "Will"** [MP-adapt]: per-player stress bars with a 100-threshold Virtue/Affliction roll create memorable moments, but an Affliction that *takes control away* from a human player (refusing orders, acting on its own) is much more frustrating than when it happens to an NPC hero. Safer for multiplayer: afflictions that change numbers or speech, not control. Virtues ("Will of D." / "Conqueror's Spirit") fit the One Piece theme strongly.
- **Death's Door** [MP-good]: maps directly onto shonen "still standing" moments. Use a visible deathblow resistance (e.g., 67%) and let crewmates intercept ("Guard") or heal to pull a player back. Combined with Deltarune's DOWN regen, a player is rarely out of the game for long.
- **Light meter → expedition hazard dial** [MP-adapt]: a ship-wide "Supplies/Log Pose/Weather" dial that the crew can lower for more loot and crit at the cost of stress and enemy damage. Needs a vote or a captain role in multiplayer.
- **DD2 Inn/relationship model** [MP-adapt]: affinities between *player characters* could be replaced by "bond" buffs between players who fight together (combo attacks unlocked by repeated co-op), avoiding negative relationships that punish real friends.

### Gaps
- No single source gave DD1's full rank rules (e.g., exact rank requirements per skill, how corpses occupy ranks) — rank-gating is documented only through boss/class examples above.
- Diseases (contracted from curios/attacks, cured in town) and the full quirk system numbers were not collected.
- DD2's "Hope"/Flame, Loathing, and Road mechanics were not documented in the sources reached (only patch-note fragments).
- No developer (Red Hook GDC) quote on *why* they designed bosses around positioning was found.

---

## 3. Classic JRPG party combat: turn order, weakness/break systems, action commands, Sea of Stars

### Takeaway
The proven "turn-based but active" toolkit is: (1) timed inputs on your own attacks (bonus damage) and on enemy attacks (block/dodge/counter) from Mario RPG → Paper Mario → Mario & Luigi → Sea of Stars; (2) weakness-exploitation that converts knowledge into tempo (Octopath's shield counter → Break; Persona's knockdown → One More → Baton Pass → All-Out Attack); (3) Sea of Stars' "locks," which let players interrupt a telegraphed enemy special by hitting it with specific damage types, with partial credit. All three are lag-tolerant because they are short windows on single inputs.

### Cited Findings

**Action commands / timed hits and blocks (Mario lineage)**
- Mario & Luigi: Superstar Saga maps Mario to A and Luigi to B, used both to attack and to dodge; pressing a brother's button at the right moment during an enemy attack dodges (some attacks require both). Jump-counters and hammer-counters deal damage back. — [Super Mario Wiki: Action Command](https://www.mariowiki.com/Action_command); [Game8: Mario & Luigi Brothership](https://game8.co/games/Mario-and-Luigi-Brothership/archives/483035)
- In Superstar Saga, successful Action Commands double attack damage; later games add directional inputs beyond the brothers' buttons. Brothership adds a hold-R guard stance that significantly reduces damage during enemy turns. — [Super Mario Wiki: Action Command](https://www.mariowiki.com/Action_command); [Game8](https://game8.co/games/Mario-and-Luigi-Brothership/archives/483035)
- Bug Fables (Paper Mario-like) centers battles on timed presses that boost attack or defense. (snippet) — [TV Tropes: Bug Fables](https://www.tvtropes.org/pmwiki/pmwiki.php/VideoGame/BugFables)

**Sea of Stars (Sabotage Studio)**
- All attacks, skills and combos except Ultimates can be timed with the confirm button for extra power; timing varies per ability. Timed blocks reduce incoming damage. — [Sea of Stars wiki (Combat), via search](https://seaofstars.fandom.com/wiki/Combat)
- Locks: an enemy charging a spell shows lock icons by damage type; breaking locks weakens the spell, breaking all cancels it, and breaking locks grants Combo Points. Director Thierry Boulanger: lock-breaking is not pass/fail — breaking 3 of 4 locks significantly weakens the attack. — [Sea of Stars wiki (Combat)](https://seaofstars.fandom.com/wiki/Combat); [RPG Site: Developer Debrief](https://rpgsite.net/interview/14807-developer-debrief-chatting-with-the-mind-behind-sea-of-stars)
- The partial-weakening ("power label") was added during iteration so players felt progress; Sabotage says they did "eight iterations on everything." (secondary/repost source) — [repost of Game Rant interview](https://lutecddep.pages.dev/posts/sea-of-stars-director-talks-making-an-engaging-turn-based-combat-system)
- "Combat 2.0" (Dawn of Equinox, Nov 2024) added Mystery Locks (each new enemy type's lock solution must be discovered in battle), "Reveal" skills that expose locks, and Combo Points that persist after battle. — [Playday: Dawn of Equinox](https://playday.one/2024/11/13/sea-of-stars-free-dawn-of-equinox-available-co-op-combat-2-0-and-more/)

**Weakness → tempo systems**
- Octopath Traveler: enemies show Shield Points = number of weakness hits needed to Break. Broken enemies take extra damage from everything, lose their next action, then the shield resets. — [Twinfinite: Break and Boost explained](https://twinfinite.net/guides/break-and-boost-system-octopath-traveler-2-explained/); [GamerGuides: Battle system](https://www.gamerguides.com/octopath-traveler/guide/the-basics/game-mechanics/battle-system)
- Boost Points: each character gains 1 BP per turn, but only if they didn't boost the previous turn; spend 1–3 BP to power up an action (more hits on normal attacks = faster shield removal). Octopath Traveler 0 also grants BP for breaking shields. — [Switchaboo: Boost Points](https://www.switchaboo.com/octopath-traveler-basics-boost-points); [Twinfinite](https://twinfinite.net/guides/break-and-boost-system-octopath-traveler-2-explained/)
- Persona 5: hitting a weakness/crit knocks an enemy Down and grants a One More (extra action). The One More can be Baton Passed to an ally with a damage/healing bonus; each member can receive only one pass per turn (max 4). When all enemies are Down, the party can launch an All-Out Attack. P5 required Confidant rank 2 to pass; Royal removed that requirement. — [Megami Tensei Wiki: Baton Pass](https://megatenwiki.com/wiki/Baton_Pass); [Megami Tensei Wiki: All-Out Attack](https://megatenwiki.com/wiki/All-Out_Attack); [Twinfinite: Baton Pass](https://twinfinite.net/guides/persona-5-baton-pass-how-to/)
- These descend from SMT's Press Turn system (weakness hits give extra turns; misses lose them). — [Megami Tensei Wiki: Press Turn System](https://megatenwiki.com/wiki/Press_Turn_System)

**Emotion triangle (OMORI)**
- OMORI uses an emotion rock-paper-scissors: Happy beats Angry, Angry beats Sad, Sad beats Happy; some skills scale with emotion tier (Omori's Final Strike from 3× ATK−DEF at neutral up to 6× at the highest tier). Turn order on speed ties: leader first, foes last. (snippet) — [OMORI wiki: Battle system](https://omori.wiki/Battle_system)

### Inferences
- **Timed hits/blocks** [MP-good]: each player times their own character's hits and blocks. Inputs are single-press windows, which survive Roblox latency far better than continuous dodging if evaluated client-side.
- **Sea of Stars locks → "Haki/Devil Fruit counters"** [MP-good, great fit]: a boss charging "Gomu Gomu no Elephant Gun" shows locks like [Slash][Blunt][Haki][Fire]; the crew must coordinate which player hits which lock before it fires — a natural team-communication puzzle that is turn-based. Partial credit (each lock weakens the attack) prevents all-or-nothing frustration.
- **Logia intangibility = shield/weakness gate** (One Piece-specific): Logia enemies with "intangible" shields that only Armament Haki or a specific element can break is a direct Octopath Break analog.
- **Baton Pass / One More** [MP-adapt]: passing an extra turn to another *human* player is a strong cooperative moment ("Luffy → Zoro combo"), but it adds waiting. Cap passes (Persona caps at once per member per turn) and use a short decision timer.
- **Octopath BP rule "earn only if you didn't spend last turn"** [MP-good]: per-player resource with no shared-pool conflicts.
- **Emotion triangle** [MP-good]: a simple, readable status layer (e.g., Fired-up / Calm / Shaken) that gives support players something to do.

### Gaps
- No sources were collected on turn-order systems (FF ATB, FFX CTB timeline, speed-based initiative). From general knowledge only: CTB's visible timeline is easier for groups to plan around than ATB's real-time gauges, but this is unverified here.
- No numeric timing windows (frames) for Mario & Luigi, Paper Mario or Sea of Stars timed hits/blocks were found.
- Sea of Stars' exact co-op handling of timed blocks was not documented (only a "coop-timed-blocks" image filename was seen in search results).

---

## 4. Existing hybrids and lessons (Deltarune, Mario & Luigi, Sea of Stars, Bug Fables, OMORI, Expedition 33, fan/Roblox games)

### Takeaway
The successful hybrids keep the active layer *short and optional for progress* (Sea of Stars timed hits are "bonuses," locks are optional; Undertale patterns are "bite-sized"), keep each enemy's attack identity distinct, and escalate difficulty with *new verbs* rather than raw density. The main recurring complaints are unreadable timing windows and repetition, and in multiplayer, extra pressure and latency.

### Cited Findings
- Deltarune: party turn-based commands + enemy turn as bullet-hell where Kris's SOUL dodges for the party; grazing earns TP for spells. — [deltarune.wiki: Gameplay](https://deltarune.wiki/w/Gameplay)
- Undertale: bullet patterns are "bite-sized," borrowed from Touhou and WarioWare; combined patterns in group fights; encounters rarely repeat. — [Game Developer deep dive](https://www.gamedeveloper.com/design/game-design-deep-dive-i-undertale-i-s-action-based-rpg-battles)
- Sea of Stars: reviewers describe timed hits as small bonuses rather than requirements; one reviewer found some timed hits/blocks "nearly impossible / extremely unintuitive / random." Lock-breaking is described as a bonus, not required to finish the game. (snippets; which of these pages carries which quote was not verified in full text) — [Sea of Stars review roundup (Vaporlens)](https://vaporlens.app/app/1244090/sea_of_stars); [RPGamer review](https://rpgamer.com/review/sea-of-stars-review/)
- Clair Obscur: Expedition 33 (turn-based + real-time parry/dodge): players report parry windows around 0.15 s on the normal difficulty and about 0.35 s on Story, with dodge more forgiving than parry; others report tightness even on normal and point to mods that widen windows by ~50%. These are unofficial forum figures and conflict with each other. — [Steam forum thread](https://steamcommunity.com/app/1903340/discussions/0/592895604607223362); [Steam forum thread 2](https://steamcommunity.com/app/1903340/discussions/0/592896433808485850)
- Mario & Luigi keeps one button per character for both offense and defense across the series. — [Super Mario Wiki: Action Command](https://www.mariowiki.com/Action_command)
- Roblox Undertale-likes are mostly PvP fighters rather than co-op turn-based hybrids: "Undertale Battle Engine" (2D recreation of the Undertale engine with online multiplayer; WASD/arrows to move, Z/Enter to select) and "Undertale: Last Corridor" (team game where winning rounds unlocks stronger options for both teams). — [Roblox: Undertale Battle Engine](https://www.roblox.com/games/18508929778/Undertale-Battle-Engine); Last Corridor description from search snippet only, game page not verified ([Roblox search result](https://www.roblox.com/games/7478475781))
- Toby Fox describes Deltarune's approach (every element a container for a new gimmick) as deliberately inefficient and laborious. — [GamesRadar](https://www.gamesradar.com/games/rpg/toby-fox-says-the-smart-way-to-make-games-is-reusing-what-you-can-but-the-way-he-makes-deltarune-is-stupid-everything-in-the-game-is-simply-a-container-for-a-never-before-seen-gimmick); [Game Informer: "Inefficient and laborious"](https://gameinformer.com/2026/05/25/inefficient-and-laborious-the-ongoing-path-to-making-deltarune)

### Inferences
- **Pacing risk is the #1 hybrid problem in multiplayer.** Every added player multiplies menu time. Patterns from the hybrids that cut downtime: simultaneous command selection (Deltarune's per-member command entry fits a "everyone picks at once with a 15–20 s timer" model), combined enemy attacks instead of one-by-one (Fox), and grazing/skill shortening enemy turns (Deltarune).
- **Content cost warning:** Fox's "every enemy gets new patterns" approach is explicitly expensive. A Roblox team should build a pattern *library* of parameterized primitives (lanes, rings, homing, sweeping lasers, gravity jumps) and give each enemy a themed skin + 2–3 parameter sets, reserving bespoke patterns/SOUL modes for bosses.
- **Mix defense types by attack weight:** routine enemy hits → Mario/Sea of Stars-style single timed block (fast, lag-tolerant); signature/boss moves → full bullet box. This keeps enemy turns short most of the time.

### Gaps
- "Soul Shatters" and "Fallen Down"-style Roblox games named in the brief were not found in search results; I could not verify their mechanics.
- No postmortem/GDC talk on a *multiplayer* turn-based + bullet-hell hybrid was found.
- Bug Fables' party mechanics (e.g., turn passing between members) and OMORI's Energy/follow-up system were not documented on the pages reached.

---

## 5. Handling the bullet-hell phase with a MULTIPLAYER party

### Takeaway
Two real implementations exist: Sea of Stars' official 3-player local co-op (each player handles their own character's combat, with a new "Co-op Timed Hits" mechanic) and a fan-made Deltarune local-multiplayer mod (each player gets their own colored heart in the shared box). The mod shows the main trade-off: more hearts = more pressure and more TP. Deltarune's own Targeted/Random/All targeting model gives a clean rule for whose HP a pattern threatens, which can be repurposed as *which players' hearts must dodge it*.

### Cited Findings
- Deltarune Local Multiplayer mod: up to 3 players; one player controls the overworld; in battle each participant controls one character on the party turn; during enemy attacks "every player is represented by a colored heart" (red, green, purple) that dodges independently. — [AllThings.How: Deltarune local multiplayer mod](https://allthings.how/deltarune-local-multiplayer-mod-how-to-play-co-op-with-friends/); [Destructoid](https://www.destructoid.com/holy-cungadero-thanks-to-mods-you-can-now-play-deltarune-with-friends/?rp=1&rw=w&src=recirc)
- In that mod, extra hearts add more targets and pressure, while tight dodging from everyone builds TP quickly, which can make hard fights more manageable. Remote play (Parsec/Steam Remote Play) adds latency that makes precise dodging harder; the guide recommends easy mode to compensate. — [AllThings.How](https://allthings.how/deltarune-local-multiplayer-mod-how-to-play-co-op-with-friends/)
- Sea of Stars "Dawn of Equinox" (free, Nov 2024): up to 3 local players for the full campaign; each player handles their own traversal and combat; adds "Co-op Timed Hits." One guide notes a short solo phase at the start until all three characters are available. — [Playday](https://playday.one/2024/11/13/sea-of-stars-free-dawn-of-equinox-available-co-op-combat-2-0-and-more/); [Gematsu](https://gematsu.com/2024/03/sea-of-stars-three-player-local-co-op-mode-announced); [GamesRadar: couch co-op JRPGs](https://gamesradar.com/couch-co-op-jrpgs-are-practically-unheard-of-but-were-finally-getting-another-thanks-to-indie-darling-sea-of-stars)
- Deltarune targeting modes (Targeted / Random / All) and DOWN rules (untargetable, regen 1/8 per turn) are documented above. — [deltarune.wiki: Target](https://deltarune.wiki/w/Target); [deltarune.wiki: DOWN](https://deltarune.wiki/w/DOWN)
- Mario & Luigi's per-character button for dodging means each character dodges separately even with one human player. — [Super Mario Wiki: Action Command](https://www.mariowiki.com/Action_command)

### Inferences
Design options, ranked by fit for a Roblox crew game (all inferred; no source tested these on Roblox):

1. **Per-player hearts, Deltarune targeting rule decides who is in danger** [MP-good, recommended]: every pattern is tagged Targeted (only the target player's heart is vulnerable; others see a faded/"spectator" heart or get a support mini-task), Random, or All (all hearts vulnerable, each hit damages only that player's character). This mirrors Deltarune's existing data model and avoids "my friend's mistake killed me."
2. **Separate box per player, same seeded pattern** [MP-good, best for latency]: each client runs its own box locally (pattern seed + start time sent by server), hit detection client-side with server sanity checks (hit count, duration). Players never collide with each other's hearts, so pattern density does not need to scale with player count. Downside: less shared spectacle.
3. **Shared box, all hearts together** (the Deltarune mod's approach) [MP-adapt]: most spectacle and "we survived together" feeling, but crowding and pressure rise with player count; reduce pattern density per added player, or give each heart a distinct color and a small "collision-free" rule between hearts.
4. **Only targeted player dodges** [MP-adapt]: simplest, but other players idle during enemy turns. Fill the idle time with a cheap support action (e.g., a "Cheer" timed press that adds a shield to the dodger, or graze-like TP from a side-task).
- **Shared vs. personal TP**: the mod and Deltarune both use a party pool; with human players, a pool encourages DEFEND-to-fund-ally teamplay but needs a spend order rule (inferred).
- **Downed players**: use DOWN (−50% HP, regen 1/8 per turn) so they rejoin; optionally let a downed player keep dodging in a "ghost heart" mode to earn a faster revive.
- **Scale rules**: scale enemy HP by player count (standard), but scale *pattern density* only in shared-box mode.
- **Turn selection**: simultaneous per-player command selection with a visible timer, then resolve in speed order, keeps 4-player rounds tight.

### Gaps
- No official/professional game was found that ships online (not local) co-op with a real-time bullet-hell defense phase in turn-based combat; the Deltarune mod is local/screen-share only.
- The mod's rule for how damage is assigned when a specific player's heart is hit, and how TP is split, were not described by the article.
- How Sea of Stars resolves timed blocks when several players are present was not documented in the sources reached.
- No data on Roblox network latency effects specifically for bullet-pattern dodging was found; the client-side simulation recommendation is an inference.

---

## 6. Accessibility and difficulty tuning for bullet-hell / timing sections (assist modes, mobile)

### Takeaway
The best precedent is Sea of Stars' modular "Relics": opt-in toggles that each change one thing (more HP + post-battle heal, clearer success feedback, auto-timed basic attacks at reduced bonus, or a harder mode where perfect blocks are rewarded more). Deltarune itself offers precision movement (hold to slow 50%) and equipment that widens graze range, and its easy mode affects bosses only. For mobile/latency, generous windows and single-button inputs are safer than continuous precise dodging.

### Cited Findings
- Sea of Stars relics (off by default, toggled anytime in the Relics menu): **Amulet of Storytelling** (sources differ: +100 HP / +100% HP and auto-heal after combat, or full heal after combat), **Sequent Flare** (a star flare confirms each successful timed hit/block — clarity aid), **Adamant Shard** (regular attacks time themselves and always double-hit, but timing bonus damage is halved), **Artful Gambit** (hard mode: HP −95%, enemies invincible while casting, perfect blocks reduce damage to 1, timed-hit bonus ×2). Difficulty presets are built from these relics. — [Prima Games: Amulet of Storytelling & Sequent Flare](https://primagames.com/gaming/should-i-use-the-amulet-of-storytelling-and-sequent-flare-in-sea-of-stars); [Sea of Stars wiki: Difficulty Presets](https://seaofstars.fandom.com/wiki/Difficulty_Presets); [Push Square review](https://www.pushsquare.com/reviews/ps5/sea-of-stars); [Playday](https://playday.one/2024/11/13/sea-of-stars-free-dawn-of-equinox-available-co-op-combat-2-0-and-more/)
- Family Gaming Database lists Sea of Stars accessibility features including custom difficulty, adjustable difficulty during play, "Multiple Buttons & Single Stick," and mouse-and-keys support. — [Family Gaming Database: Sea of Stars accessibility](https://www.familygamingdatabase.com/accessibility/Sea+of+Stars)
- Deltarune: holding CANCEL slows the SOUL 50%; Pink Ribbon/TwinRibbon widen graze range (+20%/+25% per dimension), later paired with TP-gain nerfs. — [deltarune.wiki: Target](https://deltarune.wiki/w/Target); [deltarune.wiki: TP](https://deltarune.wiki/w/TP)
- Deltarune's easy mode affects bosses only (per the multiplayer-mod guide recommending it for latency). — [AllThings.How](https://allthings.how/deltarune-local-multiplayer-mod-how-to-play-co-op-with-friends/)
- Undertale's Purple mode gives longer i-frames unless an item is equipped — i-frame length is itself a difficulty knob. — [undertale.wiki: SOUL mode](https://undertale.wiki/w/SOUL_mode)
- Fox kept projectiles fewer and larger to remain approachable to non-bullet-hell players. (snippet) — [PC Gamer: The making of Undertale](https://pcgamer.com/the-making-of-undertale)
- Expedition 33 players report Story difficulty roughly doubles the parry window (≈0.35 s vs ≈0.15 s; unofficial). — [Steam forum thread](https://steamcommunity.com/app/1903340/discussions/0/592895604607223362)
- Undertale Battle Engine on Roblox uses WASD/arrow keys + Z/Enter (keyboard-first). — [Roblox: Undertale Battle Engine](https://www.roblox.com/games/18508929778/Undertale-Battle-Engine)

### Inferences
- **Per-player "Relic"-style toggles** [MP-good]: let each player choose their own assist (bigger heart-safe margin, slower bullets in *their* box, auto-timed basic attacks at −50% bonus) without changing the fight for others. This only works cleanly with per-player boxes or per-player targeting (option 1 or 2 in Section 5).
- **Mobile touch controls** (inferred): a floating virtual joystick anywhere on the left half for the heart, a "slow/focus" button on the right (Deltarune's 50% slow), and a hitbox noticeably smaller than the heart sprite so near-misses feel fair. Avoid Blue/gravity jump modes needing hold-duration control on touch, or give them a tap-for-fixed-height option.
- **Readability rules** (inferred from Fox + Sea of Stars feedback): telegraph each projectile 0.3–0.5 s before it becomes dangerous, use a consistent color language (e.g., Haki-black = unblockable, Devil-Fruit color = element), and add a clear success flash on every timed input (the Sequent Flare lesson).
- **Difficulty ladder by verbs, not density**: early islands = red mode only, slow lanes; mid-game = combined enemy patterns; Grand Line bosses = new SOUL modes (Fox's boss-gimmick principle).
- **Lag safety**: run dodge simulation client-side and make timed-hit windows at least ~150–200 ms wide on default difficulty (Expedition 33's tightest reported windows drew complaints).

### Gaps
- No official frame/ms timing windows for Sea of Stars, Mario & Luigi, or Expedition 33 were found; Expedition 33 figures are player reports.
- No source documented touch-control design for Undertale-style dodging on mobile (Roblox or otherwise).
- No accessibility postmortem from Toby Fox or Red Hook was found.
