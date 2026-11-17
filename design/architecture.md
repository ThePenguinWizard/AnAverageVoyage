# Architecture and contracts

How the game's code is split, and the interfaces the parts use to talk to each other. Design intent lives in [decisions.md](decisions.md); this file is only about code structure. If you change an interface here, change every caller in the same edit.

## Layout

| Path | Becomes | Notes |
|---|---|---|
| `src/server/init.server.luau` | `ServerScriptService.Server` (Script) | World setup, then loads every ModuleScript in `Services`. **Frozen: do not edit.** |
| `src/server/Services/<Name>.luau` | `Server.Services.<Name>` | One service per feature. May return `init()` (no yielding, runs for all services first) and `start()` (may yield). |
| `src/server/<Feature>/…` | `Server.<Feature>` | Private helper modules for a service. |
| `src/client/init.client.luau` | `StarterPlayerScripts.Client` (LocalScript) | Loads every ModuleScript in `Controllers`. **Frozen: do not edit.** |
| `src/client/Controllers/<Name>.luau` | `Client.Controllers.<Name>` | One controller per feature, same `init()` / `start()` convention. Each is loaded in its own thread. |
| `src/client/<Feature>/…` | `Client.<Feature>` | Private helper modules for a controller. |
| `src/shared/…` | `ReplicatedStorage.Shared.…` | Data and helpers both sides use. |
| `src/shared/UI/Paper.luau` | `Shared.UI.Paper` | The ink-on-parchment UI kit. All UI is built with it. **Frozen: ask before changing.** |
| `src/workspace/…`, `tools/worldgen/…` | generated models | **Frozen.** Ships, battle island and clouds come from the generator. |

Rules:
- A service requires another service **lazily, inside the function that needs it** (`require(script.Parent.OtherService)`), never at the top of the file. Several services call each other, and top-level requires would form a cycle.
- A service must keep working if another service is missing or errors: wrap cross-service calls in `pcall` and fall back sensibly.
- Each service creates its own RemoteEvents under `ReplicatedStorage` in `init()`, named `<Feature>Remote`. Clients `WaitForChild` them.
- The server never trusts the client for anything that matters (currency, items, HP). Validate every remote argument's type and range.
- Luau only, `--!strict` at the top of every file, tabs for indentation.

## Shared state: Player attributes

Attributes on the `Player` instance replicate to that player's client for free, so they are the shared state between features. The **owner** is the only service that writes an attribute; anyone may read it.

| Attribute | Type | Owner | Meaning |
|---|---|---|---|
| `Weapon` | string | ProfileService | Weapon style id: `Sword`, `Gun` or `Fist` |
| `CrewRole` | string | ProfileService | Crew role id (`Captain`, `Navigator`, `Doctor`, `Cook`, `Shipwright`, `Musician`, `Archaeologist`, `Gunner`), or `""` |
| `Renown` | number | ProfileService | Meta currency, kept between voyages |
| `ShipTier` | number | ProfileService | 1 = Sloop, 2 = Brigantine, 3 = Galleon |
| `Gold` | number | ProfileService | Money for the current voyage |
| `InventoryJson` | string | ProfileService | JSON object `{ [itemId]: count }` |
| `HP`, `MaxHP` | number | CombatService | Health, kept between battles in a voyage. Other services heal through `CombatService.heal`. |
| `Resolve` | number | CombatService | Stress, 0–200 (decision D4). Other services change it through `CombatService.addResolve`. |
| `Condition` | string | CombatService | The current affliction or virtue id, or `""` |
| `ProfileLoaded`, `ProfileSaves` | boolean | ProfileService | Whether the profile has loaded, and whether this session will be saved |
| `Location` | string | VoyageService | `Ship`, `Battle`, `Event` or `Chart`. Controllers show or hide their UI and set the camera from this. |

## Service APIs (server)

### ProfileService — saved profile, builds, items
```lua
ProfileService.get(player): Profile?            -- { Renown, ShipTier, Weapon, CrewRole, Gold, Inventory: {[string]: number} }
ProfileService.setBuild(player, weaponId: string, roleId: string): boolean
ProfileService.addRenown(player, amount: number)
ProfileService.addGold(player, amount: number)  -- negative to spend; never goes below 0
ProfileService.giveItem(player, itemId: string, count: number)
ProfileService.takeItem(player, itemId: string, count: number): boolean   -- false if they don't have enough
ProfileService.resetVoyage(player)              -- Gold back to starting value, inventory back to the starting kit
```
Shared data it owns: `Shared.Data.Items`, `Shared.Data.Weapons`, `Shared.Data.Roles`.

### CombatService — battles
```lua
CombatService.startBattle(player, encounter: { Kind: "Battle" | "Elite" | "Boss", Enemies: { string } })
CombatService.isInBattle(player): boolean
CombatService.onFinished(callback: (player: Player, result: { Won: boolean, Kind: string }) -> ())
CombatService.heal(player, amount: number)      -- clamps to MaxHP
CombatService.addResolve(player, amount: number) -- negative relieves stress; clamps to 0..200
CombatService.restoreAll(player)                -- full HP, Resolve 0 (start of a voyage)
```
`Enemies` are ids from `Shared.Combat.Moves.Enemies`. Battles take place on `Workspace.BattleIsland.BattleArena`. A lost battle ends with `Won = false`; CombatService does not decide what happens next.

