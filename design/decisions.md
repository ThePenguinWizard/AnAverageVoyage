# Design decisions

A running log of decisions that are locked in. The research report (`reports/One Piece campaign game design.md`) is background; where this log disagrees with it, this log wins. All numbers are starting values to tune in playtests.

---

## D1. Target audience: teens and adults

**Decided:** 2026-11-14

**What changes from the report:** the report recommended aiming for a Mild rating to reach younger kids. That no longer applies.

- **Target rating: Moderate.** According to the research notes, Moderate games reach Roblox Select (ages 9–15) and standard Roblox (16+). "Restricted" is age-verified 18+ only, which would cut out the teen audience, so avoid anything that pushes the game there. Source: [Roblox docs: Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity).
- **Tone can go darker.** Darkest Dungeon-style grim narration, real dread around stress and death, and harsher failure states are all on the table.
- **Keep drinking off-screen anyway.** The research notes say alcohol references are only allowed in games with "the strictest age restrictions", so on-screen drinking risks pushing the game into 18+.
- **Check against the questionnaire.** The Maturity & Compliance Questionnaire decides the actual rating. Fill it in before any public playtest, because unrated games are restricted.

---

## D2. Everyone picks their move at the same time

**Decided:** 2026-11-14

- Every living player picks their action during one shared **command phase**, with a timer of about 15 s. The phase ends early once everyone has pressed Ready.
- **Live intent preview:** your portrait icon appears on your chosen target, and teammates see your pick update as you change it.
- **Quick pings** instead of typing: "Focus this one", "I'll heal", "Brace for me".
- Actions **resolve in Initiative order**, and that order is shown during picking. A "Delay" option lets a player act last on purpose.
- **Auto-retarget:** if your target dies before your action resolves, you hit the next enemy in the same rank.
- **Shared Tension is reserved when picked.** Whoever picks a Tension move first gets the Tension, and the bar shows the reserved part.
- **AFK players** automatically Brace when the timer runs out.

---

## D3. Attack minigames are private

**Decided:** 2026-11-14

- Each player's attack minigame (timing bar, aim reticle, rhythm combo and so on) plays **only on their own screen**. Teammates never watch it live.
- The minigame starts as soon as you lock in your action, inside the same command phase. All four players do theirs at once, so it adds almost no time to the round.
- The server grades the inputs. Teammates only see the **result** when the action resolves: the attack animation, the damage number and a grade pop-up.

| Grade | Damage | Extra effect |
|---|---|---|
| Perfect | 130% | Crit-style pop-up |
| Good | 100% | None |
| Fail | 0%: the attack misses completely | Fail close-up (D4) and about +10 Resolve |

- **Messing up means the attack fails** (decided 2026-11-14). There's no partial-damage grade in between.
- Because a fail does nothing, make the Good window generous. A starting target is for an average player to fail about 1 attack in 6–8.

---

## D4. Failure close-up, like Darkest Dungeon's affliction moment

**Decided:** 2026-11-14

When a player fails an attack or badly fails a dodge, the game cuts to a dramatic close-up of their character failing. Darkest Dungeon does the same when a hero breaks under stress. Attack minigames are private (D3), so for attacks this close-up is how the crew finds out someone messed up.

### Two levels of close-up

| | Fail close-up | Breaking point |
|---|---|---|
| Trigger | A Fail on an attack minigame, or a badly failed dodge (D6) | The character's Resolve (stress) reaches 100 |
| Length | About 1.5–2 s | About 3–4 s |
| Camera | A quick cut to a close-up of the character | A slower push-in with a heavier vignette, like Darkest Dungeon |
| What's shown | The failure itself: a blade stuck in the deck, a misfire, a fist that hits a barrel | The character cracking, or rallying if they roll a Virtue |
| Text | A short stamped word suited to the fighting style (e.g. "MISFIRE", "DULL BLADE", "WHIFFED") | A big Affliction or Virtue title |
| Narrator | One short line | One longer line |
| Effect | About +10 Resolve, shown ticking up | Applies the Affliction or Virtue |

Fails feed Resolve, so repeated failures build toward the breaking point. The small close-ups set up the big one.

