"""Furniture, ship stations and small props. Every builder works at the local origin with its front facing -Z;
use rbx.place() to put it in the world."""

import math

from rbx import (IDENT, VERT, Inst, Model, Part, Wedge, ball, box_between, cyl_between, disc, fire, light,
                 rot_x, rot_y, rot_z, vcyl)

WOOD = (150, 98, 58)
WOOD_ALT = (138, 88, 52)
WOOD_DARK = (96, 60, 36)
WOOD_LIGHT = (184, 134, 84)
PLANK = (164, 120, 74)
RAIL = (104, 66, 40)
SAIL = (244, 236, 214)
ROPE = (176, 146, 104)
IRON = (62, 62, 68)
IRON_DARK = (44, 44, 48)
GOLD = (214, 170, 62)
BLACK = (24, 24, 28)
WHITE = (240, 240, 236)
PARCHMENT = (226, 206, 160)
EMBER = (255, 122, 42)
LAMP = (255, 206, 120)
CLOTH_WHITE = (232, 230, 222)
STONE = (128, 124, 116)


def station(name, kind, **attrs):
    a = {"Station": kind}
    a.update(attrs)
    return Model(name, attrs=a)


# ---------------------------------------------------------------- small props


def barrel(name="Barrel"):
    m = Model(name)
    m.add(vcyl("Body", (0, 0, 0), 2.6, 2.1, (128, 84, 48), "Wood"))
    for y in (0.45, 2.0):
        m.add(vcyl("Band", (0, y, 0), 0.22, 2.18, IRON))
    m.add(disc("Lid", (0, 2.62, 0), 1.9, 0.06, (112, 72, 40), "Wood"))
    return m


def crate(name="Crate", size=2.6):
    m = Model(name)
    m.add(Part("Body", (size, size, size), (0, size / 2, 0), color=PLANK, material="WoodPlanks"))
    for sx in (-1, 1):
        m.add(Part("Edge", (0.25, size + 0.05, size + 0.05), (sx * (size / 2 - 0.1), size / 2, 0), color=WOOD_DARK, material="Wood"))
    return m


def lantern(name="Lantern", post_height=0.0, rng=16, brightness=1.4):
    """Lantern standing on a post (post_height > 0) or sitting where placed."""
    m = Model(name)
    y = 0.0
    if post_height > 0:
        m.add(Part("Post", (0.45, post_height, 0.45), (0, post_height / 2, 0), color=RAIL, material="Wood"))
        y = post_height
    m.add(Part("Cap", (1.0, 0.25, 1.0), (0, y + 1.45, 0), color=IRON))
    m.add(Part("Base", (1.0, 0.25, 1.0), (0, y + 0.12, 0), color=IRON))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(Part("Bar", (0.12, 1.2, 0.12), (sx * 0.44, y + 0.8, sz * 0.44), color=IRON))
    core = m.add(Part("Glow", (0.62, 0.95, 0.62), (0, y + 0.8, 0), color=LAMP, material="Neon", shadow=False))
    core.add(light(LAMP, brightness, rng))
    return m


def rope_coil(name="RopeCoil"):
    m = Model(name)
    m.add(disc("Coil", (0, 0.25, 0), 1.8, 0.5, ROPE, "Fabric"))
    m.add(disc("Coil2", (0, 0.6, 0), 1.5, 0.3, ROPE, "Fabric"))
    return m


# ---------------------------------------------------------------- stations