### ShipService — the ship camp
```lua
ShipService.placeOnShip(player)                 -- move the character onto their ship's deck and let them walk
ShipService.getShip(player): Model?             -- the ship model the player is using
```
It also runs the camp stations (found by their `Station` attribute, see decision D11): stash and crew chests, cook fire, workbench, ready bell, chart table.

### VoyageService — the sea chart and the run
```lua
VoyageService.openChart(player)                 -- show the sea chart to this player
VoyageService.setReady(player, ready: boolean)  -- the ready bell; when the whole crew is ready, sail to the chosen island
VoyageService.getVoyage(player): Voyage?        -- current run state (sea, node, map)
```
VoyageService owns the run loop: it puts players on the ship when they join, runs the chart and its vote, starts battles through CombatService, runs events, pays out through ProfileService, and sets `Workspace:SetAttribute("SeaPreset", …)` when the sea changes.

## The loop these make together

1. **Join:** ProfileService loads the profile. VoyageService starts a voyage and calls `ShipService.placeOnShip`.
2. **Camp (Location = Ship):** the player walks the deck and uses stations. The chart table calls `VoyageService.openChart`; the ready bell calls `VoyageService.setReady`.
3. **Chart (Location = Chart):** the player picks the next island. A crew votes; solo players just pick.
4. **Island:** a battle (`CombatService.startBattle`, Location = Battle), an event (Location = Event), a rest, or treasure.
5. **Back to camp** once the island is resolved, then repeat. A boss ends the sea; the last boss ends the voyage and pays Renown.

## Testing hooks

`Services/DevService.luau` exists only in Studio. It creates `ServerStorage.DevHook`, a BindableFunction that play tests invoke from the server side: `"ForceNext", kind` turns every island you can reach next into that kind, `"Call", service, function, ...` calls a service function on the first player, and `"State"` returns the voyage state and player attributes.

## Ability VFX (VFX Forge)

Effects are made in the `particles` place, not here. To bring one over: in particles, open it in the VFX Forge plugin and click **Export template…**; here, click **Import .rbxm…** then **Save as VFX template**, and save the place. Templates live in the place file at `ReplicatedStorage.AbilityVFXTemplates.<folder>.<Name>` (Rojo doesn't map it, so it leaves them alone).

`src/shared/VFXPlayer.luau` (`Shared.VFXPlayer`, a copy of `../particles/src/shared/AbilityVFX/Modules/VFXPlayer.luau` with the camera shake taken out, since this game has no screen shake; exempt from `--!strict`) plays them: `VFXPlayer.PlayByName(name, groundCFrame, { Scale = 1 })`. Play effects **on clients only**: the service that owns the moment fires its `<Feature>Remote` and each client plays it. Pass a point on the ground; the effect faces the CFrame's LookVector.

## UI conventions

- Build every screen with `Shared.UI.Paper` (`Paper.screen`, `Paper.sheet`, `Paper.button`, `Paper.label`, `Paper.tab`, `Paper.Colors`, `Paper.Fonts`, `Paper.Layers`), except battles.
- Battles use `Shared.UI.Ink` (decision D17): black panels with a cream edge and red shards, comic numbers. Its art is cut from the UI sheets in `assets/ui/sheets` and uploaded as images; `Ink.Images` holds the asset ids. `Client.Combat.Plates` draws the HP plates over each fighter with it, and `Client.Combat.Menu` is the FIGHT / ITEMS / FOCUS command menu (cut-out letters built from text labels, no images).
- One ScreenGui per controller, named `<Feature>Gui`.
- Must be usable with mouse, keyboard, gamepad and touch. Minimum button height 44 px.
- No uploaded images outside the battle kit, and no sounds yet: Paper screens draw with frames, strokes and text only.
- Adding battle art: put the sheet in `assets/ui/sheets`, cut it with `blender --background --factory-startup --python tools/ui/cut_sheet.py -- SHEET OUT_DIR`, copy the pieces you need into `assets/ui`, serve that folder on localhost and upload with the Studio MCP `upload_image` tool, then add the ids to `Ink.Images` (and a slice rect for anything 9-sliced). New art comes from ChatGPT (in Chrome): attach the sheets in `assets/ui/sheets` as a style guide, ask for flat vector pieces with hard edges on a transparent background, spaced apart so they cut cleanly, and ask for layers (slab, outline, shard, halftone, speed lines, burst) rather than finished panels so each layer can animate on its own. The prompts that made the current set are in that chat; its outputs are in `assets/ui/sheets/generated`. For a hollow bar frame, `tools/ui/bar_inside.py` makes the matching black backing and white fill shape.
