# An Average Voyage (working title)

A crew-based pirate roguelite for Roblox. Design decisions live in [design/decisions.md](design/decisions.md); background research is in [reports/](reports/).

## Project layout

| Path | Syncs to | What it is |
|---|---|---|
| `src/server` | ServerScriptService.Server | Server scripts. `World/Ocean` builds the terrain ocean; `World/Environment` applies the per-sea lighting. |
| `src/shared` | ReplicatedStorage.Shared | Shared modules. `World/SeaPresets` holds the Sea 1–3 sky, lighting and water presets. |
| `src/client` | StarterPlayerScripts.Client | Client scripts. |
| `src/workspace` | Workspace | **Generated** ship and island models. Don't edit these by hand; change the generator instead. |
| `tools/worldgen` | (not synced) | Python generator for the ships and the battle island. |

## Working with Rojo

```bash
rojo serve
```

Then connect from the Rojo plugin in Studio. To build a place file from scratch:

```bash
rojo build -o "AnAverageOnePiece.rbxlx"
```

## Regenerating the ships and island

The generator runs on Blender's bundled Python, so no separate Python install is needed:

```bash
"C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" --background --factory-startup --python tools/worldgen/build.py
```

Add `-- --write-models` to the end of that command to rewrite the models in `src/workspace` (ships, battle island), which Rojo then syncs into Studio. Without it, the run only prints the overlap report and exports the FBX meshes to `assets/export/`. Add `--preview <folder>` to also render preview images.

- `tools/worldgen/ships.py`: the hull generator and the three ship tiers (Sloop, Brigantine, Galleon)
- `tools/worldgen/props.py`: stations, furniture and figureheads
- `tools/worldgen/island.py`: the battle island
- `tools/worldgen/check.py`: the overlap checker
- `tools/worldgen/preview.py`, `clouds.py`: Blender scene, previews and FBX export
- `tools/worldgen/blsend.py`: sends code to a live Blender session (for example the one on port 9877)
- `tools/worldgen/rbx.py`: part, mesh and CFrame helpers, plus the `.model.json` writer

## Ocean and lighting in edit mode

The server builds the ocean and applies the Sea 1 lighting when the game starts. To see them while editing, run this once in the Studio command bar, then save the place:

```lua
require(game.ServerScriptService.Server.World.Ocean).build(true); require(game.ServerScriptService.Server.World.Environment).apply("Sea1")
```

Swap `"Sea1"` for `"Sea2"` or `"Sea3"` to preview the other seas.