### Rules that keep rounds short

- **At most two fail close-ups per round.** Any further fails that round just show a "FAIL" pop-up.
- **The same player never gets a fail close-up two rounds in a row.**
- **Breaking-point close-ups always play.**
- Attack close-ups play when that player's attack resolves. Dodge close-ups play right after the dodge box closes.

### Look and feel (teen and adult tone)

- Freeze the action. Dim and desaturate the background, and rim-light the character.
- Use a heavy vignette, high contrast, manga-style speed lines or screentone, and a red ink stamp for the text.
- Swap the R6 face to a "panic" decal for the length of the close-up, and add a short camera shake on the stamp.
- Narrator lines are grim with dark humour, in Darkest Dungeon's register. Keep all lines in the same data table as the other player-facing names, so they're easy to rename.

### Implementation sketch (Roblox)

- The server owns the resolution timeline. When it reaches a close-up, it broadcasts `{actorId, kind = "Fail" | "Break", variant, duration}` and waits `duration` before resolving the next action, which keeps every client in sync.
- **Option A, recommended:** use a ViewportFrame. Clone the character into a full-screen ViewportFrame over a dimmed overlay, pose it, and add the stamp and narrator text. This gives full control and the most Darkest Dungeon-like portrait look.
- **Option B:** set `Camera.CameraType = Scriptable`, tween to an offset in front of the character's head with a narrow `FieldOfView` (about 30), and use a `ColorCorrectionEffect` for the dim and desaturation plus a `Highlight` on the character.

### Open questions

- **A matching close-up for success?** Darkest Dungeon also zooms in on crits. A rare close-up for a Perfect killing blow would stop close-ups from feeling purely like punishment.

---

## D5. Afflictions change numbers, never take control

**Decided:** 2026-11-14

- When a player's character breaks (Resolve reaches 100), the Affliction changes **stats, dialogue and how the character looks**. It **never** takes over the player's commands. The game never makes their character refuse orders, skip turns or attack the wrong target.
- This is where Darkest Dungeon is deliberately not followed: there, afflicted heroes sometimes act on their own. Here a real person is behind every character, so losing control would feel like the game playing for them.
- Each Affliction should be a **trade-off the player can still play around**, not just a penalty. Starting examples:

| Affliction | Effect |
|---|---|
| Panicked | +15% soul speed in the dodge box, but a 10% bigger hitbox |
| Reckless | +20% damage, but Brace is disabled |
| Paranoid | Can't receive heals or buffs from teammates, but +15% dodge-box graze radius |
| Hopeless | Gains half as much Tension, and Resolve recovers more slowly |
| Selfish | Takes the first pick of shared loot, and Cover presses for teammates are disabled |

- **Virtues** stay positive-only (for example, Fired Up: +Tension from grazing and a small damage boost for the whole crew).
- **AI crew (NPC recruits) are the exception.** They have no human controlling them, so they can act on their own when afflicted, like Darkest Dungeon heroes.
- Afflictions clear at a port, through rest actions, or through Doctor and Musician skills (tune in playtests).

---

## D6. Round flow: turns take place one at a time, and the crew watches each dodge

**Decided:** 2026-11-14

This replaces the report's round, where all enemies attacked together in one combined dodge phase and each player dodged in their own separate box.

### The round

| Step | What happens |
|---|---|
| 1. Intent | Each enemy shows who it's about to attack (an icon on that player's portrait), so the crew can plan around it. |
| 2. Command (all at once) | Everyone picks an action and plays their private attack minigame (D2, D3). |
| 3. Resolution | Every action, from players and enemies, plays out one at a time in Initiative order. |
| 4. End of round | Status effects tick, breaking points play, and downed players are checked. |

### During resolution

- **A player's turn:** their attack animation plays, with the damage and grade pop-up. A Fail does nothing and can trigger a fail close-up (D4).
- **An enemy attacking one player:** that player is pulled into the Undertale-style dodge box. **Everyone else watches the same box live** on their own screen.
- **An enemy attacking several players:** every targeted player is pulled into **the same box**, each with their own soul. You only control your own soul, souls pass through each other, and a hit only damages the soul it touches. Players who weren't targeted watch.
- **After the dodge,** damage applies. A badly failed dodge triggers a fail close-up (D4). As a starting point, that means losing at least 25% of max HP from one attack, or dropping into Last Stand.

