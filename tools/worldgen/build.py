"""Generate the ships and the battle island.

Ships are part models (decks, stations, masts, colliders) plus meshes (hull, castle walls, sails). The part models
go to src/workspace for Rojo; the meshes are exported as FBX to assets/export for upload to Roblox.

Run with Blender's Python:
    blender --background --factory-startup --python tools/worldgen/build.py -- [options]
Options:
    --write-models    write the .model.json files into src/workspace (Rojo then syncs them)
    --preview DIR     render preview images into DIR
In a live Blender session call build.main(["--live"]) to (re)build everything into a "Voyage" collection.
"""

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import check  # noqa: E402
import island  # noqa: E402
import ships  # noqa: E402
from rbx import mesh_to_parts, place, write_model  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "src", "workspace")
EXPORT = os.path.join(ROOT, "assets", "export")

# Showcase layout: the three tiers float side by side, bows toward the battle island.
SHIP_LAYOUT = [
    ("Sloop", ships.build_sloop, (-80.0, 0.0, 10.0)),
    ("Brigantine", ships.build_brigantine, (-12.0, 0.0, 0.0)),
    ("Galleon", ships.build_galleon, (72.0, 0.0, -6.0)),
]
ISLAND_CENTER = (0.0, 0.0, -360.0)
CLOUDS = [("CloudA", 3), ("CloudB", 8), ("CloudC", 21)]
IGNORE_PAIRS = [("Decks", "Rigging/MainMast"), ("Decks", "Rigging/Mast"), ("Decks", "Rigging/ForeMast"),
                ("Decks", "Rigging/MizzenMast"), ("Hull", "Rigging/Bowsprit")]


def run_checks(name, ship):
    problems = check.part_overlaps(ship.model, ignore=IGNORE_PAIRS)
    for (a, b), (pen, pa, pb) in problems[:25]:
        print("[overlap] %s: %s x %s  depth %.2f  (%s | %s)" % (name, a, b, pen, pa, pb))
    for gname in ("Sail", "SailStripe"):
        if gname in ship.meshes:
            hits = check.verts_inside_parts(ship.model, ship.meshes[gname].verts)
            if hits:
                print("[overlap] %s: %s vertices inside parts: %s" % (name, gname, hits))
    print("[check] %s: %d part overlaps over the threshold" % (name, len(problems)))


def shell_parts(name, builder, pos):
    """Write the Rojo model with the hull, walls and sails as wedge parts (used until mesh assets are uploaded)."""
    ships.COARSE = True
    try:
        ship = builder()
    finally:
        ships.COARSE = False
    for gname, buf in ship.meshes.items():
        thin = gname.startswith("Sail")
        ship.g_shell.add(mesh_to_parts(buf, gname, 0.25 if thin else 0.5, "Fabric" if thin else "SmoothPlastic",
                                       collide=not thin))
    place(ship.model, pos)
    count = write_model(ship.model, os.path.join(OUT, "Ships", name + ".model.json"))
    print("[worldgen] %s: wrote %d parts (wedge shell)" % (name, count))
    return ship


def main(argv):
    live = "--live" in argv
    preview_dir = argv[argv.index("--preview") + 1] if "--preview" in argv else None
    write_models = "--write-models" in argv
    os.makedirs(os.path.join(OUT, "Ships"), exist_ok=True)
    os.makedirs(EXPORT, exist_ok=True)

    built = []
    manifest = {"ships": {}, "clouds": {}}
    for name, builder, pos in SHIP_LAYOUT:
        ship = builder()
        run_checks(name, ship)
        lo = [1e9] * 3
        hi = [-1e9] * 3
        groups = {}
        for gname, buf in ship.meshes.items():
            a, b = buf.bounds()
            lo = [min(lo[i], a[i]) for i in range(3)]
            hi = [max(hi[i], b[i]) for i in range(3)]
            groups[gname] = {"color": list(buf.color), "material": buf.material,
                             "min": [round(v, 3) for v in a], "max": [round(v, 3) for v in b]}
        manifest["ships"][name] = {"pos": list(pos), "min": [round(v, 3) for v in lo], "max": [round(v, 3) for v in hi],
                                   "groups": groups, "fbx": os.path.join(EXPORT, name + ".fbx").replace("\\", "/")}
        place(ship.model, pos)
        count = sum(1 for _ in ship.model.parts())
        if write_models:
            shell_parts(name, builder, pos)
        print("[worldgen] %s: %d parts, %d mesh groups" % (name, count, len(ship.meshes)))
        built.append((name, ship, pos))
    isle = island.build_island(ISLAND_CENTER)
    if write_models:
        write_model(isle, os.path.join(OUT, "BattleIsland.model.json"))

    try:
        import bpy  # noqa: F401
    except ImportError:
        print("[worldgen] not running inside Blender: skipped FBX export and previews")
        return
    import clouds
    import preview

    root = preview.reset_root(wipe_file=not live)
    prims = preview.unit_meshes()
    for name, ship, pos in built:
        coll = preview.new_collection(name, root)
        parts_coll = preview.new_collection(name + "_Parts", coll)
        preview.add_parts(ship.model, parts_coll, prims)
        objs = [preview.add_mesh("%s_%s" % (name, g), buf, coll, pos) for g, buf in ship.meshes.items()]
        preview.export_fbx(objs, os.path.join(EXPORT, name + ".fbx"))
    cloud_coll = preview.new_collection("Clouds", root)
    cloud_objs = []
    for i, (cname, seed) in enumerate(CLOUDS):
        obj = clouds.make_cloud(cname, seed, cloud_coll)
        obj.location = (-160 + i * 160, 520, 40)
        cloud_objs.append(obj)
        tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
        manifest["clouds"][cname] = {"tris": tris}
    preview.export_fbx(cloud_objs, os.path.join(EXPORT, "Clouds.fbx"))
    manifest["clouds_fbx"] = os.path.join(EXPORT, "Clouds.fbx").replace("\\", "/")
    with open(os.path.join(EXPORT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1)
    print("[worldgen] exported FBX files to", EXPORT)
    if not live:
        island_coll = preview.new_collection("BattleIsland", root)
        preview.add_parts(isle, island_coll, prims)
    if preview_dir:
        preview.render(preview_dir)


if __name__ == "__main__":
    main(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