def chart_table():
    """Sea-chart table: where the crew gathers to vote on the next island."""
    m = station("ChartTable", "ChartTable")
    top = 3.3
    m.add(Part("Top", (6.6, 0.45, 4.6), (0, top - 0.22, 0), color=WOOD_DARK, material="Wood"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(Part("Leg", (0.6, top - 0.45, 0.6), (sx * 2.9, (top - 0.45) / 2, sz * 1.9), color=WOOD_DARK, material="Wood"))
    m.add(Part("Chart", (5.8, 0.08, 3.8), (0, top + 0.04, 0), color=PARCHMENT))
    # little islands drawn on the chart
    marks = [(-2.0, -1.0, (122, 168, 92)), (-0.3, 0.9, (196, 170, 112)), (1.4, -0.6, (122, 168, 92)), (2.2, 1.1, (150, 120, 92))]
    for i, (x, z, col) in enumerate(marks):
        m.add(disc("Isle", (x, top + 0.1, z), 0.7 + 0.15 * (i % 2), 0.05, col))
        if i:
            px, pz, _ = marks[i - 1]
            m.add(box_between("Route", (px, top + 0.1, pz), (x, top + 0.1, z), 0.08, 0.04, (150, 60, 50), shadow=False))
    # ship figurine on the chart
    fx, fz = -1.1, 0.0
    m.add(Part("FigHull", (0.45, 0.35, 1.2), (fx, top + 0.25, fz), color=(120, 80, 46), material="Wood"))
    m.add(Part("FigMast", (0.08, 0.9, 0.08), (fx, top + 0.85, fz), color=WOOD_DARK))
    m.add(Part("FigSail", (0.6, 0.45, 0.05), (fx, top + 0.9, fz - 0.05), color=SAIL, material="Fabric"))
    # brass compass and a candle
    m.add(disc("Compass", (2.4, top + 0.12, -1.4), 0.9, 0.18, GOLD, "Metal"))
    m.add(box_between("Needle", (2.4, top + 0.23, -1.75), (2.4, top + 0.23, -1.05), 0.08, 0.04, (190, 40, 40)))
    m.add(vcyl("Candle", (-2.5, top + 0.08, 1.5), 0.6, 0.3, (240, 232, 210)))
    flame = m.add(ball("Flame", (-2.5, top + 0.8, 1.5), 0.22, LAMP, "Neon", shadow=False, collide=False))
    flame.add(light(LAMP, 0.8, 8))
    return m


def stash_chest():
    m = station("StashChest", "Stash")
    m.add(Part("Body", (4.2, 2.0, 2.6), (0, 1.0, 0), color=(120, 78, 44), material="Wood"))
    m.add(Part("Lid", (4.3, 0.8, 2.7), (0, 2.4, 0), color=(104, 66, 38), material="Wood"))
    for x in (-1.6, 0.0, 1.6):
        m.add(Part("Band", (0.28, 2.9, 2.74), (x, 1.42, 0), color=IRON))
    m.add(Part("Lock", (0.6, 0.7, 0.25), (0, 1.9, -1.45), color=GOLD, material="Metal"))
    return m


def crew_chest(slot, paint):
    m = station("CrewChest%d" % slot, "CrewChest", Slot=slot)
    m.add(Part("Body", (2.6, 1.3, 1.6), (0, 0.65, 0), color=(128, 84, 48), material="Wood"))
    m.add(Part("Lid", (2.7, 0.5, 1.7), (0, 1.55, 0), color=paint, material="Wood"))
    m.add(Part("Band", (0.22, 1.85, 1.74), (0, 0.92, 0), color=IRON))
    m.add(Part("Tag", (0.7, 0.45, 0.08), (0.75, 0.75, -0.84), color=PARCHMENT))
    return m


def cook_brazier():
    """Tier 1 'campfire': an iron brazier with a pot on a tripod."""
    m = station("CookFire", "CookFire")
    m.add(Part("HearthStone", (4.0, 0.3, 4.0), (0, 0.15, 0), color=STONE, material="Slate"))
    for a in range(3):
        ang = a * 2 * math.pi / 3
        x, z = math.cos(ang) * 1.2, math.sin(ang) * 1.2
        m.add(Part("Leg", (0.25, 1.4, 0.25), (x, 1.0, z), color=IRON))
    m.add(vcyl("Bowl", (0, 1.6, 0), 0.7, 3.0, IRON))
    embers = m.add(disc("Embers", (0, 2.32, 0), 2.5, 0.12, EMBER, "Neon", shadow=False))
    embers.add(light((255, 160, 90), 2.0, 18))
    embers.add(fire(3, 5))
    top = (0, 5.2, 0)
    for a in range(3):
        ang = a * 2 * math.pi / 3 + 0.5
        foot = (math.cos(ang) * 2.0, 0.3, math.sin(ang) * 2.0)
        m.add(cyl_between("Tripod", foot, top, 0.18, IRON_DARK))
    m.add(cyl_between("Chain", (0, 5.2, 0), (0, 4.1, 0), 0.08, IRON_DARK))
    m.add(vcyl("Pot", (0, 3.0, 0), 1.1, 1.4, IRON_DARK))
    return m


def workbench():
    m = station("Workbench", "Workbench")
    m.add(Part("Top", (5.0, 0.5, 2.4), (0, 2.95, 0), color=WOOD_LIGHT, material="Wood"))
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(Part("Leg", (0.5, 2.7, 0.5), (sx * 2.2, 1.35, sz * 0.9), color=WOOD_DARK, material="Wood"))
    m.add(Part("Shelf", (4.6, 0.3, 2.0), (0, 0.8, 0), color=WOOD, material="Wood"))
    m.add(Part("Vise", (0.7, 0.7, 0.9), (1.9, 3.5, -0.6), color=IRON))
    m.add(Part("Saw", (2.2, 0.06, 0.6), (-0.8, 3.25, 0.3), rot_y(0.3), color=(170, 170, 176), material="Metal"))
    m.add(Part("Hammer", (0.2, 0.2, 1.2), (0.6, 3.3, -0.5), color=WOOD_DARK))
    m.add(Part("Planks", (3.2, 0.5, 1.2), (-0.5, 1.2, 0.1), color=PLANK, material="WoodPlanks"))
    return m


def ready_bell():
    m = station("ReadyBell", "ReadyBell", Label="Ready (x/6)")
    for sx in (-1, 1):
        m.add(Part("Post", (0.5, 6.2, 0.5), (sx * 1.6, 3.1, 0), color=RAIL, material="Wood"))
    m.add(Part("Beam", (3.8, 0.5, 0.6), (0, 6.2, 0), color=RAIL, material="Wood"))
    m.add(vcyl("Bell", (0, 4.2, 0), 1.5, 1.5, GOLD, "Metal"))
    m.add(vcyl("Lip", (0, 4.1, 0), 0.3, 1.85, GOLD, "Metal"))
    m.add(ball("Clapper", (0, 3.9, 0), 0.45, IRON_DARK))
    m.add(Part("Hanger", (0.3, 0.6, 0.3), (0, 5.9, 0), color=IRON))
    return m


def helm():
    m = station("Helm", "Helm")
    m.add(Part("Post", (0.9, 3.4, 0.9), (0, 1.7, 0.4), color=RAIL, material="Wood"))
    cz = -0.25
    hub_rot = rot_y(math.pi / 2)  # cylinder axis along Z
    m.add(Part("Hub", (0.7, 0.8, 0.8), (0, 3.8, cz), hub_rot, WOOD_DARK, "Wood", shape="Cylinder"))
    for k in range(4):
        m.add(Part("Spoke", (0.22, 5.0, 0.22), (0, 3.8, cz), rot_z(k * math.pi / 4), WOOD_LIGHT, "Wood"))
    r = 1.95
    seg = 2 * r * math.tan(math.pi / 8)
    for k in range(8):
        a = k * math.pi / 4
        pos = (math.cos(a) * r, 3.8 + math.sin(a) * r, cz)
        m.add(Part("Rim", (0.35, seg + 0.1, 0.35), pos, rot_z(a), WOOD, "Wood"))
    return m


def cannon():
    """Points along +X (outboard)."""
    m = station("Cannon", "Cannon")
    m.add(Part("Carriage", (2.8, 1.0, 2.2), (0, 0.95, 0), color=WOOD, material="Wood"))
    for sz in (-1, 1):
        m.add(Part("Cheek", (2.6, 1.2, 0.35), (0, 1.75, sz * 0.9), color=WOOD_DARK, material="Wood"))
    wheel_rot = rot_y(math.pi / 2)
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.add(Part("Wheel", (0.4, 1.1, 1.1), (sx * 1.0, 0.55, sz * 1.2), wheel_rot, WOOD_DARK, "Wood", shape="Cylinder"))
    m.add(Part("Barrel", (4.2, 1.05, 1.05), (0.9, 2.0, 0), color=IRON_DARK, material="Metal", shape="Cylinder"))
    m.add(Part("Muzzle", (0.35, 1.3, 1.3), (2.9, 2.0, 0), color=IRON_DARK, material="Metal", shape="Cylinder"))
    m.add(ball("Breech", (-1.3, 2.0, 0), 0.8, IRON_DARK, "Metal"))
    m.add(ball("Shot", (-0.6, 0.45, 1.6), 0.8, IRON_DARK, "Metal"))
    return m


def bed(blanket):
    m = Model("Cot")
    m.add(Part("Frame", (3.2, 1.2, 6.6), (0, 0.6, 0), color=WOOD, material="Wood"))
    m.add(Part("Mattress", (3.0, 0.5, 6.2), (0, 1.45, 0), color=CLOTH_WHITE, material="Fabric"))
    m.add(Part("Pillow", (2.3, 0.45, 1.1), (0, 1.9, 2.4), color=WHITE, material="Fabric"))
    m.add(Part("Blanket", (3.05, 0.16, 3.4), (0, 1.75, -1.1), color=blanket, material="Fabric"))
    return m


def medicine_cabinet():
    m = Model("MedicineCabinet")
    m.add(Part("Body", (3.2, 4.6, 1.2), (0, 2.3, 0), color=WOOD_LIGHT, material="Wood"))
    for y in (1.6, 2.9):
        m.add(Part("Shelf", (3.0, 0.15, 1.0), (0, y, -0.12), color=WOOD_DARK))
    cols = [(90, 160, 210), (200, 90, 80), (110, 190, 120), (230, 200, 90)]
    for i in range(4):
        m.add(vcyl("Bottle", (-1.1 + i * 0.72, 1.68, -0.25), 0.7, 0.4, cols[i], "Glass", transparency=0.15))
        m.add(vcyl("Jar", (-1.1 + i * 0.72, 2.98, -0.25), 0.55, 0.5, cols[(i + 2) % 4], "Glass", transparency=0.15))
    return m


def herb_sign():
    """Green cross sign for the infirmary door (not the protected red emblem)."""
    m = Model("InfirmarySign")
    m.add(Part("Board", (2.2, 2.2, 0.2), (0, 0, 0), color=CLOTH_WHITE))
    m.add(Part("CrossV", (0.6, 1.7, 0.25), (0, 0, -0.03), color=(60, 160, 90)))
    m.add(Part("CrossH", (1.7, 0.6, 0.25), (0, 0, -0.03), color=(60, 160, 90)))
    return m


def stove(chimney_height):
    m = Model("Stove")
    m.add(Part("Body", (3.2, 2.6, 2.6), (0, 1.3, 0), color=IRON_DARK, material="Metal"))
    m.add(Part("Top", (3.4, 0.25, 2.8), (0, 2.72, 0), color=IRON))
    door = m.add(Part("FireDoor", (1.4, 0.9, 0.12), (0, 1.0, -1.32), color=EMBER, material="Neon", shadow=False))
    door.add(light((255, 150, 80), 1.6, 14))
    m.add(vcyl("Chimney", (0.9, 2.8, 0.6), chimney_height, 0.8, IRON))
    m.add(vcyl("Pot", (-0.6, 2.85, -0.2), 1.0, 1.3, (70, 70, 76)))
    m.add(Part("Pan", (1.0, 0.15, 1.0), (0.5, 2.92, -0.6), color=(70, 70, 76)))
    return m


def long_table(length):
    m = Model("MessTable")
    m.add(Part("Top", (3.0, 0.45, length), (0, 2.9, 0), color=WOOD_LIGHT, material="Wood"))
    for sz in (-1, 1):
        m.add(Part("Leg", (2.4, 2.7, 0.5), (0, 1.35, sz * (length / 2 - 0.8)), color=WOOD_DARK, material="Wood"))
    for sx in (-1, 1):
        m.add(Part("Bench", (1.2, 0.45, length - 0.6), (sx * 2.4, 1.7, 0), color=WOOD, material="Wood"))
        for sz in (-1, 1):
            m.add(Part("BenchLeg", (1.0, 1.5, 0.4), (sx * 2.4, 0.75, sz * (length / 2 - 1.0)), color=WOOD_DARK, material="Wood"))
    for i, z in enumerate((-1.5, 0.4, 2.0)):
        m.add(vcyl("Mug", (0.6 * (-1) ** i, 3.12, z), 0.6, 0.45, (150, 110, 70), "Wood"))
    m.add(vcyl("Plate", (0, 3.12, -0.5), 0.1, 1.1, CLOTH_WHITE))
    m.add(ball("MeatOnBone", (0, 3.55, -0.5), 0.8, (150, 70, 50)))
    return m


def anvil():
    m = Model("Anvil")
    m.add(Part("Stump", (1.6, 1.8, 1.6), (0, 0.9, 0), color=WOOD_DARK, material="Wood"))
    m.add(Part("Waist", (0.8, 0.6, 0.9), (0, 2.1, 0), color=IRON_DARK, material="Metal"))
    m.add(Part("Face", (2.2, 0.55, 1.0), (0, 2.65, 0), color=IRON_DARK, material="Metal"))
    m.add(Wedge("Horn", (0.9, 0.55, 1.0), (-1.55, 2.65, 0), rot_y(math.pi / 2), color=IRON_DARK, material="Metal"))
    return m


def forge():
    m = Model("Forge")
    m.add(Part("Base", (3.4, 2.4, 2.8), (0, 1.2, 0), color=STONE, material="Cobblestone"))
    coals = m.add(Part("Coals", (2.6, 0.3, 2.0), (0, 2.5, 0), color=EMBER, material="Neon", shadow=False))
    coals.add(light((255, 140, 70), 2.0, 16))
    m.add(Part("Hood", (3.0, 0.4, 2.4), (0, 5.0, 0.1), color=IRON))
    m.add(vcyl("Flue", (0, 5.2, 0.3), 1.7, 1.0, IRON))
    return m


def tool_rack():
    m = Model("ToolRack")
    m.add(Part("Board", (4.0, 3.0, 0.3), (0, 3.0, 0), color=WOOD, material="Wood"))
    for i in range(5):
        x = -1.6 + i * 0.8
        m.add(Part("Tool", (0.18, 1.6, 0.18), (x, 3.0, -0.25), color=WOOD_DARK))
        m.add(Part("Head", (0.6, 0.3, 0.2), (x, 3.85, -0.25), color=(170, 170, 176), material="Metal"))
    return m


def recruit_board():
    m = station("RecruitBoard", "RecruitBoard")
    m.add(Part("Frame", (4.6, 3.4, 0.35), (0, 0, 0), color=WOOD_DARK, material="Wood"))
    m.add(Part("Cork", (4.1, 2.9, 0.4), (0, 0, 0), color=(176, 132, 84), material="Wood"))
    papers = [(-1.3, 0.6, 0.1), (0.1, 0.8, -0.08), (1.4, 0.5, 0.06), (-0.7, -0.7, 0.04), (0.9, -0.6, -0.1)]
    for x, y, a in papers:
        m.add(Part("Notice", (0.95, 1.2, 0.06), (x, y, -0.24), rot_z(a), PARCHMENT))
    m.add(Part("Sign", (2.2, 0.55, 0.12), (0, 1.95, -0.2), color=GOLD, material="Metal"))
    return m


def captains_desk():
    m = Model("CaptainsDesk")
    m.add(Part("Top", (5.0, 0.45, 2.6), (0, 3.0, 0), color=(90, 52, 30), material="Wood"))
    for sx in (-1, 1):
        m.add(Part("Drawers", (1.4, 2.8, 2.4), (sx * 1.7, 1.4, 0), color=(104, 62, 36), material="Wood"))
    m.add(Part("Log", (1.2, 0.2, 1.6), (-0.8, 3.33, 0), color=(120, 40, 40)))
    m.add(vcyl("Inkwell", (0.9, 3.22, -0.3), 0.35, 0.4, BLACK))
    m.add(Part("ChairSeat", (1.8, 0.4, 1.8), (0, 1.8, 2.2), color=(120, 40, 40), material="Fabric"))
    m.add(Part("ChairBack", (1.8, 2.4, 0.3), (0, 3.0, 3.0), color=(90, 52, 30), material="Wood"))
    return m


# ---------------------------------------------------------------- figureheads (facing -Z)


def seagull_head():
    m = Model("Figurehead")
    m.add(cyl_between("Neck", (0, -1.0, 1.2), (0, 0.2, 0.0), 1.3, WHITE, "Wood"))
    m.add(ball("Head", (0, 0.6, -0.4), 2.0, WHITE, "Wood"))
    m.add(Wedge("Beak", (0.7, 0.6, 1.6), (0, 0.45, -1.9), color=(240, 170, 60), material="Wood"))
    for sx in (-1, 1):
        m.add(ball("Eye", (sx * 0.85, 0.85, -0.85), 0.36, BLACK))
    return m


def turtle_head():
    m = Model("Figurehead")
    green = (96, 150, 96)
    m.add(cyl_between("Neck", (0, -1.2, 1.4), (0, 0.0, 0.0), 1.6, green, "Wood"))
    m.add(ball("Head", (0, 0.4, -0.6), 2.5, green, "Wood"))
    for sx in (-1, 1):
        m.add(ball("Eye", (sx * 0.95, 0.85, -1.35), 0.42, BLACK))
    m.add(Part("Smile", (1.2, 0.12, 0.1), (0, -0.05, -1.82), color=(60, 90, 60)))
    return m


def serpent_head():
    m = Model("Figurehead")
    teal = (44, 112, 124)
    m.add(cyl_between("Neck", (0, -1.8, 2.2), (0, 0.0, 0.2), 2.0, teal, "Wood"))
    m.add(Part("Skull", (2.4, 2.0, 3.0), (0, 0.6, -0.8), color=teal, material="Wood"))
    m.add(Wedge("Snout", (2.0, 1.2, 2.4), (0, 0.9, -3.4), color=teal, material="Wood"))
    m.add(Part("Jaw", (1.8, 0.6, 2.6), (0, -0.55, -2.4), color=(36, 92, 102), material="Wood"))
    for sx in (-1, 1):
        m.add(ball("Eye", (sx * 1.05, 1.2, -1.6), 0.45, (255, 60, 40), "Neon", shadow=False))
        m.add(Wedge("Horn", (0.4, 1.6, 1.4), (sx * 0.9, 2.1, 0.2), rot_x(0.5), color=GOLD, material="Metal"))
    return m


def anchor():
    m = Model("Anchor")
    m.add(Part("Shank", (0.5, 5.2, 0.5), (0, 0, 0), color=IRON_DARK, material="Metal"))
    m.add(Part("Stock", (3.0, 0.4, 0.4), (0, 2.0, 0), color=IRON_DARK, material="Metal"))
    m.add(Part("Ring", (0.3, 1.0, 1.0), (0, 2.9, 0), rot_y(math.pi / 2), IRON_DARK, "Metal", shape="Cylinder"))
    for sx in (-1, 1):
        m.add(Part("Arm", (2.0, 0.45, 0.45), (sx * 0.85, -2.25, 0), rot_z(sx * 0.6), IRON_DARK, "Metal"))
        m.add(Part("Fluke", (0.8, 0.8, 0.3), (sx * 1.7, -1.75, 0), rot_z(sx * 0.6), IRON_DARK, "Metal"))
    return m