### Rules

- **Enemies and players share one turn order,** so an enemy can act before some players. If a player goes DOWN before their turn, their action is cancelled. The full turn order is shown while players pick, so they can react: for example, Brace if a fast enemy is targeting them.
- **Brace** means skipping your attack to take about a third less damage in your next dodge and gain Tension right away.
- **Dodge lengths:** about 3–5 s for normal enemies, 5–8 s for elites, and 8–12 s for boss signature moves.
- **The shared box grows a little with each extra soul** (about +15% each), so multiple souls aren't cramped.
- **Missing input:** if a targeted player disconnects or goes AFK, their soul stays still and takes every hit that reaches it.

### Suggestions to keep rounds under a minute (not decided yet)

- **Weak enemies in a group attack together** as one dodge instead of one each. Undertale combines group attacks for the same reason.
- **Round budget:** with 4 players and 3 enemies, roughly 15–20 s of picking, about 8 s of player attacks, 3 dodges at about 5 s each, plus up to two close-ups, comes to about 45–50 s. Boss fights run longer.

### How the shared box works in Roblox

- The server sends each enemy attack as `{attackId, seed, startTime, targets}`. Every client builds the same bullet pattern from the seed, so the dodging players and the watchers all see identical bullets.
- Each targeted player moves their own soul on their own device, so there's no input lag. Their device sends the soul's position 10–20 times a second over an `UnreliableRemoteEvent`. Other players see those souls moving smoothly about 0.1–0.2 s behind, which doesn't matter because souls never interact.
- The server replays each player's movement against the same pattern to decide what hit them, so a cheating client can't claim it dodged.

---

## D7. Builds: a weapon style plus a crew role

**Decided:** 2026-11-14

Each player picks two things:
- a **weapon style**, which decides how they fight on their own turn
- a **crew role**, which decides how they help the crew: on their own turn, during teammates' dodges, and on the voyage

Cursed fruits come later as an optional third layer. Offer ready-made combos for new players, such as "Sword Captain" or "Gun Navigator".

### Weapon styles

Every weapon has its own attack minigame. Subclasses reuse their parent weapon's minigame with a twist, so most variety should come from subclasses, not new weapons.

| Weapon | When | Rank | Attack minigame | Identity |
|---|---|---|---|---|
| Sword | Prototype | Front or middle | Timing-bar slash, like Undertale's FIGHT | Reliable damage, breaks guards |
| Gun | Prototype | Back | A drifting crosshair: fire when it's over the weak point | Hits enemies' back ranks, trick ammo (smoke, fire, nets), weak if pulled forward |
| Fist | Prototype | Front | A short rhythm combo | Multi-hit, knocks enemies out of their ranks, buffs itself |
| Shield (with a sidearm) | Launch | Front | A simple timed bash | Taunt: pulls enemy attacks onto itself. Its real skill test is the dodge box. |
| Harpoon / Spear | Launch | Front or middle | Charge and release: hold, then let go in the sweet spot | Hits two ranks deep, drags back-row enemies forward |
| Weather Staff | Later | Middle or back | Trace a shape (swipe-friendly on phones) | Area attacks, plus weather that changes the next dodge box (rain slows bullets, wind pushes them sideways) |
| Daggers | Later | Any | Reaction taps: targets pop up and you tap them fast | Crits, poison, stealing gold and items |

Subclass candidates:
- **Fist:** kicks
- **Gun:** bombs, cannon arm
- **Sword:** greatsword, ship's anchor
- **Harpoon:** chain, whip
- **Daggers:** claws

Subclasses are unlocked by island mentors (see the report).

### Crew roles

- **One of each role per crew.** Whoever locks a role in first gets it.
- **Captain by default:** whoever forms the crew is Captain, and can hand the role off.
- **Empty roles:** NPC crew can fill them at reduced strength.
- **No role is required.** Healing items are strong enough that a crew without a Doctor or Cook can still win.
- **Weapons do most of the combat work.** Roles are support, so builds don't all become "Doctor plus whatever".

