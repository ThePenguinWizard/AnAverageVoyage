"""Sample battle island: a beach ring, a grassy plateau, a combat arena with rank markers, palms, ruins and a dock."""

import math
import random

import props as P
from rbx import (Model, Part, Wedge, add, ball, box_between, cyl_between, disc, fire, lerp, light, look_at, mul,
                 place, rot_mul, rot_x, rot_y, rot_z, vcyl)

SAND = (232, 212, 162)
SAND_WET = (204, 184, 138)
GRASS = (104, 168, 72)
GRASS_DARK = (92, 154, 64)
ROCKS = [(128, 120, 108), (112, 106, 96), (142, 134, 120)]
DIRT = (170, 140, 100)
SEABED = (92, 84, 72)
RUIN = (198, 188, 166)
BASALT = (66, 68, 78)
GLYPH = (90, 224, 204)
CREW = (70, 140, 230)
ENEMY = (220, 74, 60)


def outline_radius(discs, ang, cx, cz):
    """Distance from (cx, cz) to the outer edge of a union of circles, along heading `ang` (0 = +Z)."""
    dx, dz = math.sin(ang), math.cos(ang)
    best = 0.0
    for x, z, r in discs:
        ox, oz = cx - x, cz - z
        b = ox * dx + oz * dz
        c = ox * ox + oz * oz - r * r
        d = b * b - c
        if d >= 0:
            best = max(best, -b + math.sqrt(d))
    return best


def inside(discs, x, z, margin=0.0):
    return any((x - dx) ** 2 + (z - dz) ** 2 <= (r - margin) ** 2 for dx, dz, r in discs)


def rock(rnd, name, size, pos, color=None):
    rot = rot_mul(rot_y(rnd.uniform(0, math.tau)), rot_mul(rot_x(rnd.uniform(-0.25, 0.25)), rot_z(rnd.uniform(-0.25, 0.25))))
    return Part(name, size, pos, rot, color or rnd.choice(ROCKS), "Rock")


def palm(rnd, height):
    m = Model("Palm")
    la = rnd.uniform(0, math.tau)
    lean = (math.sin(la), 0.0, math.cos(la))
    lean_max = rnd.uniform(0.25, 0.5)
    segs = 6
    seg = height / segs
    pts = [(0.0, -0.5, 0.0)]
    for k in range(segs):
        a = lean_max * ((k + 1) / segs) ** 1.4
        d = (lean[0] * math.sin(a), math.cos(a), lean[2] * math.sin(a))
        pts.append(add(pts[-1], mul(d, seg)))
    for k in range(segs):
        m.add(cyl_between("Trunk", pts[k], pts[k + 1], lerp(1.9, 1.1, k / (segs - 1)),
                          (142, 104, 70) if k % 2 == 0 else (126, 92, 60), "Wood"))
    top = pts[-1]
    for j in range(9):
        yaw = j * math.tau / 9 + rnd.uniform(-0.15, 0.15)
        droop = rnd.uniform(0.3, 0.65)
        L = rnd.uniform(8.0, 10.5)
        d = (math.sin(yaw) * math.cos(droop), -math.sin(droop), math.cos(yaw) * math.cos(droop))
        m.add(box_between("Frond", top, add(top, mul(d, L)), 2.0, 0.25, (64, 150, 66) if j % 2 == 0 else (80, 168, 76),
                          collide=False))
    for j in range(5):
        yaw = j * math.tau / 5 + 0.3
        rise = rnd.uniform(0.1, 0.45)
        L = rnd.uniform(5.0, 6.5)
        d = (math.sin(yaw) * math.cos(rise), math.sin(rise), math.cos(yaw) * math.cos(rise))
        m.add(box_between("Frond", top, add(top, mul(d, L)), 1.6, 0.25, (92, 178, 84), collide=False))
    for j in range(3):
        a = j * math.tau / 3
        m.add(ball("Coconut", add(top, (math.cos(a) * 0.8, -0.7, math.sin(a) * 0.8)), 0.9, (110, 76, 44)))
    return m


