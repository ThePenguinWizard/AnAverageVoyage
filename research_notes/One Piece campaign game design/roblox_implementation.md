# Roblox (Luau) Engineering for a Turn-Based JRPG with Undertale-Style Dodging, Node Maps and Co-op Parties (as of Nov 2026)

Research notes by the Roblox-implementation researcher. Every Cited Finding has an inline source. Items under "Inferences" are my engineering reasoning from those findings. Items tagged **[unverified this session]** come from general knowledge and were not re-checked against a live source here, so the report writer should treat them as lower-confidence.

---

## 1. Bullet hell in Roblox: rendering approach, performance, pooling, update loop, determinism, and hit authority

### Takeaway
No mature open-source Roblox "Undertale battle engine" turned up. The practical path is a client-simulated 2D soul box built from pooled GuiObjects (or one EditableImage canvas) and updated in `RunService.PreRender`. Patterns are generated from a server-sent attack ID, seed and start time. The server validates damage and does not trust it. The real performance cost is the number of per-frame property writes, not the number of instances.

### Cited Findings
**Existing resources (sparse)**
- A DevForum thread dated Oct 27–29, 2025 asks how to build an Undertale-style battle box. Its only advice is to build bullet movement first, then hit detection, then polish. No code or modules are shared. — [DevForum: How would I go about making an Undertale-style battle system?](https://devforum.roblox.com/t/how-would-i-go-about-making-an-undertale-style-battle-system/4028030)
- A Roblox experience called "Undertale Battle Engine" exists. Its page says only its *asset loader* is "completely open source," available via the creator's community server. It is not a documented library. — [Roblox: Undertale Battle Engine](https://www.roblox.com/games/18508929778/Undertale-Battle-Engine)
- A DevForum thread shows another developer building an Undertale-style game entirely from UI. — [DevForum: UNDERTALE UI-based game in Roblox](https://devforum.roblox.com/t/undertale-ui-based-game-in-roblox/3484839)

**Performance data points (community, mostly 3D-part-based)**
- One developer reported handling about 180 bullets per frame (three players each firing one bullet per frame at 60 fps) by keeping bullets client-side and avoiding per-bullet server raycasts. They suggested updating clients only every few frames and interpolating. — [DevForum: Handling thousands of projectiles with high performance?](https://devforum.roblox.com/t/handling-thousands-of-projectiles-with-high-performance/735531)
- Another developer still saw lag at about 150 bullets even with client-side visuals. — [DevForum: More performant way to create a projectile?](https://devforum.roblox.com/t/more-performant-way-to-create-a-projectile/2312096)
- In a thread on thousands of moving objects, most of the cost came from "changing thousands of properties every single frame." — [DevForum: Optimizing manipulation of thousands of parts](https://devforum.roblox.com/t/optimizing-manipulation-of-thousands-of-parts/2944309)
- Bullet-hell developers use pooling ("part pooling") instead of creating and destroying instances. — [DevForum: What would the best way be to move gigantic amounts of bullets?](https://devforum.roblox.com/t/what-would-the-best-way-be-to-move-gigantic-amounts-of-bullets/768815)
- In a March 2022 bullet-curtain thread, the original poster pooled bullets client-side and asked about syncing 200+ bullets. The best reply said that if paths are deterministic, the server should send "information about each attack," not per-bullet updates, so each client generates the same pattern. The poster noted that homing bullets break pure determinism. The thread was never resolved and contains no FPS benchmarks. — [DevForum: Strategy to optimize performance on a bullet-hell game genre](https://devforum.roblox.com/t/strategy-to-optimize-performance-on-a-bullet-hell-game-genre-in-roblox/1706889)
- I found no published benchmark of GuiObject-based or EditableImage-based bullet counts on mobile (see Gaps).

**Update loop APIs**
- `RunService.RenderStepped` "has been superseded by PreRender which should be used for new work." `Stepped` has likewise been superseded by `PreSimulation`. `Heartbeat` is not deprecated and runs at the end of each frame after physics. `PreRender` runs before the frame is drawn, and rendering waits on it, so it should be used sparingly. `BindToRenderStep` is client-only, lower priority numbers run first, ties run in random order, and you must pass `Enum.RenderPriority.X.Value`. — [Roblox docs: RunService](https://create.roblox.com/docs/reference/engine/classes/RunService)

**EditableImage as a single-canvas renderer**
- Maximum size is 1024×1024, and `Size` is read-only. Drawing methods are `DrawRectangle`, `DrawCircle` (with optional anti-aliasing), `DrawLine`, `DrawImage`, `DrawImageTransformed` (scale, rotate, pivot), `DrawImageProjected` and `WritePixelsBuffer` (raw RGBA, `Size.X*Size.Y*4` bytes). Create one with `AssetService:CreateEditableImage()` and display it via `ImageLabel.ImageContent = Content.fromObject(img)`. — [Roblox docs: EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage)
- "For security purposes, using EditableImage fails by default in published games." You must enable **Enable Mesh / Image APIs** in Creator Dashboard settings. Client memory budgets are strict, creation APIs can return nil when the budget is exhausted, and **only one EditableImage updates on screen per frame**. — [Roblox docs: EditableImage](https://create.roblox.com/docs/reference/engine/classes/EditableImage)
- Community reports put a 1024×1024 image at about 4 MB. One developer hit budget errors after about 5–6 large images, and another found `WritePixelsBuffer` "kind of slow." — [DevForum: memory budget limits error](https://devforum.roblox.com/t/failed-to-create-empty-editableimage-that-was-requested-due-to-reaching-memory-budget-limits-error/3490799); [DevForum: Client Beta Mesh & Image APIs](https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293)
- A community 2D pixel renderer built on EditableImage exists (PixelRasterizer), as does the OSGL graphics library. Both are useful references for a canvas approach. — [DevForum: PixelRasterizer](https://devforum.roblox.com/t/editableimage-pixelrasterizer-real-time-2d-pixel-grid-system-with-dynamic-lighting-editableimage-rendering/3881135); [DevForum: OSGL](https://devforum.roblox.com/t/osgl-editableimage-graphics-library/3066757/51)

**Clipping of rotated bullets (important 2026 change)**
- Previously, rotated GuiObjects were not clipped cleanly by a `ClipsDescendants` parent. An announcement dated July 14, 2026 added `StarterGui.ClipsDescendantsSupportsRotation`. It became the default on Sept 24, 2026, and the property is scheduled for removal in Nov 2026, making the new behavior permanent. Rotated and Path2D children are now clipped by a non-rotated `ClipsDescendants` parent. Rotated *parents* still need a CanvasGroup to clip, and UICorner clipping still needs a CanvasGroup. The announcement says the change has no new performance cost. — [DevForum: Clipping Support for Rotated Elements & Path2D](https://devforum.roblox.com/t/opt-in-phase-introducing-clipping-support-for-rotated-elements-path2d/4737864)

**Networking primitives for dodge telemetry**
- `UnreliableRemoteEvent` is unordered and unreliable, and dropped events are not resent. Payloads over **1000 bytes are dropped**. Client-to-server sends are capped at about **500 requests/sec per client**, shared across all remotes of the same type. It is meant for ephemeral or continuously changing data. — [Roblox docs: UnreliableRemoteEvent](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent)

**Engine-level server authority (2026)**
- Roblox's Server Authority model (`Workspace.AuthorityMode = Server`) predicts client input locally and rolls back on misprediction. It requires settings including `SignalBehavior = Deferred`, `UseFixedSimulation`, `StreamingEnabled`, NextGenerationReplication and `PlayerScriptsUseInputActionSystem`. — [Roblox docs: Server authority model](https://create.roblox.com/docs/projects/server-authority)
- Its release status is unclear in 2026 sources. A post titled "[Full Release]" calls it opt-in and "available now as a Beta to all experiences." A Roblox newsroom post from July 2026 describes the system. Developers report input-delay issues at high ping. — [DevForum: Full Release – Server Authority](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993); [Roblox Newsroom Jul 2026](https://about.roblox.com/newsroom/2026/07/creating-responsive-cheat-resistant-games-roblox-server-authority); [DevForum: input delay scales with player count](https://devforum.roblox.com/t/server-authority-input-delay-scales-with-player-count-at-high-ping/4763481)

### Inferences
- **Recommended approach: GUI soul box with pooled ImageLabels.**
  - Build one `Frame` (the box) with `ClipsDescendants = true`. Simulate in a fixed virtual coordinate space (for example 240×240 "game pixels"), and map to screen with a `UIScale` or by setting `Position = UDim2.fromOffset(x*k, y*k)`.
  - Run circle-vs-circle collision (`(dx*dx+dy*dy) < (r1+r2)^2`) in those virtual units. Do not read `AbsolutePosition`/`AbsoluteSize` every frame. This keeps the math the same on every device, which you need for any server replay.
  - Keep a free-list pool (preallocate, say, 300 ImageLabels per bullet type, toggle `Visible`). Pick one sprite sheet with `ImageRectOffset` and `ImageRectSize` (see Section 4).
  - Write only `Position` (and `Rotation` if needed) per bullet per frame. Skip writes for unchanged values.
  - Because property writes dominate cost, cap active bullets per pattern. A conservative target for a mobile-safe budget is about 150–300 simultaneous GUI bullets. This figure is extrapolated from the 150–200 counts that caused lag with 3D parts, and is **not benchmarked**.
- **Alternative: EditableImage canvas** (for example 256×256, displayed with `ResampleMode = Pixelated`). Each frame you redraw with `DrawRectangle` to clear and `DrawImage`/`DrawCircle` per bullet.
  - This fits a pixel-art look and removes the instance count. However, it hits the 1-update-per-frame limit, the memory budget, the opt-in toggle, and possible nil on low-memory phones.
  - Keep the GUI renderer as a fallback if `CreateEditableImage` returns nil. Never run two changing EditableImages at once.
- **3D arena alternative** (Parts on a plane viewed from a fixed orthographic-like camera): possible, but this is where most of the "lag at 150 bullets" reports come from. Prefer GUI unless you want 3D effects. If you do use parts, `workspace:BulkMoveTo()` with `Enum.BulkMoveMode.FireCFrameChanged` disabled is the standard bulk-move tool **[unverified this session]**.
- **Update loop**: drive the dodge sim from `RunService.PreRender` with `dt`. Prefer a fixed-step accumulator (for example 1/60 s steps) so pattern math is frame-rate independent and replayable. Keep per-frame work tight, because rendering waits on PreRender.
- **Determinism and sync**:
  - The server picks `{attackId, seed, startServerTime, durationSec}` and fires it to each party member. Each client builds the pattern with `Random.new(seed)` and evaluates bullets as a function of time `t = workspace:GetServerTimeNow() - startServerTime`. (`GetServerTimeNow` and `Random.new` are standard APIs **[unverified this session]**.)
  - Homing or "aim at player" bullets should only use the *local* player's own soul position. That is fine because each player dodges in their own box.
- **Co-op structure**: like Undertale, each party member dodges the enemy's attack in their own box at the same time, with their own soul, and takes damage individually. Other players' souls are optional "ghosts" sent at about 10–20 Hz over `UnreliableRemoteEvent` with quantized positions (for example two int16s), well under the 1000-byte cap. No real-time cross-client collision is needed.
- **Hit authority (anti-cheat tradeoff)**:
  - A purely client-reported "I got hit N times" lets exploiters report 0 hits. Practical options, from cheapest to strongest:
    1. **Server-side minimum damage**: the server computes expected damage for an "idle" player and caps how far below that a client can report. This is weak but cheap.
    2. **Input-trace replay**: the client streams soul positions (for example 20 Hz, quantized) or a compact input log. At phase end the server re-simulates the deterministic pattern with the same seed and computes hits itself. This is authoritative for deterministic patterns. Homing bullets are replayable because they depend only on the logged soul position.
    3. **Plausibility checks**: enforce a max soul speed and in-bounds position on the trace.
  - Option 2 is the strongest fit for a turn-based game because the dodge phase is short (about 5–15 s) and latency barely matters. Damage is applied at the end of the phase or in batches, not per frame.
  - The engine Server Authority mode is physics/character-oriented. It does not apply to a GUI minigame, and enabling it forces `SignalBehavior = Deferred` and other settings. Don't adopt it just for this.
- **Latency**: the server should allow a grace window (for example `duration + 1–2 s`) before closing the phase. Clients should also run a short countdown (for example 0.5–1 s) before bullets spawn, which hides network skew.

### Gaps
- No public, current (2025–2026) Roblox bullet-hell or Undertale battle engine with source code was found. The best leads are the UI-based Undertale project thread and the asset-loader-only "Undertale Battle Engine" experience.
- No benchmark of how many GuiObjects or EditableImage draws per frame mid-range mobile handles. The developer must profile with the MicroProfiler and the Developer Console on a low-end Android device.
- No official per-device EditableImage memory budget number. Roblox publishes none and has no API to query remaining budget.

---

## 2. Turn-based combat architecture (server-authoritative state machine, remotes, party turn sync, AFK timeouts, frameworks)

### Takeaway
Run each battle as a server-side state machine (one ModuleScript object per battle). Clients only submit *intents* over a small set of validated RemoteEvents, and the server broadcasts state diffs or snapshots. For frameworks, Knit and Roact are both dead and archived. Use plain ModuleScripts or a lightweight service loader, react-lua/Fusion/Vide for UI, ProfileStore for saves, and optionally a buffer-based networking library (Blink or Zap).

### Cited Findings
- **Knit is archived**: its README reads "Knit has been archived and will no longer receive updates," and the repo was archived on **Jul 31, 2024**. — [GitHub: Sleitnick/Knit](https://github.com/Sleitnick/Knit)
- **Roact is deprecated**: "This repository is deprecated and no longer maintained." It was archived on **Dec 13, 2023**, and the README points to **react-lua**. — [GitHub: Roblox/roact](https://github.com/Roblox/roact)
- React-lua is recommended for long-term work in community discussion because of its maturity and docs. Fusion is a Roblox-native reactive library (MIT) and has been described as less mature. Vide is praised for concise syntax. — [DevForum: Fusion vs React-lua](https://devforum.roblox.com/t/fusion-vs-react-lua-which-one-to-use-for-long-term-development/2781328/2)
- **ProfileStore** (loleris) is the successor to ProfileService. It is a DataStore wrapper handling auto-saving and **session locking**, and is still actively maintained. A Feb 2025 tutorial still recommends it. — [DevForum: ProfileStore](https://devforum.roblox.com/t/profilestore/3190543); [GitHub mirror: ProfileStore](https://github.com/ISFOR1/ProfileStore); [DevForum: ProfileStore tutorial (Feb 2025)](https://devforum.roblox.com/t/tutorial-learn-roblox-db-in-20-minutes-saving-player-data-to-the-database-using-profilestore-with-types/3455968)
- **Networking libraries**:
  - Community benchmarks rank **Blink** slightly ahead of **Zap** for bandwidth and FPS. Both beat **Packet**, and ByteNet's results are inconsistent.
  - One poster noted ByteNet and Zap lacked protection against oversized malicious buffers. **BlinkBlox** markets full validation of client input.
  - All of these benchmarks are self-published.
  - — [DevForum: Packet](https://devforum.roblox.com/t/packet-networking-library/3573907); [DevForum: Zap or ByteNet](https://devforum.roblox.com/t/zap-or-bytenet-performance-security/2888968); [DevForum: BlinkBlox](https://devforum.roblox.com/t/blinkblox-buffer-networking-that-checks-everything-a-client-sends/4898948); [GitHub: ByteNet](https://github.com/ffrostfall/ByteNet)
- RemoteEvent client-to-server traffic is rate-limited to about 500 requests/sec per client per remote type. — [Roblox docs: UnreliableRemoteEvent](https://create.roblox.com/docs/reference/engine/classes/UnreliableRemoteEvent)
- Server Authority mode requires `SignalBehavior = Deferred`. If you ever adopt it, event handlers will run deferred rather than immediately, which affects state-machine code that assumes immediate signal firing. — [Roblox docs: Server authority model](https://create.roblox.com/docs/projects/server-authority)

### Inferences
- **Battle state machine on the server**. Phases:
  `Intro → CommandSelect (all living party members choose simultaneously, with a deadline) → ResolvePlayerActions (ordered by Speed stat) → EnemyTelegraph → DodgePhase (clients simulate; server waits for traces with a deadline) → ResolveDamage/Stress → CheckEnd → loop`.
  - Store everything in one `BattleState` table (party, enemies, turn number, RNG seed, phase, deadline). Only the server mutates it.
- **Remote surface (keep it tiny and validated)**:
  - `Battle.SubmitAction(battleId, actionId, targetIndex)` is a RemoteEvent. The server checks that the phase is CommandSelect, the player is in this battle and alive, the action is unlocked, they have the resources, and the target is valid.
  - `Battle.SubmitDodgeTrace(battleId, attackSeq, bufferTrace)` sends the trace as a `buffer` (buffers are compact).
  - `Battle.State` is a server-to-client RemoteEvent with snapshots or diffs.
  - Avoid `RemoteFunction:InvokeClient`. If a client never returns, the server thread hangs (standard Roblox guidance **[unverified this session]**).
- **AFK and timeouts**: each CommandSelect has a deadline (for example 30–45 s, shown as a UI timer). On expiry, auto-pick "Defend" or "Basic attack." Count consecutive auto-turns, and after N, mark the player AFK. Let teammates vote-kick, or keep AFK-piloting via simple AI.
  - During DodgePhase, a missing trace counts as "took the idle-player hits" (a pessimistic default), so stalling never helps.
  - Handle `Players.PlayerRemoving` mid-battle by converting the slot to AI or a downed state.
- **Replicated state options**: a hand-rolled snapshot RemoteEvent is enough for a turn-based game, because updates are infrequent. A replica library (loleris's ReplicaService, or a newer successor if one exists) adds convenience but is not required.
- **Recommended stack (Nov 2026)**:
  - Plain ModuleScripts with a simple service/controller loader (Knit-style, but self-owned).
  - react-lua or Fusion (or Vide) for UI.
  - ProfileStore for persistence.
  - Optionally Blink or Zap codegen for typed buffers, which also gives schema-level validation. Still sanity-check values server-side.
  - Tooling: Rojo + Wally, plus strict Luau types **[unverified this session]**.

### Gaps
- I did not verify the current status of loleris's ReplicaService or whether a successor "Replica" module has been released.
- No authoritative 2025–2026 benchmark comparing Fusion, react-lua and Vide performance on mobile was found.

---

## 3. Parties and sessions: lobby → reserved server teleports, matchmaking, saving progress and mid-run saves

### Takeaway
`TeleportService:ReserveServer()`/`ReserveServerAsync()` and `TeleportPartyAsync`/`TeleportToPrivateServer` are **deprecated**. The current pattern is `TeleportAsync(placeId, playersArray, TeleportOptions)` with `TeleportOptions.ReservedServerId = HttpService:GenerateGUID()` (max 50 players per call). Never trust TeleportData. Persist run state in ProfileStore so a mid-run disconnect or rejoin can resume.

### Cited Findings
- `ReserveServer` and `ReserveServerAsync`: "This function is deprecated and no longer supported. Use TeleportAsync() with TeleportOptions.ReservedServerId instead." For new work, generate a GUID with `HttpService:GenerateGUID()`. "Reusing the same ID routes subsequent teleports to that same server." — [Roblox docs: TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService)
- Other deprecated methods are `Teleport`, `TeleportPartyAsync` ("Use TeleportAsync() instead"), `TeleportToPlaceInstance`, `TeleportToPrivateServer` and `TeleportToSpawnByName`. The docs say "the numerous teleport functions have been combined into a single method." — [Roblox docs: TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService)
- `TeleportAsync(placeId, players, teleportOptions)` yields. "No more than 50 players can be teleported with a single TeleportAsync() call," and "groups of players can only be teleported within a single experience." With a reserved or VIP destination it returns a `TeleportAsyncResult`. — [Roblox docs: TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService)
- "Exploiters can spoof teleport data." Send secure data through a server-side service such as DataStoreService. Teleport settings are stored locally and can be manipulated. — [Roblox docs: TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService)
- `TeleportInitFailed(player, teleportResult, errorMessage, placeId, teleportOptions)` fires on failure. `SetTeleportGui` sets a loading screen for the destination. — [Roblox docs: TeleportService](https://create.roblox.com/docs/reference/engine/classes/TeleportService)
- **MemoryStore limits**:
  - Keys and sort keys max 128 chars, values max 32 KB.
  - One sorted map or queue max 1,000,000 items / 100 MB.
  - Per-partition request limits are set on the backend and can change, and throttling returns `RequestThrottled`. Roblox recommends exponential backoff and sharding.
  - `GetQueue` exists for queue-based matchmaking.
  - — [Roblox docs: Memory store sorted map](https://create.roblox.com/docs/cloud-services/memory-stores/sorted-map); [Roblox docs: Memory stores](https://create.roblox.com/docs/cloud-services/memory-stores); [Roblox docs: MemoryStore best practices](https://create.roblox.com/docs/cloud-services/memory-stores/best-practices)
- Sharding helps with per-structure request limits but not universal or global limits (Roblox staff reply). — [DevForum: MemoryStoreService throttling](https://devforum.roblox.com/t/memorystoreservice-requests-throttling-despite-not-being-near-limit/2810573/8)
- RDC 2025 announced **custom matchmaking** alongside server authority for all creators. — [Roblox Newsroom: RDC 2025](https://about.roblox.com/newsroom/2025/09/roblox-rdc-2025)
- ProfileStore provides session locking, which prevents two servers from writing one player's data at once (for example during a teleport). — [DevForum: ProfileStore](https://devforum.roblox.com/t/profilestore/3190543)

### Inferences
- **Recommended flow**:
  1. **Lobby place**: players form a party via a ProximityPrompt "ship" or an invite UI. The party leader hits "Set Sail." For friends on *different* lobby servers, use MessagingService invites plus a MemoryStore SortedMap `party:{partyId}` with a TTL (MessagingService is **[unverified this session]**).
  2. **Server-side**: `local opts = Instance.new("TeleportOptions"); opts.ReservedServerId = HttpService:GenerateGUID(); opts:SetTeleportData({partyId=..., runId=...})`, then `TeleportService:TeleportAsync(RUN_PLACE_ID, partyPlayers, opts)` inside `pcall` with retry and backoff. Handle `TeleportInitFailed` by retrying only the failed player to the *same* `ReservedServerId`.
  3. **Run place**: use TeleportData only as a *hint* (partyId/runId). The authoritative run state lives in DataStore/ProfileStore (or a MemoryStore hash keyed by runId for transient party state). Validate that each arriving player belongs to that runId.
  4. **Matchmaking for strangers**: a MemoryStore queue or SortedMap with sharded keys. A single lobby "matchmaker" elected via a MemoryStore lock pops groups of 2–4 and teleports them. If Roblox's custom matchmaking is available to you, evaluate it first.
- **Mid-run saves**:
  - Store `currentRun = {runId, seed, mapNodeIndex, partyComposition, hp/stress per unit, inventory, version}` in each player's profile. Write it at safe checkpoints (after each node is resolved, not mid-battle). ProfileStore autosaves periodically and saves on leave.
  - For a co-op run, designate the host's profile as the source of truth for shared map state. Alternatively, store shared run state under a separate DataStore key `run:{runId}` updated with `UpdateAsync` (DataStore ~4 MB per key and per-key write throttles **[unverified this session]**).
  - **Rejoin**: if a player disconnects, keep `{runId → reservedServerId}` in MemoryStore so they can rejoin via `TeleportAsync` with the same `ReservedServerId` while the server lives. Otherwise, resume from the last checkpoint.
- Seat counts: the run place's Max Players should equal the party cap (for example 4) to avoid strangers. Reserved servers are only joinable via teleport anyway.

### Gaps
- Exact fields of `TeleportAsyncResult` (`PrivateServerId`/`ReservedServerAccessCode`) were not exposed in the fetched doc text.
- Details, APIs and availability of the RDC 2025 "custom matchmaking" feature as of Nov 2026 were not researched in depth.
- Current DataStore per-key size and throttle numbers were not re-verified this session (check the "Error codes and limits" doc).

---

## 4. UI for mobile, PC and console: scaling, safe areas, touch dodge controls, pixel art, 9-slice, fonts, tweens, and newer UI features

### Takeaway
Use scale-based layout with `UIAspectRatioConstraint` on fixed-shape panels (the soul box must be square) and respect `ScreenInsets`. Use the (now fully released) Input Action System for cross-platform bindings, but hand-roll touch drag or joystick input for the dodge box. Get crisp pixel art with `ResampleMode = Pixelated`, sprite sheets via `ImageRectOffset`, and 9-slice via `ScaleType.Slice` + `SliceCenter`.

### Cited Findings
- **Safe areas**:
  - `ScreenGui.ScreenInsets` (enum `ScreenInsets`) values are `None`, `DeviceSafeInsets` (avoids notches but not Roblox's top bar), `CoreUISafeInsets` (default, below the top bar) and `TopbarSafeInsets`.
  - `SafeAreaCompatibility` (default `FullscreenExtension`) lets full-screen backgrounds extend past notches.
  - `GuiService.TopbarInset` is a Rect of unoccupied top-bar space.
  - — [Roblox docs: ScreenInsets enum](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets); [Roblox docs: SafeAreaCompatibility](https://create.roblox.com/docs/reference/engine/enums/SafeAreaCompatibility); [Roblox docs: ScreenGui](https://create.roblox.com/docs/reference/engine/classes/ScreenGui); [DevForum: TopbarSafeInsets topbar](https://devforum.roblox.com/t/how-to-produce-a-topbar-based-on-topbarsafeinsets/2914413)
- Pitfall: `GuiService:GetGuiInset()` returns the TopbarSafeInsets inset, not `None`. One workaround measures the offset between two ScreenGuis. — [DevForum: GetGuiInset for ScreenInsets?](https://devforum.roblox.com/t/guiservicegetguiinset-for-screeninsets/2803966)
- **Pixel art and sprites**:
  - `ImageLabel.ResampleMode` set to `Pixelated` "keeps the sharp edges of pixels." The default smooths when scaled.
  - `ImageRectOffset`/`ImageRectSize` display a sub-rect for sprite sheets ("multiple images packed into one file to reduce load times").
  - `ScaleType.Slice` + `SliceCenter` (Rect) gives 9-slice, where corners stay at source size. `SliceScale` scales the edges (default 1.0).
  - `ImageContent` accepts an asset URI or an EditableImage.
  - — [Roblox docs: ImageLabel](https://create.roblox.com/docs/reference/engine/classes/ImageLabel)
- **Input Action System (IAS)**:
  - The model is `InputContext` → `InputAction` → `InputBinding`, where a binding is a key, gamepad button or touch tap.
  - Official guidance is to give each InputAction a binding for gamepad, keyboard/mouse **and** touch.
  - IAS reached full release, and the Studio **Input Action Manager** editor is also fully released. It can bind touch input to UI buttons.
  - — [Roblox docs: Input Action System](https://create.roblox.com/docs/input/input-action-system); [DevForum: Full Release IAS](https://devforum.roblox.com/t/full-release-input-action-system-ias-newly-converted-player-scripts/4678416?page=4); [DevForum: Full Release Input Action Manager](https://devforum.roblox.com/t/full-release-input-action-manager/4965021/1)
- IAS touch-gesture coverage is limited. Developers still use UserInputService for TouchSwipe/TouchRotate-type gestures, and a third-party plugin (InputPro v1.2.0) adds Tap, LongPress and Swipe. — [DevForum: Client Beta IAS thread](https://devforum.roblox.com/t/client-beta-input-action-system-is-now-available-to-publish-in-experiences/3890979); [DevForum: InputPro](https://devforum.roblox.com/t/120-inputpro-a-free-input-mapper-for-roblox/4559331)
- Cross-platform guidance doc (layouts and inputs per device): — [Roblox docs: Cross-platform](https://create.roblox.com/docs/projects/cross-platform)
- **Flex layout**: `UIListLayout` gained flex features (wrapping, grow and shrink, `ItemLineAlignment`) plus a `UIFlexItem` instance. These are now in client release. — [DevForum: Flex features for UIListLayout client release](https://devforum.roblox.com/t/flex-features-for-uilistlayout-client-release/3096190)
- **Path2D** is fully released. It provides 2D splines in UI for graph editors and path animations, and can be animated with TweenService. — [Roblox docs: 2D paths](https://create.roblox.com/docs/ui/2D-paths); [DevForum: Path2D full release](https://devforum.roblox.com/t/path2d-full-release/3027288/1)
- **UI Styling** (style sheets for UI) arrived in 2025 per the Creator Roadmap summer update. — [DevForum: Creator Roadmap 2025 Summer Update](https://devforum.roblox.com/t/creator-roadmap-2025-summer-update/3880746)
- **Rotated-element clipping** is now default (Sept 24, 2026), and CanvasGroup is still needed for rotated parents and UICorner clipping. — [DevForum: Clipping Support for Rotated Elements & Path2D](https://devforum.roblox.com/t/opt-in-phase-introducing-clipping-support-for-rotated-elements-path2d/4737864)
- RDC 2025: Studio Assistant supports MCP, including importing a UI laid out in Figma. — [allthings.how RDC 2025 roundup](https://allthings.how/roblox-rdc-2025-10-creator-tools-and-updates-that-matter/); [Roblox Newsroom: RDC 2025](https://about.roblox.com/newsroom/2025/09/roblox-rdc-2025)

### Inferences
- **Layout rules**:
  - Size containers with Scale and pin aspect with `UIAspectRatioConstraint` (soul box `AspectRatio = 1`, battle panel for example 16:9).
  - Use Offset only inside a `UIScale`-scaled "design canvas" (for example design at 1920×1080 or at a 480×270 pixel grid). Compute `UIScale.Scale = min(viewport.X/designW, viewport.Y/designH)` on `Camera:GetPropertyChangedSignal("ViewportSize")`.
  - For pixel art, round the scale to an integer multiple when possible (2×, 3×) to avoid uneven pixel widths.
  - Use `UITextSizeConstraint`/`TextScaled` carefully, since pixel fonts look bad at non-integer sizes. `UIPadding`, `UICorner`, `UIStroke`, `UIGradient` and `UISizeConstraint` are the standard modifiers **[unverified this session]**.
- **Battle screen ScreenGui**: `IgnoreGuiInset = true` with `ScreenInsets = DeviceSafeInsets` for the arena. Keep menus (FIGHT/ACT/ITEM/MERCY-style) inside `CoreUISafeInsets`. On console, use `GuiService.SelectedObject` plus `NextSelectionUp/Down` for gamepad navigation of command menus **[unverified this session]**.
- **Touch dodge controls** (the hardest UX problem). Offer two modes in settings:
  1. **Relative drag ("trackpad")**: the soul moves by the finger's delta, scaled by a sensitivity setting. The finger never covers the soul because you can drag anywhere on the lower half of the screen. Implement with `UserInputService.TouchStarted/TouchMoved/TouchEnded` (track one `InputObject` by reference), or `UIDragDetector` on an invisible full-screen pad **[UIDragDetector unverified this session]**. This is usually the best feel for bullet hells on phones.
  2. **Virtual joystick/D-pad**: a custom-built thumbstick (Roblox's default thumbstick is for character movement). Use IAS `InputAction` of type Direction2D for keyboard (WASD/arrows) and gamepad left stick so all three platforms feed the same `Vector2`.
  - Disable default character controls during battle (for example `ContextActionService`/`PlayerModule` controls `:Disable()`) **[unverified this session]**.
- **Pixel-art pipeline**:
  - Pack bullets, souls and UI icons in power-of-two sprite sheets. Set every ImageLabel `ResampleMode = Pixelated`, and use 9-slice for dialogue boxes, with `SliceScale` tuned to integer pixel multiples.
  - Typewriter text: use `TextLabel.MaxVisibleGraphemes` incremented over time. It works with RichText **[unverified this session]**.
  - Custom fonts: use `FontFace = Font.new(assetUri, weight, style)` **[unverified this session]**.
- **Animation**: TweenService for menu slides and HP-bar drains. CanvasGroup for fading whole panels (`GroupTransparency`), but it costs texture memory, so use few. Path2D for curved projectile tracers or "ship sailing along route" animations.

### Gaps
- Whether Roblox now supports uploading custom font files directly (vs. only the Roblox font library) was not verified.
- The exact 2025–2026 status, API and performance cost of "UI Styling" (StyleSheet/StyleRule) was not researched.
- Full-release date for IAS was not visible in the snippets.

---

## 5. Node map: generating and drawing a branching (Inscryption/Slay-the-Spire-style) map, with reproducible seeding

### Takeaway
Generate the map **on the server** from `Random.new(seed)` and send the node graph as plain data, or send only the seed plus a generator version. Draw it in a `ScrollingFrame` with nodes as ImageButtons and edges as rotated thin Frames or Path2D splines. Rotated edges now clip correctly inside the scroll area as of the Sept 2026 clipping change.

### Cited Findings
- Path2D gives 2D spline instances in UI. You can place UI objects along a path and animate along it with TweenService. — [Roblox docs: 2D paths](https://create.roblox.com/docs/ui/2D-paths)
- Rotated GuiObjects and Path2D are now clipped by a `ClipsDescendants` parent, such as a ScrollingFrame or Frame, regardless of rotation. This applies by default since Sept 24, 2026 and permanently after Nov 2026. — [DevForum: Clipping Support for Rotated Elements & Path2D](https://devforum.roblox.com/t/opt-in-phase-introducing-clipping-support-for-rotated-elements-path2d/4737864)
- Flex layout (`UIFlexItem`, wrapping) is available for auto-laid-out rows of nodes. — [DevForum: Flex features client release](https://devforum.roblox.com/t/flex-features-for-uilistlayout-client-release/3096190)

### Inferences
- **Generation algorithm** (Slay the Spire style):
  - Use rows 0..N (for example 12–15 floors per island/arc) and columns 0..6. Draw several random walks from bottom to top (for example 6 paths). Each step goes to column `c-1`, `c` or `c+1` (`rng:NextInteger(-1,1)`, clamped), and the walk rejects crossing edges.
  - Merge coincident nodes, then assign node types by weighted roll with constraints (no elite in the first 3 rows, a rest site before the boss row, no two shops in a row).
  - Use one `Random.new(seed)` instance and call it in a fixed order so all clients and replays match. (`Random` is seedable, and `math.random` shares global state, so avoid it here **[unverified this session]**.)
- **Authority**: the server generates and stores the graph in run state. Clients get the graph table. Sending only the seed is smaller, but a client-side generator change (version drift) would desync, so include `generatorVersion` if you send the seed. Party voting on the next node: each member sends `VoteNode(nodeId)` and the server resolves by majority, then leader, then random after a timeout.
- **Drawing edges with rotated Frames** (cheap, no extra API): for points A and B in pixel space, set `mid = (A+B)/2`, `len = (B-A).Magnitude`, `angle = math.deg(math.atan2(B.Y-A.Y, B.X-A.X))`. Create a Frame with `AnchorPoint = (0.5,0.5)`, `Position = UDim2.fromOffset(mid.X, mid.Y)`, `Size = UDim2.fromOffset(len, thickness)` and `Rotation = angle`.
  - For dotted Inscryption-style trails, place small dot ImageLabels at intervals along A→B instead.
  - Lay out nodes in a fixed "map canvas" size, for example 600×2000 offset, inside a ScrollingFrame scaled by UIScale, so the angle math stays in one coordinate space.
- **Path2D edges** are better for curved or hand-drawn-looking routes. Use one Path2D per edge with 2–3 control points jittered by the same seeded RNG. Animate the "ship" icon along the chosen path for juice.
- Performance: a 15×7 map has well under 200 edges plus nodes, which is trivial. Build it once, not per frame.

### Gaps
- No Roblox-specific open-source branching-map generator was searched for or found. The algorithm above follows the well-known roguelike approach, not a cited Roblox source.

---

## 6. Audio: SoundService, battle music systems, and audio upload, privacy and licensing rules

### Takeaway
Custom music must be uploaded by the experience owner (user or group) and stays private to that owner's experiences. Uploads are capped per month (10 by default, 100 with ID verification), and public SFX uploads require ID verification. Plan the soundtrack around few, longer tracks and possibly Roblox's licensed music catalog.

### Cited Findings
- Since the March 2022 audio privacy change, audio over 6 seconds uploaded by users is private. An experience can only use audio uploaded by its owner (user or group) or Roblox's licensed catalog, which remains public. — [DevForum: [Action Needed] Upcoming Changes to Asset Privacy for Audio](https://devforum.roblox.com/t/1701697); [DevForum: [Update] Changes to Asset Privacy for Audio](https://devforum.roblox.com/t/update-changes-to-asset-privacy-for-audio/1715717)
- Audio upload is free with monthly caps: **10/month by default, 100/month with ID verification**. Users under 13 are effectively stuck at 10. — [DevForum: Changes to Asset Privacy for Audio](https://devforum.roblox.com/t/action-needed-upcoming-changes-to-asset-privacy-for-audio/1701697?page=3)
- Public sound-effect uploads became available, but creators must be **ID-verified**, and public SFX "should not include music or speech." — [DevForum: Public Sound Effects Upload Are Now Available](https://devforum.roblox.com/t/public-sound-effects-upload-are-now-available-for-creators/2980704)
- Roblox provides rights-cleared music and professional SFX from partners in its catalog. — [DevForum: Asset Privacy for Audio](https://devforum.roblox.com/t/1701697)

### Inferences
- **Upload under the group that owns the experience.** If the game is group-owned, audio uploaded to a personal account may not play there. Assets must belong to the experience owner (based on the privacy rules above; also check the asset-permissions sharing UI) **[mechanics unverified this session]**.
- **Battle music system**:
  - Use a client-side MusicController module with two `Sound` objects for crossfading (overworld ↔ battle ↔ victory). Run TweenService on `Volume` and use `SoundGroup`s (Music, SFX, UI) for player volume sliders saved in the profile.
  - Preload battle tracks with `ContentProvider:PreloadAsync` when entering a map node, so the battle sting starts instantly.
  - Use `Sound.TimePosition` for loop points if a track has an intro, or upload intro and loop as separate assets.
  - Sync bullet patterns to music beats by using the server start time and BPM rather than `Sound.TimePosition`, which drifts and can differ per client.
- Roblox's newer modular Audio API (`AudioPlayer`, `AudioFader`, `AudioEqualizer` connected with `Wire`) enables dynamic music layering, such as adding drums when HP is low. Note this as an option **[unverified this session]**.
- With 10–100 uploads per month, budget the soundtrack (for example one battle theme per island or arc, plus boss themes). Ship SFX as packed sound sprites where possible, or rely on the licensed SFX library.
- **IP caution**: do not upload actual One Piece anime music. The audio moderation and copyright pipeline will reject it or issue strikes. Commission or compose "inspired-by" tracks.

### Gaps
- I found no confirmed 2025–2026 update to the 10/100 monthly audio upload limits or duration and price rules. The sources are from 2022–2024, and the limits may have changed.
- The current state and documentation of the Audio API (AudioPlayer/Wire) was not fetched this session.

---

## 7. 2025–2026 Roblox platform changes relevant to this project

### Takeaway
The changes that matter most are:
- Deprecation of `ReserveServer` (use `TeleportOptions.ReservedServerId`).
- RenderStepped and Stepped superseded by PreRender and PreSimulation.
- Rotated-UI clipping becoming default (Sept to Nov 2026).
- Full release of the Input Action System.
- Server Authority (opt-in, physics-focused).
- A new content-rating regime with Roblox Kids (5–8), Roblox Select (9–15), standard 16+, and IARC ratings. A One Piece game with cartoon combat and drinking references must answer the questionnaire carefully.

### Cited Findings
- **Content maturity labels** are now **Minimal, Mild, Moderate, Content May Vary and Restricted**:
  - Minimal and Mild: eligible for **Roblox Kids (ages 5–8)** and **Roblox Select (ages 9–15)**.
  - Moderate: Roblox Select and standard Roblox (16+).
  - Content May Vary: age-checked 16+.
  - Restricted: age-verified 18+.
  - Without completing the Maturity & Compliance Questionnaire, Roblox restricts the game's playability for all players, and inaccurate answers risk moderation.
  - — [Roblox docs: Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)
- Roblox is moving to a new rating system with **IARC ratings**. Existing Kids and Select games must review pre-filled IARC ratings, and Kids/Select games without IARC ratings by **Jan 26, 2027** may be pulled from the Kids/Select catalog in Australia. — [Roblox docs: Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)
- Violence criteria consider whether it is direct ("hit, shot, or blown up"), who is targeted, a fantastical vs. realistic setting, art style, reactions and frequency. "Mild" includes unrealistic violence, such as bodies disappearing at 0 health. Any moment with realistic consequences pushes the game to Moderate or higher. Blood, gore, fear (scary vs. horrifying), crude humor and alcohol are rated separately. Alcohol references must be disclosed and are permitted in "games with the strictest age restrictions." — [Roblox docs: Content maturity](https://create.roblox.com/docs/production/promotion/content-maturity); [Roblox docs: Experience guidelines](https://create.roblox.com/docs/production/promotion/experience-guidelines)
- RDC 2025 (Sept 5–6, 2025, San Jose) announced server authority for all creators, custom matchmaking, and Studio Assistant with MCP. — [Roblox Newsroom: RDC 2025](https://about.roblox.com/newsroom/2025/09/roblox-rdc-2025); [DevForum: Creator Roadmap 2025 RDC Update](https://devforum.roblox.com/t/creator-roadmap-2025-rdc-update/3961527)
- Server Authority: a "[Full Release]" post describes it as an opt-in beta available to all experiences. It requires Deferred signals, fixed simulation, streaming and IAS-based player scripts. — [DevForum: Full Release Server Authority](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993); [Roblox docs: Server authority model](https://create.roblox.com/docs/projects/server-authority)
- Deprecations: `RunService.RenderStepped` → `PreRender`, `Stepped` → `PreSimulation` ([RunService docs](https://create.roblox.com/docs/reference/engine/classes/RunService)). `TeleportService.ReserveServer`/`ReserveServerAsync`/`TeleportPartyAsync`/`TeleportToPrivateServer`/`Teleport` → `TeleportAsync` ([TeleportService docs](https://create.roblox.com/docs/reference/engine/classes/TeleportService)). Roact → react-lua ([GitHub: Roblox/roact](https://github.com/Roblox/roact)). Knit archived ([GitHub: Sleitnick/Knit](https://github.com/Sleitnick/Knit)).
- UI: rotated and Path2D clipping (`StarterGui.ClipsDescendantsSupportsRotation`, removal Nov 2026) ([DevForum](https://devforum.roblox.com/t/opt-in-phase-introducing-clipping-support-for-rotated-elements-path2d/4737864)). IAS and Input Action Manager are fully released ([DevForum IAM](https://devforum.roblox.com/t/full-release-input-action-manager/4965021/1)). UI Styling arrived in 2025 ([Creator Roadmap Summer 2025](https://devforum.roblox.com/t/creator-roadmap-2025-summer-update/3880746)). EditableImage needs the Creator Dashboard opt-in ([EditableImage docs](https://create.roblox.com/docs/reference/engine/classes/EditableImage)).

### Inferences
- **Rating target**:
  - Pirate fist and sword fights where enemies "faint" or vanish at 0 HP, with no blood, plus cartoon art will likely land in **Mild**, keeping the game open to Roblox Select (9–15), the core audience for One Piece fans.
  - Explicit sake or booze drinking (Zoro, Shanks), visible blood, or realistic injury will likely push it higher. Prefer "meat" and "juice" or keep drinking off-screen, and render damage as flashes and stars.
  - Complete the questionnaire before any public playtest, since unrated games are restricted.
- **Monetization note**: this topic was not researched in this pass. Developer Products and Game Passes are the standard model, and paid random items (loot boxes) carry extra disclosure rules **[unverified this session]**.
- The game does not need Server Authority mode. Because it is opt-in and forces engine-wide settings (Deferred signals, streaming), adopting it for a UI-centric turn-based game adds risk without benefit.

### Gaps
- **IP and licensing risk**: using the "One Piece" name, characters or art on Roblox (DMCA takedown exposure) is a significant platform risk. It was not researched here and should be covered by the design/legal researcher or flagged in the report.
- 2025–2026 monetization rule changes (for example price floors, paid-random-item rules, Rewarded Video ads, regional pricing) were not researched within this tool-call budget.
- I could not confirm the exact current (Nov 2026) state of Server Authority (beta vs. GA). Sources from 2026 conflict in their wording.