**Launch set (8):**

| Role | Action on your turn | Help during a teammate's dodge | Voyage perk |
|---|---|---|---|
| Captain | Rally: the crew gains Tension and loses some stress | Bullets slow down for 2 s | Breaks tied votes on the sea chart |
| Navigator (includes the old Helmsman) | Shows the enemies' next moves further ahead | Warning lines show where the next bullets will spawn | Clears more fog on the chart and avoids one sea hazard per sea |
| Doctor | Heals an ally and cures a status | Heals half the damage from that dodge once it ends | Clears Scars at ports |
| Cook | A snack: small heal plus stress relief | Tosses food into the box that heals when grabbed | Port meals relieve more stress |
| Shipwright | Shields an ally | Tap to place a plank wall in the box for 3 s | Repairs the ship and cancels some sea hazards |
| Musician | A crew buff | The dodger gains no stress from this attack | Storms cause less stress |
| Archaeologist | Reveals enemy weaknesses | Shows the safe spot for the first second | Reads ruin glyphs for puzzles (the clue-holder in co-op puzzles) |
| Gunner | Once per fight, the ship's cannons hit every enemy | Tap up to 3 bullets in the box to shoot them down | Wins ship battles and fights sea monsters on sea lanes |

**Add later:**

| Role | Action on your turn | Help during a teammate's dodge | Note |
|---|---|---|---|
| Diver | Pulls a downed or soaked ally to safety | A bubble that slows bullets in one area for 3 s | Arrives with cursed fruits, since it rescues fruit users who can't swim |
| Quartermaster | Hands any ally an item without using up their turn | The dodger gains Tension for each hit taken | Owns loot, money and the shared stash |
| Negotiator | Better odds to recruit an enemy or make it flee | Bribe: spend gold to end the enemy's attack early | Owns events, parleys and recruiting |
| Blacksmith | Widens the Good window on an ally's next attack minigame | The dodger's first hit is blocked | Owns gear and crafting |
| Rookie (joke role) | A random, weaker version of another role's action | A random, weaker help | Earns XP faster |

### Rules for helping during a dodge

- Watching is the default.
- Only players **outside** the box can help, so if an attack hits everyone, nobody can.
- Each help costs Tension from the crew's shared pool and can be used **once per dodge** per player.
- The server adds every help to the attack's timeline, so planks and snacks show up identically for everyone and count when hits are checked.

---

## D8. How players gain Will (Haki) and cursed fruits (Devil Fruits)

**Decided:** 2026-11-14

In-game names are **Will** (Sense, Steel, Crown) and **cursed fruits**, so the game avoids One Piece's own coined terms. **Fruits are found during a run and last only for it. Will is earned once and kept for good.**

### Will

How you awaken it:
- **In a crisis:** a Virtue roll at a breaking point (D4) can be an Awakening instead. Stress from dodging awakens Sense; stress from big hits or Last Stand awakens Steel.
- **From a mentor:** rare mentor islands offer a trial. Passing awakens the type; failing costs stress and an injury.
- **Crown** can't be trained. It can only awaken when you're the last crew member standing against a boss, on a lucky roll.