def build_island(center=(0.0, 0.0, -360.0), seed=11):
    rnd = random.Random(seed)
    cx, _, cz = center
    m = Model("BattleIsland", attrs={"IslandKind": "Battle", "Sea": 1})

    # ---------------------------------------------------------- ground
    ground = m.add(Model("Ground"))
    ground.add(vcyl("Seabed", (cx, -44.0, cz), 42.5, 360, SEABED, "Slate"))
    beach = [(cx, cz, 140.0)]
    for k in range(7):
        a = k * math.tau / 7 + rnd.uniform(-0.25, 0.25)
        d, r = rnd.uniform(78, 100), rnd.uniform(50, 68)
        beach.append((cx + math.sin(a) * d, cz + math.cos(a) * d, r))
    for i, (x, z, r) in enumerate(beach):
        top = 1.2 - 0.04 * i
        ground.add(vcyl("Shore", (x, -3.0, z), top + 2.4, 2 * r + 7, SAND_WET, "Sand"))
        ground.add(vcyl("Beach", (x, -3.0, z), top + 3.0, 2 * r, SAND, "Sand"))
    plateau = [(cx, cz - 6, 104.0)]
    for k in range(6):
        a = k * math.tau / 6 + 0.4 + rnd.uniform(-0.2, 0.2)
        d, r = rnd.uniform(50, 62), rnd.uniform(44, 56)
        plateau.append((cx + math.sin(a) * d, cz + math.cos(a) * d, r))
    for i, (x, z, r) in enumerate(plateau):
        ground.add(vcyl("Plateau", (x, -1.0, z), 7.0 - 0.03 * i, 2 * r, GRASS if i % 2 == 0 else GRASS_DARK, "Grass"))

    # cliffs ring the plateau, leaving the south path open
    cliffs = m.add(Model("Cliffs"))
    n = 60
    for k in range(n):
        a = k * math.tau / n + rnd.uniform(-0.03, 0.03)
        if abs(math.atan2(math.sin(a), math.cos(a))) < 0.11:
            continue
        r = outline_radius(plateau, a, cx, cz) - rnd.uniform(0.5, 2.5)
        sx, sy, sz = rnd.uniform(7, 13), rnd.uniform(6.5, 9.5), rnd.uniform(5, 9)
        pos = (cx + math.sin(a) * r, 6.0 - sy / 2 + rnd.uniform(0.4, 1.4), cz + math.cos(a) * r)
        cliffs.add(rock(rnd, "Cliff", (sx, sy, sz), pos))

    # ramp from the beach up to the plateau (south side, facing the anchored ships)
    rs = outline_radius(plateau, 0.0, cx, cz)
    rise = 4.8
    run = rise / math.tan(math.radians(18))
    ramp = m.add(Model("Path"))
    ramp.add(Wedge("Ramp", (12, rise, run), (cx, 1.2 + rise / 2, cz + rs - 1.5 + run / 2), rot_y(math.pi),
                   color=DIRT, material="Ground"))
    for sx in (-1, 1):
        for j in range(3):
            ramp.add(rock(rnd, "PathRock", (rnd.uniform(2.5, 4.5), rnd.uniform(2, 4), rnd.uniform(2.5, 4.5)),
                          (cx + sx * rnd.uniform(7.5, 9.5), 1.2 + j * 1.6, cz + rs + j * 4.0)))

    # ---------------------------------------------------------- arena
    arena = m.add(Model("BattleArena", attrs={"Arena": True, "Formation": "2 ranks x 3 slots"}))
    acx, acz, ay = cx, cz - 14.0, 6.0
    arena.add(disc("ArenaFloor", (acx, ay + 0.15, acz), 94, 0.3, DIRT, "Ground"))
    for k in range(28):
        a = k * math.tau / 28 + rnd.uniform(-0.04, 0.04)
        s = rnd.uniform(1.8, 3.2)
        arena.add(rock(rnd, "RingStone", (s, s * 0.8, s), (acx + math.sin(a) * 47.5, ay + 0.6, acz + math.cos(a) * 47.5)))
    # Each side stands in two columns of three: rank 1 is the front line (nearest the middle), rank 2 the back
    # line. Slot 1 is nearest the camera, slot 3 the farthest.
    for side, sign, col in (("Crew", -1, CREW), ("Enemy", 1, ENEMY)):
        for rank in (1, 2):
            for slot in (1, 2, 3):
                x = acx + sign * (-1.0 + rank * 11.0)
                z = acz + (2 - slot) * 10.0
                arena.add(disc("%sR%dS%d" % (side, rank, slot), (x, ay + 0.36, z), 4.4, 0.12, col, collide=False,
                               transparency=0.35, shadow=False,
                               attrs={"BattleSlot": True, "Side": side, "Rank": rank, "Slot": slot}))
    # Low and close, looking down the aisle between the two sides, so each side's lines lean in toward the
    # middle ("/ \"). It tips up a little so the fighters sit in the lower half of the screen and the battle
    # card at the top doesn't cover them. CombatController uses a
    # 66 degree field of view with it.
    cam = (acx, ay + 13.0, acz + 34.0)
    arena.add(Part("BattleCamera", (1, 1, 1), cam, look_at(cam, (acx, ay + 9.5, acz - 7.0)), collide=False,
                   transparency=1, shadow=False, attrs={"CameraAnchor": True}))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        x, z = acx + math.sin(a) * 51, acz + math.cos(a) * 51
        arena.add(Part("TorchPost", (0.7, 5.5, 0.7), (x, ay + 2.75, z), color=P.RAIL, material="Wood"))
        arena.add(vcyl("TorchBowl", (x, ay + 5.5, z), 0.7, 1.6, P.IRON))
        flame = arena.add(disc("TorchEmbers", (x, ay + 6.25, z), 1.2, 0.15, P.EMBER, "Neon", shadow=False))
        flame.add(light((255, 160, 90), 1.6, 22))
        flame.add(fire(2.5, 7))

    # ---------------------------------------------------------- ruins with a waystone (puzzle site)
    ruins = m.add(Model("Ruins", attrs={"PuzzleSite": True}))
    rcx, rcz = cx + 4.0, cz - 86.0
    ruins.add(disc("RuinFloor", (rcx, ay + 0.15, rcz), 36, 0.3, (172, 164, 148), "Cobblestone"))
    heights = [11.0, 8.5, 5.0, 10.0, 3.5, 7.5]
    for k, ht in enumerate(heights):
        a = math.pi * 0.55 + k * math.pi * 0.18
        x, z = rcx + math.sin(a) * 14, rcz + math.cos(a) * 14
        ruins.add(Part("Plinth", (4.4, 1.0, 4.4), (x, ay + 0.5, z), color=RUIN, material="Limestone"))
        ruins.add(vcyl("Pillar", (x, ay + 1.0, z), ht, 3.2, RUIN, "Limestone"))
        if ht > 7:
            ruins.add(Part("Capital", (4.2, 0.9, 4.2), (x, ay + 1.0 + ht + 0.45, z), color=RUIN, material="Limestone"))
    ruins.add(cyl_between("FallenPillar", (rcx - 10, ay + 1.6, rcz + 3), (rcx + 1, ay + 1.6, rcz + 9), 3.0, RUIN,
                          "Limestone"))
    stone = ruins.add(Model("Waystone", attrs={"Waystone": True}))
    stone.add(Part("Slab", (3.6, 8.0, 1.4), (rcx, ay + 4.0, rcz), color=BASALT, material="Basalt"))
    stone.add(Part("Base", (5.0, 1.0, 2.6), (rcx, ay + 0.5, rcz), color=BASALT, material="Basalt"))
    zf = rcz + 0.72
    glyphs = [(-1.0, 6.4, 0.9, 0.18), (0.2, 6.4, 0.18, 0.9), (1.0, 6.1, 0.6, 0.18), (-0.9, 4.9, 0.18, 1.1),
              (0.1, 4.6, 1.0, 0.18), (1.0, 4.9, 0.18, 0.7), (-0.6, 3.2, 0.7, 0.18), (0.6, 3.0, 0.18, 0.9),
              (-1.0, 1.9, 0.18, 0.6), (0.3, 1.8, 1.1, 0.18)]
    for gx, gy, w, hgt in glyphs:
        stone.add(Part("Glyph", (w, hgt, 0.1), (rcx + gx, ay + gy, zf), color=GLYPH, material="Neon", shadow=False))
    glow = stone.add(Part("GlyphLight", (0.2, 0.2, 0.2), (rcx, ay + 4.0, zf + 0.6), collide=False, transparency=1,
                          shadow=False))
    glow.add(light(GLYPH, 1.0, 14))

    # ---------------------------------------------------------- vegetation and rocks
    flora = m.add(Model("Flora"))
    placed = 0
    tries = 0
    while placed < 12 and tries < 600:
        tries += 1
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(20, 105)
        x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
        if not inside(plateau, x, z, 10):
            continue
        if math.hypot(x - acx, z - acz) < 57 or math.hypot(x - rcx, z - rcz) < 22:
            continue
        if abs(x - cx) < 12 and z > cz + 60:
            continue
        if abs(x - acx) < 50 and z > acz + 30:
            continue  # keep the battle camera's view of the arena clear
        flora.add(place(palm(rnd, rnd.uniform(16, 24)), (x, ay, z)))
        placed += 1
    placed = 0
    tries = 0
    while placed < 6 and tries < 600:
        tries += 1
        a = rnd.uniform(0, math.tau)
        r = rnd.uniform(110, 175)
        x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
        if not inside(beach, x, z, 14) or inside(plateau, x, z, -10):
            continue
        if abs(x - cx - 24) < 12 and z > cz:
            continue
        flora.add(place(palm(rnd, rnd.uniform(14, 20)), (x, 1.0, z)))
        placed += 1
    for k in range(22):
        for _ in range(100):
            a = rnd.uniform(0, math.tau)
            r = rnd.uniform(30, 170)
            x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
            on_plateau = inside(plateau, x, z, 6)
            if not inside(beach, x, z, 8):
                continue
            if on_plateau and (math.hypot(x - acx, z - acz) < 52 or math.hypot(x - rcx, z - rcz) < 20):
                continue
            if abs(x - cx) < 10 and z > cz + 55:
                continue
            if abs(x - cx - 24) < 10 and z > cz:
                continue
            s = rnd.uniform(1.5, 5.0)
            y = (ay if on_plateau else 1.1) + s * 0.25
            flora.add(rock(rnd, "Boulder", (s, s * 0.75, s * 1.1), (x, y, z)))
            break

    # ---------------------------------------------------------- dock (south, toward the ships)
    dock = m.add(Model("Dock", attrs={"Mooring": True}))
    dx = cx + 24.0
    z_edge = max(z + math.sqrt(r * r - (dx - x) ** 2) for x, z, r in beach if abs(dx - x) < r)
    z0, z1 = z_edge - 10.0, z_edge + 44.0
    dy = 2.4
    z = z0
    k = 0
    while z < z1:
        dock.add(Part("Plank", (9.0, 0.45, 1.4), (dx, dy - 0.22, z), color=(176, 134, 88) if k % 2 else (164, 122, 78),
                      material="WoodPlanks"))
        z += 1.5
        k += 1
    for sx in (-1, 1):
        dock.add(Part("Stringer", (0.8, 0.8, z1 - z0), (dx + sx * 3.2, dy - 0.85, (z0 + z1) / 2), color=P.WOOD_DARK,
                      material="Wood"))
        zz = z0 + 4
        while zz < z1:
            dock.add(vcyl("Piling", (dx + sx * 4.4, -10.0, zz), 13.4, 1.3, (110, 80, 54), "Wood"))
            zz += 6
        dock.add(vcyl("Bollard", (dx + sx * 3.4, dy, z1 - 1.2), 1.4, 1.1, P.WOOD_DARK, "Wood"))
    dock.add(place(P.lantern(post_height=4.5, rng=18), (dx + 3.6, dy, z1 - 3.5)))
    dock.add(place(P.crate(), (dx - 2.4, dy, z0 + 12), 0.2))
    dock.add(place(P.crate(size=2.0), (dx - 2.2, dy + 2.6, z0 + 12), 0.6))
    dock.add(place(P.barrel(), (dx + 2.6, dy, z0 + 15)))
    dock.add(place(P.rope_coil(), (dx + 2.4, dy, z1 - 6)))
    return m