How it carries over:
- Once awakened, a type is unlocked on your account for good.
- You bring one awakened type into each voyage, chosen at the start. A second can still awaken mid-run.
- You grow it in a training tree at the harbor dojo, paid for with meta currency.
- The **WIL** stat (AAC's FTH, renamed) powers Will skills, which cost Energy.

What each type does:
- **Sense:** warning lines for bullets and a short slow-motion moment in the dodge box. It also slows the Gun's crosshair.
- **Steel:** less damage per hit in the dodge box. Your attacks can hit elemental enemies and break armor.
- **Crown:** weak enemies faint and skip their attack, and others get Fear (they gain only 1 Energy per turn).

### Cursed fruits

Where they come from:
- rare islands and events
- an expensive black-market merchant
- bosses who use a fruit can drop it

Items, Legacies and the Navigator role make fruit islands more likely.

Rules:
- One fruit per character per run. Eating a second is a hidden, almost-certain death.
- **Fruit users can't swim.** Sea hazards and "overboard" events can drown them unless a crewmate (the Diver role) rescues them. Sea-iron nets block fruit skills.

What a fruit does: it adds fruit skills and **changes how your soul moves in the dodge box**:
- **Elemental:** phases through normal bullets for short moments; black-edged bullets still hit
- **Beast:** a bigger soul with more HP and a charging dash
- **Special:** one unique trick per fruit, such as a rubber soul that bounces off the box walls

Long-term progress: a fruit encyclopedia records every fruit you've eaten, and each fruit has mastery that unlocks extra skills the next time you find it.

### Never sold

Fruits and Will are never sold for Robux. Monetization stays at AAC's level: meta currency bundles and revives, no power for sale.

---

## D9. Crews of up to 6 players

**Decided:** 2026-11-14

- Crews hold **1–6 players**, and the run place's max players is 6. The harbor lobby stays at about 50.
- **Formation:** Darkest Dungeon's 4 single ranks can't hold 6 characters. Starting point: **3 ranks (front, middle, back) with 2 slots each**. Rank-gated skills check the rank, not the slot.
- **Enemy scaling:** start from AAC's numbers (+12.5% enemy attack and +50% enemy HP per extra player) and tune down if 6-player fights drag.
- **Round time:** six players means more dodges per round. Weak enemies attacking together as one dodge (D6) goes from a suggestion to something to build early.

---

## D10. The camp is on the crew's ship

**Decided:** 2026-11-14

AAC's campfire camp moves onto the crew's ship. AAC's camp menus (Stash, Craft, Inventory, Equipment and the party-wide Ready button, now "Ready (x/6)") become **physical stations on the ship** that players walk up to between islands and at rest stops. The sea chart table, where the crew votes on the next island, is on the ship too. Higher ship tiers add more stations.

---

## D11. Three ship tiers, unlocked permanently

**Decided:** 2026-11-14 (first versions built from Roblox parts; Blender versions to compare later)

- Ship tiers are **permanent upgrades** bought with meta currency. The crew sails the **Captain's** ship tier.
- Every tier holds a crew of 6.

| Tier | Ship | Size (studs) | Rig | Stations it adds |
|---|---|---|---|---|
| 1 | Sloop | 56 long × 18 wide | 1 mast + jib | Chart table and helm (quarterdeck), stash chest, 6 crew chests, cook brazier (the old campfire), workbench, ready bell |
| 2 | Brigantine | 86 × 26 | 2 masts + jib | Galley deckhouse (stove, mess table), infirmary (cabin under the quarterdeck), 4 cannons |
| 3 | Galleon | 124 × 36 | 3 masts + jib | Workshop in the forecastle (forge, anvil, workbench), crow's nest with a climbable ladder, recruit board, captain's cabin (crew chests live here), 8 cannons |

- **Station attributes:** each station model has a `Station` attribute that game code can look up. The values are ChartTable, Helm, Stash, CrewChest (plus `Slot` 1–6), CookFire, Workbench, ReadyBell, Galley, Infirmary, Cannon, Workshop, CrowsNest and RecruitBoard.
- **Ship attributes:** the ship model itself carries `ShipTier`, `ShipClass` and `CrewCapacity`.

---

## D12. World setup: ocean, seas and the battle island

**Decided:** 2026-11-14

- **Waterline:** y = 0. Terrain water fills a 3072 × 3072 square, 48 deep, over a sand seabed. Ships and islands are built for that waterline.
- **Mood by sea:** Sea 1 "Calm Blues" is bright midday, Sea 2 "Golden Route" is golden dusk, and Sea 3 "Storm Sea" is dim and stormy with a slight green tint. Each preset covers lighting, atmosphere, clouds, water color, waves and post-effects. Set Workspace's `SeaPreset` attribute to switch; in-game it tweens over 4 s.
- **Battle island arena:**
  - Crew on the left, enemies on the right, seen from a three-quarter camera.
  - Each side has 3 ranks × 2 slots, matching D9. Slot markers carry `BattleSlot`, `Side`, `Rank` and `Slot` attributes.
  - The camera's position is a part with a `CameraAnchor` attribute.
- **Island extras:**
  - A dock on the side facing the ships.
  - A ruin with a glowing waystone (`Waystone` attribute) as a teaser for the persistent meta puzzle.

---

## D13. Vibe reference: painted dusk sea and a parchment dodge box

**Noted:** 2026-11-14, from a 45-second reference video the user shared ("this is like the vibe I want, kinda"). Treat it as direction, not a spec.

### The world in the reference

- A calm, painterly sea at dusk: lavender-to-pink sky, one huge soft peach cloud on the horizon, deep indigo water with gentle ripples, and a small lush island in the distance.
- Quiet and a little melancholy, not loud or neon.
- The Sea 2 preset is now tuned to this palette. Roblox's built-in clouds are wispy, so the big painted cloud would need a custom skybox or cloud mesh.

### The dodge box in the reference

- **The box is a parchment card:** torn edges, a double ink border, and cream paper, in place of Undertale's black box.
- **It unfolds** from a thin strip when an attack starts, and the scene behind it dims.
- **The soul is a small compass star.** Each crew member's star has its own colour (teal, red, green, orange).
- **Attacks are ink drawings on the paper:**
  - a cutlass swing is a crescent sweep
  - a gunshot is a straight line across the card
  - a volley is several lines
- **Telegraphs:** a dashed red line shows the path first, the shape then appears pale, and it turns dark at the moment it can hurt.
- **The weapon is drawn outside the card** (a cutlass or a flintlock) at the spot the attack comes from.
- **Rails:** some attacks put the soul on a rail, so it can only move left-right or up-down.
- **Labels:** a dark name tab for the attacker ("NAVY SWORDSMAN"), a handwritten line for the move ("Cutlass · use 1"), a small "HP 20 / 20" under the card, and a serif caption at the bottom of the screen.
- **Replay:** after a hit, a slow-motion replay (0.35× speed, 2× zoom) shows the swing that landed. This could be how the fail close-up (D4) plays for dodges.

### What this changes

- UI direction moves from "pixel font on dark translucent panels" (AAC's look) to **ink on parchment with serif type**. The sea chart, event cards and menus should follow the same paper look.
- The dodge box is no longer pixel art (this replaces the report's suggestion).

### Players who aren't targeted: watch, or use their crew role's help

Decided 2026-11-14 (see D7). Watching is the default. A player outside the box can use their crew role's dodge help once per dodge, paid for with Tension from the crew's shared pool.

---

## D14. Ship rebuild: exact hull shells, curved sails, big horizon clouds

**Decided:** 2026-11-14

- **Why:** the first ships used overlapping plank boxes for the hull (jagged edges, parts poking through each other) and flat sails that hung through the cabins.
- **Hull, castle walls and sails** are now generated as surfaces, with two outputs from the same shapes:
  - **In the place now:** a wedge shell. Every triangle of the surface is two wedge parts that fit exactly, so nothing overlaps. Faceted, low-poly look.
  - **Ready in `assets/export/`:** smooth FBX meshes (one file per ship). These need Studio's asset upload permission (`asset:read` and `asset:write`) before they can replace the wedge shell.
- **Sails** are curved, and the lowest sail on every mast hangs above cabin roofs and head height.
- **Overlap checker:** the generator tests every part against every other part and every sail against all parts, and prints anything deeper than 0.35 studs. Known leftovers: a hidden deck board touching the galleon's bow post, and one sail corner touching the brigantine's bowsprit.
- **Big clouds:** removed on 2026-11-14 at the user's request (they didn't like the sphere-built cumulus heaps). Only Roblox's built-in sky clouds remain.
- **Part counts** (with the wedge shell): Sloop 1,337, Brigantine 2,108, Galleon 2,976. A run only ever spawns one ship; the mesh versions cut these to roughly 380, 600 and 940.

---

## D15. Sparring prototype: first moves against dummy pirates

**Built:** 2026-11-14

A first playable slice of combat. On joining, each player is placed on a crew slot of the battle island and fights three training dummies. It is one player against the dummies, one turn at a time; it is not the full simultaneous-pick round from D2 and D6 yet.

**Player moves** (one per weapon style, graded Perfect 130% / Good 100% / Fail 0% as in D3):

| Move | Weapon | Minigame | Base damage |
|---|---|---|---|
| Slash | Sword | Timing bar: stop the blade in the middle | 8 |
| Aimed Shot | Gun | Drifting crosshair: fire when it is on the mark | 7 |
| Combo | Fist | Rhythm: press on each of four beats | 9 |

**Dummy pirates and their attacks** (drawn on the parchment dodge card, D13):

| Dummy | HP | Attacks |
|---|---|---|
| Pirate Deckhand | 20 | Cutlass sweep (one arc from the left) |
| Navy Swordsman | 26 | Left then right; up then down |
| Navy Gunner | 18 | Aimed shot (aims at your height when the warning appears); three-shot volley |

- Sweeps and shots warn first (pale shape plus dashed red line for 0.8 s), then turn dark for 0.22 s, which is when they hurt.
- The soul is a teal compass star moved with WASD, arrow keys, a gamepad stick, or by dragging on a touch screen. A hit gives 0.6 s of invulnerability.
- When all three dummies are down they get back up; when the player hits 0 HP they are patched up to full.

**Prototype shortcuts to replace later:**
- The client reports its own minigame grade and hit count, and the server only sanity-checks them. The real game needs the server-side dodge replay from D6.
- No stress, ranks, crew roles, fail close-ups or spectating yet.
- Moves and dummies are data in `src/shared/Combat/Moves.luau`.

---

## D16. First full loop: ship, chart, island, back to ship

**Built:** 2026-11-14, by four subagents working in separate files against `design/architecture.md`, then joined and play-tested.

- **Loop:** you join on your ship's deck, open the sea chart, pick an island and set sail, resolve the island (battle, elite, event, rest, treasure, port or boss), and return to the deck. Three seas, then a summary and a fresh voyage. This replaces the D15 sparring-on-join prototype.
- **Combat:** each weapon style has two moves plus Brace. There are 11 enemy types (six regulars, two elites, one boss per sea). Stress has four afflictions and three virtues, all number-only (D5). Fail close-ups are in.
- **Voyage:** each sea is 7 rows: five rows of 2-4 islands, a port, then the boss. Islands more than two rows ahead are fogged. There are nine narrated events. A full clear pays 70 Renown.
- **Ship camp:** every station has a prompt. Chests open your inventory; the cook fire, galley and infirmary heal or relieve stress once per visit; the rest show a note.
- **Profiles:** Renown, ship tier, weapon and role are saved. Gold and items last one voyage.

**Play-tested (2026-11-15):**
- **Ship:** placement on deck, the status strip, the stash and crew chests (using items), the cook fire, a placeholder station note.
- **Crew papers:** switching weapon and role, buying the Brigantine (which now moves you onto it straight away).
- **Islands:** battle, elite, boss, event (with a gamble), rest, treasure and port.
- **Combat:** Slash, Aimed Shot, Combo, Brace, a failed attack, losing to the Sea 1 boss.
- **Stress:** fail and knockout close-ups, the breaking point, afflictions and virtues rolling and clearing.
- **Voyage:** the lost-voyage summary and "Sail again" (HP, gold and items reset), switching to the Sea 3 lighting.

**Fixed during testing:** the battle camera framing; the fail close-up's portrait (smaller, after Studio ran out of graphics memory with a full-screen one and six Studio windows open); buying a ship now moves you onto it; Escape no longer closes ship panels (it also opened the Roblox menu); event and summary cards fit their text; the ship-purchase confirm button is readable.

**Still not play-tested:** winning a boss fight and crossing into the next sea through play (the sea lighting switch itself works), completing a full voyage, Heavy Cleave, Deadeye and Flurry, the galley and infirmary, the crow's nest ladder, two or more players, touch and gamepad, saving on a published place.

**Numbers that are guesses:** max HP is 60 (was 20 in D15), player damage 9-16, boss HP 80 / 105 / 130.

**Crew roles are one per server** (decided 2026-11-14): a role held by another player in the server is unavailable. This treats everyone in a server as one crew, which matches D7. Revisit it if a server ever holds several crews.
