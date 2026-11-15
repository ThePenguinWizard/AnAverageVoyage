"""The three crew ship tiers (Sloop, Brigantine, Galleon), built from Roblox parts.

Each ship is built bow-forward along -Z with the waterline at Y = 0. The AAC-style camp (stash, crew chests,
cooking, crafting, ready bell, sea chart) lives on the ship as physical stations; higher tiers add more of them.
Stations carry a "Station" attribute so game code can find them.
"""

import math

import props as P
from rbx import (IDENT, Inst, MeshBuf, Model, Part, Wedge, add, sub, ball, box_between, cyl_between, disc, light, lerp, mul,
                 place, quad_box, rot_x, rot_y, vcyl)

TH = 0.8  # hull plank thickness
COARSE = False  # True: low-detail shell meant to be turned into wedge parts instead of FBX meshes
DECK_A = (198, 160, 112)
DECK_B = (186, 148, 102)
SUBDECK = (74, 50, 34)
BELOW = (84, 56, 38)


class Hull:
    """Parametric hull surface. t runs stern (0) to bow (1); s runs keel (0) to gunwale (1)."""

    def __init__(self, L, B, keel_y, top_y, sheer_stern, sheer_bow, nseg, nstrakes=6):
        self.L, self.B = L, B
        self.keel_y, self.top_y = keel_y, top_y
        self.sheer_stern, self.sheer_bow = sheer_stern, sheer_bow
        self.nseg, self.ns = nseg, nstrakes
        self.ts = [i / nseg for i in range(nseg + 1)]
        self.ss = [j / nstrakes for j in range(nstrakes + 1)]

    def f(self, t):  # plan-view width profile, 1 = full beam
        if t < 0.4:
            return 0.80 + 0.20 * math.sin(math.pi / 2 * t / 0.4)
        u = (t - 0.4) / 0.6
        return max(0.035, math.cos(math.pi / 2 * u ** 1.15) ** 0.7)

    def w(self, s):  # cross-section: narrow at the keel, full at the gunwale
        s = max(0.0, min(1.0, s))
        return 0.30 + 0.70 * s ** 0.55

    def sheer(self, t):
        return self.sheer_stern * max(0.0, 1 - t / 0.5) ** 2 + self.sheer_bow * max(0.0, (t - 0.5) / 0.5) ** 2

    def top(self, t):
        return self.top_y + self.sheer(t)

    def y(self, t, s):
        return self.keel_y + s * (self.top(t) - self.keel_y)

    def z(self, t, s):
        s = max(0.0, min(1.0, s))
        zs = self.L / 2 - (1 - s) * self.L * 0.035
        zb = -self.L / 2 + (1 - s) * self.L * 0.09
        return zs + (zb - zs) * t

    def x(self, t, s):
        return self.B / 2 * self.f(t) * self.w(s)

    def P(self, t, s, side):
        return (side * self.x(t, s), self.y(t, s), self.z(t, s))

    def s_at(self, t, y):
        return (y - self.keel_y) / (self.top(t) - self.keel_y)

    def half_width_at(self, t, y):
        return self.x(t, min(self.s_at(t, y), 1.0))

    def z_at(self, t, y):
        return self.z(t, min(self.s_at(t, y), 1.0))

    def t_of_z(self, z):
        return max(0.0, min(1.0, (self.L / 2 - z) / self.L))


class ShipBuilder:
    def __init__(self, name, tier, L, B, keel_y, top_y, deck_y, sheer_stern, sheer_bow, nseg,
                 paint, trim, sail_stripe):
        self.h = Hull(L, B, keel_y, top_y, sheer_stern, sheer_bow, nseg)
        self.name = name
        self.deck_y = deck_y
        self.paint = paint
        self.trim = trim
        self.sail_stripe = sail_stripe
        self.castles = []
        self.bow_top = self.h.top(1.0)
        self.model = Model(name, attrs={"ShipTier": tier, "ShipClass": name, "CrewCapacity": 6})
        self.g_hull = self.model.add(Model("Hull"))
        self.g_deck = self.model.add(Model("Decks"))
        self.g_rig = self.model.add(Model("Rigging"))
        self.g_st = self.model.add(Model("Stations"))
        self.g_props = self.model.add(Model("Props"))
        self.g_col = self.model.add(Model("Colliders"))
        self.meshes = {}
        self.coarse = COARSE
        nt = nseg if self.coarse else nseg * max(2, round(56 / nseg))
        self.tt = [i / nt for i in range(nt + 1)]
        self.g_shell = self.model.add(Model("Shell"))

    # ------------------------------------------------------------ helpers

    def deck_pos(self, t, x=0.0, y=None):
        y = self.deck_y if y is None else y
        return (x, y, self.h.z_at(t, y))

    def inner_x(self, t, inset=0.0, y=None):
        y = self.deck_y if y is None else y
        return self.h.half_width_at(t, y) - TH - inset

    def put(self, group, model, pos, yaw=0.0):
        place(model, pos, yaw)
        group.add(model)
        return model

    def in_castle(self, t0, t1):
        return any(t0 >= a - 1e-6 and t1 <= b + 1e-6 for a, b in self.castles)

    def strake_color(self, j, y_mid):
        ns = self.h.ns
        if j == ns - 1:
            return P.WOOD_DARK
        if j == ns - 2:
            return self.paint
        if y_mid < -0.3:
            return BELOW
        return P.WOOD if j % 2 == 0 else P.WOOD_ALT

    # ------------------------------------------------------------ meshes

    def mesh(self, name, color=None, material="Wood", smooth=True):
        if name not in self.meshes:
            self.meshes[name] = MeshBuf(color or P.WOOD, material, smooth)
        return self.meshes[name]

    def strip(self, name, color, pts, side, o_in, o_out, y_lo, y_hi):
        """Rectangular bar following hull points `pts` (given for the starboard side)."""
        if self.coarse:
            ym, xm = (y_lo + y_hi) / 2, (o_in + o_out) / 2
            for (x0, y0, z0), (x1, y1, z1) in zip(pts, pts[1:]):
                self.g_shell.add(box_between(name, (side * max(0.03, x0 + xm), y0 + ym, z0),
                                             (side * max(0.03, x1 + xm), y1 + ym, z1), o_out - o_in, y_hi - y_lo,
                                             color, "Wood", extra_len=0.3))
            return
        sections = []
        for x, y, z in pts:
            xo, xi = side * max(0.03, x + o_out), side * max(0.03, x + o_in)
            sections.append([(xo, y + y_lo, z), (xo, y + y_hi, z), (xi, y + y_hi, z), (xi, y + y_lo, z)])
        self.mesh(name, color, smooth=False).tube(sections)

    def castle_t(self, t):
        return any(a + 1e-6 < t < b - 1e-6 for a, b in self.castles)

    def rows_s(self, a, b):
        n = (2 if a == 0.0 else 1) if self.coarse else 3
        return [a + (b - a) * k / n for k in range(n + 1)]

    def collider(self, p0, p1, p2, p3, outward):
        if self.coarse:
            return
        self.g_col.add(quad_box("Collider", p0, p1, p2, p3, TH, outward, P.WOOD, transparency=1, shadow=False))

    # ------------------------------------------------------------ hull

    def build_hull(self):
        h, g, tt = self.h, self.g_hull, self.tt
        ns = h.ns
        sw = (-0.3 - h.keel_y) / (h.top_y - h.keel_y)
        sp0, sp1 = (ns - 2) / ns, (ns - 1) / ns
        bands = [("HullBelow", BELOW, 0.0, sw), ("HullWood", P.WOOD, sw, sp0),
                 ("HullPaint", self.paint, sp0, sp1), ("HullTop", P.WOOD_DARK, sp1, 1.0)]
        inner = self.mesh("HullInner", P.WOOD_ALT)

        def s_deck(t):
            return max(0.0, min(1.0, h.s_at(t, self.deck_y - 0.6)))

        for side in (1, -1):
            for name, col, a, b in bands:
                ss = self.rows_s(a, b)
                self.mesh(name, col).grid([[h.P(t, s, side) for t in tt] for s in ss], (side, 0, 0))
            rows = []
            ni = 1 if self.coarse else 3
            for k in range(ni + 1):
                row = []
                for t in tt:
                    s0 = s_deck(t)
                    p = h.P(t, s0 + (1 - s0) * k / ni, 1)
                    row.append((side * max(0.03, p[0] - TH), p[1], p[2]))
                rows.append(row)
            inner.grid(rows, (-side, 0, 0))
            self.strip("Wale", self.trim, [h.P(t, sp0, 1) for t in tt], side, -0.1, 0.3, -0.3, 0.3)
            run = []
            for t in tt + [None]:
                if t is not None and not self.castle_t(t):
                    run.append(h.P(t, 1.0, 1))
                else:
                    if len(run) > 1:
                        self.strip("Rail", P.RAIL, run, side, -TH - 0.35, 0.3, 0.0, 0.6)
                    run = []
            # invisible collision walls (the meshes themselves don't collide)
            for j in range(3):
                for i in range(h.nseg):
                    t0, t1 = h.ts[i], h.ts[i + 1]
                    self.collider(h.P(t0, j / 3, side), h.P(t1, j / 3, side), h.P(t1, (j + 1) / 3, side),
                                  h.P(t0, (j + 1) / 3, side), (side, 0, 0))
        # transom (flat stern) and bottom
        for name, col, a, b in bands:
            ss = self.rows_s(a, b)
            self.mesh(name, col).grid([[h.P(0, s, -1), h.P(0, s, 1)] for s in ss], (0, 0, 1))
        s0 = s_deck(0)
        rows = []
        ni = 1 if self.coarse else 3
        for k in range(ni + 1):
            s = s0 + (1 - s0) * k / ni
            x, y, z = h.x(0, s) - TH, h.y(0, s), h.z(0, s) - TH
            rows.append([(-x, y, z), (x, y, z)])
        inner.grid(rows, (0, 0, -1))
        self.mesh("HullBelow", BELOW).grid([[h.P(t, 0, -1) for t in tt], [h.P(t, 0, 1) for t in tt]], (0, -1, 0))
        for j in range(3):
            self.collider(h.P(0, j / 3, -1), h.P(0, j / 3, 1), h.P(0, (j + 1) / 3, 1), h.P(0, (j + 1) / 3, -1), (0, 0, 1))
        for i in range(h.nseg):
            t0, t1 = h.ts[i], h.ts[i + 1]
            self.collider(h.P(t0, 0, -1), h.P(t0, 0, 1), h.P(t1, 0, 1), h.P(t1, 0, -1), (0, -1, 0))
        g.add(box_between("Keel", (0, h.keel_y - 0.6, h.z(0, 0)), (0, h.keel_y - 0.6, h.z(1, 0)), 1.2, 1.4,
                          P.WOOD_DARK, "Wood"))
        stem_top = self.bow_top + 0.8
        g.add(box_between("Stem", (0, h.keel_y - 0.6, h.z(1, 0)), (0, stem_top, h.z(1, 1) - 0.3), 1.3, 1.5,
                          P.WOOD_DARK, "Wood"))
        if not self.castle_t(h.ts[1] / 2):
            xs, zt, yt = h.x(0, 1), h.z(0, 1), h.top(0)
            g.add(box_between("Rail", (-xs, yt + 0.3, zt - 0.35), (xs, yt + 0.3, zt - 0.35), 1.3, 0.6, P.RAIL, "Wood",
                              extra_len=0.6))

    # ------------------------------------------------------------ decks

    def deck_planks(self, g, y, t_a, t_b, name="Deck", lane=1.6, th=0.5):
        h = self.h
        samples = 300
        ts = [t_a + (t_b - t_a) * k / samples for k in range(samples + 1)]
        hw = [h.half_width_at(t, y) - TH - 0.05 for t in ts]
        zs = [h.z_at(t, y) for t in ts]
        m = g.add(Model(name))
        n = int(2 * max(hw) / lane) + 1
        x0 = -(n - 1) * lane / 2
        for k in range(n):
            xk = x0 + k * lane
            need = abs(xk) + lane / 2
            runs, start = [], None
            for idx, wv in enumerate(hw):
                if wv >= need:
                    if start is None:
                        start = idx
                elif start is not None:
                    runs.append((start, idx - 1))
                    start = None
            if start is not None:
                runs.append((start, samples))
            for a, b in runs:
                if b <= a:
                    continue
                za, zb = zs[a], zs[b]
                col = DECK_A if k % 2 == 0 else DECK_B
                m.add(Part("Plank", (lane - 0.06, th, abs(za - zb)), (xk, y - th / 2, (za + zb) / 2),
                           color=col, material="WoodPlanks"))
        for k0 in range(0, samples, 10):
            k1 = min(samples, k0 + 10)
            wmin = 2 * min(hw[k0:k1 + 1])
            if wmin > 0.6:
                m.add(Part("SubDeck", (wmin, 0.4, abs(zs[k0] - zs[k1]) + 0.05),
                           (0, y - th - 0.2, (zs[k0] + zs[k1]) / 2), color=SUBDECK, material="Wood"))
        return m

    def main_deck(self):
        self.deck_planks(self.g_deck, self.deck_y, 0.0, 1.0, "MainDeck")

    # ------------------------------------------------------------ castles

    def bulkhead(self, g, t_e, y0, y1, zc, door, door_h, color, door_w=5.0):
        """Castle front wall, built in horizontal bands so it follows the hull's flare instead of poking through it."""
        h = self.h
        edges = {round(y0, 4), round(y1, 4)}
        y = y0 + 1.5
        while y < y1 - 0.2:
            edges.add(round(y, 4))
            y += 1.5
        if door:
            edges.add(round(y0 + door_h, 4))
        edges = sorted(edges)
        for a, b in zip(edges, edges[1:]):
            hw = h.half_width_at(t_e, a) - TH - 0.05
            cy, hgt = (a + b) / 2, b - a
            if door and b <= y0 + door_h + 1e-6:
                seg = hw - door_w / 2
                for sx in (-1, 1):
                    g.add(Part("Bulkhead", (seg, hgt, TH), (sx * (door_w / 2 + seg / 2), cy, zc), color=color,
                               material="WoodPlanks"))
            else:
                g.add(Part("Bulkhead", (2 * hw, hgt, TH), (0, cy, zc), color=color, material="WoodPlanks"))
        if not door:
            return
        for sx in (-1, 1):
            g.add(Part("DoorFrame", (0.4, door_h, TH + 0.3), (sx * (door_w / 2 + 0.2), y0 + door_h / 2, zc),
                       color=P.RAIL, material="Wood"))
        g.add(Part("DoorLintel", (door_w + 1.2, 0.5, TH + 0.3), (0, y0 + door_h + 0.25, zc), color=P.RAIL,
                   material="Wood"))

    def edge_rail(self, g, y, z, x0, x1, gaps, color):
        def in_gap(x):
            return any(a < x < b for a, b in gaps)

        xs = []
        n = max(1, int((x1 - x0) / 2.2))
        for i in range(n + 1):
            x = x0 + (x1 - x0) * i / n
            if not in_gap(x):
                xs.append(x)
        for a, b in gaps:
            if x0 < a < x1:
                xs.append(a)
            if x0 < b < x1:
                xs.append(b)
        xs = sorted(set(round(x, 3) for x in xs))
        for x in xs:
            g.add(Part("RailPost", (0.45, 3.0, 0.45), (x, y + 1.5, z), color=color, material="Wood"))
        for a, b in zip(xs, xs[1:]):
            if in_gap((a + b) / 2):
                continue
            g.add(Part("RailTop", (b - a + 0.45, 0.45, 0.6), ((a + b) / 2, y + 3.0, z), color=color, material="Wood"))
            g.add(Part("RailMid", (b - a, 0.3, 0.3), ((a + b) / 2, y + 1.5, z), color=color, material="Wood"))

    def stairs(self, g, x, z_edge, y0, y1, width, toward):
        """Steps from the deck (y0) up to a castle deck (y1); they run away from the bulkhead along `toward` (+-1 in z)."""
        n = max(1, int(math.ceil((y1 - y0) / 1.0)))
        rise = (y1 - y0) / n
        run = 1.3
        for k in range(1, n + 1):
            d = (n - k + 0.5) * run
            g.add(Part("Step", (width, k * rise, run), (x, y0 + k * rise / 2, z_edge + toward * d),
                       color=DECK_A if k % 2 else DECK_B, material="WoodPlanks"))
        return n * run

    def castle(self, name, t_a, t_b, height, at_stern, wall_color=None, cap_color=None, door=True):
        h = self.h
        n = h.nseg
        t_a, t_b = round(t_a * n) / n, round(t_b * n) / n
        y_c = self.deck_y + height
        wall_top = y_c + 3.0
        self.castles.append((t_a, t_b))
        if not at_stern:
            self.bow_top = max(self.bow_top, wall_top)
        g = self.model.add(Model(name))
        wc = wall_color or P.WOOD_ALT
        cc = cap_color or P.RAIL
        t_e = t_b if at_stern else t_a
        inward = 1.0 if at_stern else -1.0
        wname = "HullPaint" if wc == self.paint else "CastleWall"
        tts = [t for t in self.tt if t_a - 1e-6 <= t <= t_b + 1e-6]
        inner = self.mesh("HullInner", P.WOOD_ALT)
        for side in (1, -1):
            outer = [h.P(t, 1.0, 1) for t in tts]
            self.mesh(wname, wc).grid([[(side * p[0], p[1], p[2]) for p in outer],
                                       [(side * p[0], wall_top, p[2]) for p in outer]], (side, 0, 0))
            inner.grid([[(side * max(0.03, p[0] - TH), p[1], p[2]) for p in outer],
                        [(side * max(0.03, p[0] - TH), wall_top, p[2]) for p in outer]], (-side, 0, 0))
            self.strip("CastleCap", cc, [(p[0], wall_top, p[2]) for p in outer], side, -TH - 0.35, 0.3, 0.0, 0.6)
            pe = h.P(t_e, 1.0, 1)
            self.mesh(wname, wc).poly([(side * pe[0], pe[1], pe[2]), (side * pe[0], wall_top + 0.6, pe[2]),
                                       (side * (pe[0] - TH), wall_top + 0.6, pe[2]), (side * (pe[0] - TH), pe[1], pe[2])],
                                      (0, 0, -inward))
            for i in range(n):
                t0, t1 = h.ts[i], h.ts[i + 1]
                if t0 < t_a - 1e-6 or t1 > t_b + 1e-6:
                    continue
                p0, p1 = h.P(t0, 1.0, side), h.P(t1, 1.0, side)
                self.collider(p0, p1, (p1[0], wall_top, p1[2]), (p0[0], wall_top, p0[2]), (side, 0, 0))
        if at_stern:
            xs, zt, yt = h.x(0, 1), h.z(0, 1), h.top(0)
            self.mesh(wname, wc).grid([[(-xs, yt, zt), (xs, yt, zt)], [(-xs, wall_top, zt), (xs, wall_top, zt)]], (0, 0, 1))
            inner.grid([[(-xs + TH, yt, zt - TH), (xs - TH, yt, zt - TH)],
                        [(-xs + TH, wall_top, zt - TH), (xs - TH, wall_top, zt - TH)]], (0, 0, -1))
            self.collider((-xs, yt, zt), (xs, yt, zt), (xs, wall_top, zt), (-xs, wall_top, zt), (0, 0, 1))
            g.add(box_between("Cap", (-xs, wall_top + 0.3, zt - 0.35), (xs, wall_top + 0.3, zt - 0.35), 1.4, 0.6, cc,
                              "Wood", extra_len=0.7))
        self.deck_planks(g, y_c, t_a, t_b, name + "Deck")
        z_e = h.z(t_e, 1.0)
        door_h = min(7.5, height - 0.9)
        self.bulkhead(g, t_e, self.deck_y, y_c, z_e + inward * TH / 2, door and door_h >= 6.5, door_h, wc)
        hw_deck = self.inner_x(t_e, 0.1)
        stair_x = hw_deck - 2.0
        hw_c = h.half_width_at(t_e, y_c) - TH - 0.1
        gaps = [(-stair_x - 1.9, -stair_x + 1.9), (stair_x - 1.9, stair_x + 1.9)]
        self.edge_rail(g, y_c, z_e + inward * 0.3, -hw_c, hw_c, gaps, cc)
        run = 0.0
        for sx in (-1, 1):
            run = self.stairs(g, sx * stair_x, z_e, self.deck_y, y_c, 3.6, -inward)
        return {"y": y_c, "z_edge": z_e, "inward": inward, "t_a": t_a, "t_b": t_b, "stair_x": stair_x,
                "stair_run": run, "wall_top": wall_top, "group": g}

    # ------------------------------------------------------------ rigging

    def sail(self, g, width, ytop, ybot, ztop, bulge, stripe):
        """Billowing square sail as a two-sided mesh; `stripe` adds a painted band."""
        nu = 4 if self.coarse else 8
        hw = width / 2

        def pt(u, v, off):
            b = bulge * (math.sin(math.pi * v ** 0.85) ** 0.9) * (1 - 0.55 * (2 * u - 1) ** 2) + bulge * 0.25 * v
            return (-hw + width * u, lerp(ytop, ybot, v), ztop - b + off)

        spans = [(0.0, 0.6, "Sail"), (0.6, 0.8, "SailStripe"), (0.8, 1.0, "Sail")] if stripe else [(0.0, 1.0, "Sail")]
        for v0, v1, name in spans:
            nv = max(1, int(round((v1 - v0) * 5))) if self.coarse else max(2, int(round((v1 - v0) * 10)))
            col = self.paint if name == "SailStripe" else P.SAIL
            m = self.mesh(name, col, "Fabric")
            for off, out in ((0.0, (0, 0, -1)), (0.2, (0, 0, 1)))[:1 if self.coarse else 2]:
                m.grid([[pt(i / nu, lerp(v0, v1, k / nv), off) for i in range(nu + 1)] for k in range(nv + 1)], out)

    def jib(self, tack, clew, head, bulge=2.0):
        n = 4 if self.coarse else 8
        m = self.mesh("Sail", P.SAIL, "Fabric")

        def pt(i, j, off):
            a, b = j / n, i / n
            p = add(tack, add(mul(sub(clew, tack), a), mul(sub(head, tack), b)))
            return (p[0] + bulge * 27 * a * b * (1 - a - b) + off, p[1], p[2])

        for off, out in ((0.0, (-1, 0, 0)), (0.2, (1, 0, 0)))[:1 if self.coarse else 2]:
            for i in range(n):
                for j in range(n - i):
                    m.poly([pt(i, j, off), pt(i, j + 1, off), pt(i + 1, j, off)], out)
                    if j < n - i - 1:
                        m.poly([pt(i, j + 1, off), pt(i + 1, j + 1, off), pt(i + 1, j, off)], out)

    def jolly_roger(self, g, x, y, z):
        g.add(vcyl("FlagPole", (x, y, z), 4.4, 0.3, P.RAIL, "Wood"))
        fy, fz = y + 2.8, z + 3.9
        g.add(Part("Flag", (0.2, 4.6, 7.2), (x, fy, fz), IDENT, P.BLACK, "Fabric", collide=False))
        g.add(Part("Skull", (0.34, 2.2, 2.2), (x, fy + 0.4, fz), IDENT, P.WHITE, shape="Cylinder", collide=False))
        for dz in (-0.45, 0.45):
            g.add(Part("EyeHole", (0.46, 0.55, 0.55), (x, fy + 0.55, fz + dz), IDENT, P.BLACK, shape="Cylinder",
                       collide=False))
        g.add(Part("Jaw", (0.34, 0.7, 1.2), (x, fy - 0.75, fz), IDENT, P.WHITE, collide=False))
        for a in (0.62, -0.62):
            g.add(Part("Bone", (0.26, 0.45, 5.4), (x, fy, fz), rot_x(a), P.WHITE, collide=False))

    def crows_nest(self, g, z, y):
        st = g.add(Model("CrowsNest", attrs={"Station": "CrowsNest"}))
        zc = z + 2.0
        x0, x1, z0, z1 = -3.4, 3.4, zc - 3.0, zc + 3.0
        hole = (-1.15, 1.15, z + 1.15, z + 3.35)
        zrow = z0 + 0.6
        while zrow < z1 - 0.1:
            if zrow + 0.6 > hole[2] and zrow - 0.6 < hole[3]:
                for a, b in ((x0, hole[0]), (hole[1], x1)):
                    st.add(Part("Floor", (b - a, 0.5, 1.2), ((a + b) / 2, y - 0.25, zrow), color=DECK_B,
                                material="WoodPlanks"))
            else:
                st.add(Part("Floor", (x1 - x0, 0.5, 1.2), (0, y - 0.25, zrow), color=DECK_B, material="WoodPlanks"))
            zrow += 1.2
        for x, zz in ((x0, z0), (x1, z0), (x0, z1), (x1, z1), (0, z0), (0, z1), (x0, zc), (x1, zc)):
            st.add(Part("Post", (0.45, 3.0, 0.45), (x, y + 1.5, zz), color=P.RAIL, material="Wood"))
        for a, b in (((x0, z0), (x1, z0)), ((x0, z1), (x1, z1)), ((x0, z0), (x0, z1)), ((x1, z0), (x1, z1))):
            for yy, th in ((y + 3.0, 0.45), (y + 1.5, 0.3)):
                st.add(box_between("Rail", (a[0], yy, a[1]), (b[0], yy, b[1]), th, th, P.RAIL, "Wood", extra_len=0.45))
        ladder_h = int(math.ceil((y - self.deck_y + 1.0) / 2.0)) * 2
        st.add(Part("Ladder", (2, ladder_h, 2), (0, self.deck_y + ladder_h / 2, z + 2.25), color=P.WOOD_DARK,
                    material="Wood", cls="TrussPart"))

    def mast(self, label, t, height, dia, yards, flag=False, nest_frac=None):
        h = self.h
        y0 = self.deck_y
        z = h.z_at(t, y0)
        g = self.g_rig.add(Model(label))
        g.add(vcyl("Mast", (0, y0 - 0.5, z), height + 0.5, dia, P.WOOD_DARK, "Wood"))
        g.add(vcyl("Collar", (0, y0, z), 0.8, dia + 0.7, P.RAIL, "Wood"))
        top = y0 + height
        g.add(vcyl("Cap", (0, top, z), 0.6, dia + 0.4, P.RAIL, "Wood"))
        for frac, ylen, drop, stripe in yards:
            yy = y0 + frac * height
            zy = z - dia / 2 - 0.45
            g.add(Part("Yard", (ylen, 0.8, 0.8), (0, yy, zy), IDENT, P.WOOD_DARK, "Wood", shape="Cylinder"))
            for sx in (-1, 1):
                g.add(cyl_between("Lift", (0, yy + (top - yy) * 0.35, z), (sx * ylen / 2 * 0.95, yy, zy), 0.16,
                                  P.ROPE, collide=False, shadow=False))
            ybot = y0 + drop * height
            self.sail(g, ylen * 0.9, yy - 0.35, ybot, zy - 0.55, max(1.5, (yy - ybot) * 0.16),
                      stripe and self.sail_stripe)
        sh_top = y0 + 0.72 * height
        for side in (1, -1):
            for off in (1.5, 3.5, 5.5):
                zr = z + off
                tr = h.t_of_z(zr)
                xr = h.x(tr, 1.0) - 0.4
                yr = h.top(tr) + 0.5
                g.add(cyl_between("Shroud", (side * dia * 0.4, sh_top, z), (side * xr, yr, zr), 0.2, P.ROPE,
                                  collide=False, shadow=False))
        if flag:
            self.jolly_roger(g, 0, top + 0.6, z)
        if nest_frac:
            self.crows_nest(g, z, y0 + nest_frac * height)
        return {"z": z, "top": top, "group": g}

    def bowsprit_and_jib(self, fore, length):
        h = self.h
        start = (0, self.bow_top + 0.3, h.z(1, 1) + 2.5)
        ang = math.radians(16)
        tip = add(start, mul((0, math.sin(ang), -math.cos(ang)), length))
        g = self.g_rig.add(Model("Bowsprit"))
        g.add(cyl_between("Bowsprit", start, tip, 1.3, P.WOOD_DARK, "Wood"))
        g.add(cyl_between("Forestay", (0, fore["top"], fore["z"]), tip, 0.2, P.ROPE, collide=False, shadow=False))
        yb = tip[1] + 0.8
        zf = tip[2] + 1.0
        zk = fore["z"] - 11.0
        head = fore["top"] * 0.48 + yb * 0.52
        self.jib((0, yb, zf), (0, yb + 0.8, zk), (0, head, zk))
        return tip

    def stay(self, a, b):
        self.g_rig.add(cyl_between("Stay", (0, a["top"], a["z"]), (0, b["top"] * 0.78 + self.deck_y * 0.22, b["z"]),
                                   0.2, P.ROPE, collide=False, shadow=False))

    # ------------------------------------------------------------ dressing

    def figurehead(self, model):
        h = self.h
        self.put(self.g_hull, model, (0, self.bow_top - 1.2, h.z(1, 1) - 1.2))

    def anchors(self):
        h = self.h
        for side in (1, -1):
            t, s = 0.84, 0.8
            pos = (side * (h.x(t, s) + 0.7), h.y(t, s) - 1.0, h.z(t, s))
            self.put(self.g_hull, P.anchor(), pos, math.pi / 2)

    def deckhouse(self, name, kind, W, D, H, wall_color):
        m = Model(name, attrs={"Station": kind}) if kind else Model(name)
        th = TH
        m.add(Part("Wall", (W, H, th), (0, H / 2, D / 2 - th / 2), color=wall_color, material="WoodPlanks"))
        for sx in (-1, 1):
            m.add(Part("Wall", (th, H, D - 2 * th), (sx * (W / 2 - th / 2), H / 2, 0), color=wall_color,
                       material="WoodPlanks"))
            m.add(Part("Window", (th + 0.14, 2.0, 3.0), (sx * (W / 2 - th / 2), H * 0.62, 0), color=(170, 206, 226),
                       material="Glass", transparency=0.35))
        door_w, door_h = 5.0, 7.5
        seg = (W - door_w) / 2
        for sx in (-1, 1):
            m.add(Part("Wall", (seg, H, th), (sx * (door_w / 2 + seg / 2), H / 2, -(D / 2 - th / 2)), color=wall_color,
                       material="WoodPlanks"))
            m.add(Part("DoorFrame", (0.4, door_h, th + 0.3), (sx * (door_w / 2 + 0.2), door_h / 2, -(D / 2 - th / 2)),
                       color=P.RAIL, material="Wood"))
        m.add(Part("Header", (door_w, H - door_h, th), (0, door_h + (H - door_h) / 2, -(D / 2 - th / 2)),
                   color=wall_color, material="WoodPlanks"))
        m.add(Part("Lintel", (door_w + 1.2, 0.5, th + 0.3), (0, door_h + 0.25, -(D / 2 - th / 2)), color=P.RAIL,
                   material="Wood"))
        for sx in (-1, 1):
            for sz in (-1, 1):
                m.add(Part("CornerPost", (0.9, H + 0.2, 0.9), (sx * (W / 2 - 0.2), H / 2, sz * (D / 2 - 0.2)),
                           color=P.RAIL, material="Wood"))
        m.add(Part("Roof", (W + 1.4, 0.6, D + 1.4), (0, H + 0.3, 0), color=P.WOOD_DARK, material="WoodPlanks"))
        m.add(Part("RoofTrim", (W + 1.6, 0.35, 0.4), (0, H + 0.6, -(D / 2 + 0.6)), color=self.paint, material="Wood"))
        return m

    def lantern_on(self, pos, group=None, post=0.0, rng=16, brightness=1.4):
        return self.put(group or self.g_props, P.lantern(post_height=post, rng=rng, brightness=brightness), pos)

    def spawn(self, pos):
        s = Part("CrewSpawn", (5, 1, 5), pos, color=DECK_A, cls="SpawnLocation", collide=False, transparency=1,
                 shadow=False)
        s.props["Neutral"] = True
        s.props["Duration"] = 0
        self.model.add(s)


# ================================================================ tier 1: sloop


def build_sloop():
    s = ShipBuilder("Sloop", 1, L=56, B=18, keel_y=-5, top_y=5.6, deck_y=2.6, sheer_stern=1.0, sheer_bow=2.2,
                    nseg=14, paint=(40, 140, 148), trim=(214, 190, 120), sail_stripe=True)
    h = s.h
    qd = s.castle("Quarterdeck", 0.0, 3 / 14, 4.0, at_stern=True)
    s.build_hull()
    s.main_deck()

    mast = s.mast("Mast", 0.56, 44, 2.0, [(0.47, 21, 0.23, True), (0.78, 15, 0.51, False)], flag=True)
    s.bowsprit_and_jib(mast, 14)
    s.figurehead(P.seagull_head())
    s.anchors()

    st = s.g_st
    s.put(st, P.helm(), s.deck_pos(0.07, 0, qd["y"]), 0)
    s.put(st, P.chart_table(), s.deck_pos(0.155, 0, qd["y"]), 0)
    s.put(st, P.stash_chest(), s.deck_pos(0.37), 0)
    for i, t in enumerate((0.33, 0.39, 0.45)):
        x = s.inner_x(t, 0.9)
        s.put(st, P.crew_chest(i * 2 + 1, s.paint), s.deck_pos(t, x), math.pi / 2)
        s.put(st, P.crew_chest(i * 2 + 2, s.paint), s.deck_pos(t, -x), -math.pi / 2)
    s.put(st, P.ready_bell(), s.deck_pos(0.505, -3.9), 0)
    s.put(st, P.cook_brazier(), s.deck_pos(0.71), 0)
    s.put(st, P.workbench(), s.deck_pos(0.635, s.inner_x(0.635, 1.3)), math.pi / 2)

    pr = s.g_props
    s.put(pr, P.barrel(), s.deck_pos(0.83, 2.2))
    s.put(pr, P.barrel(), s.deck_pos(0.80, -2.6))
    s.put(pr, P.crate(), s.deck_pos(0.835, -0.6), 0.3)
    s.put(pr, P.rope_coil(), s.deck_pos(0.62, -3.5))
    s.lantern_on((0, qd["wall_top"] + 0.6, h.z(0, 1) - 0.4))
    s.lantern_on(s.deck_pos(0.505, 3.6), post=5.0)
    return s


# ================================================================ tier 2: brigantine


def build_brigantine():
    s = ShipBuilder("Brigantine", 2, L=86, B=26, keel_y=-7, top_y=6.6, deck_y=3.0, sheer_stern=1.4,
                    sheer_bow=2.8, nseg=20, paint=(168, 46, 42), trim=(222, 184, 92), sail_stripe=True)
    h = s.h
    qd = s.castle("Quarterdeck", 0.0, 0.2, 8.0, at_stern=True, wall_color=s.paint)
    s.build_hull()
    s.main_deck()

    main = s.mast("MainMast", 0.42, 54, 2.4,
                  [(0.50, 28, 0.24, True), (0.74, 21, 0.53, False), (0.93, 14, 0.77, False)], flag=True)
    fore = s.mast("ForeMast", 0.70, 46, 2.2, [(0.46, 24, 0.21, True), (0.74, 18, 0.49, False)])
    s.stay(main, fore)
    s.bowsprit_and_jib(fore, 18)
    s.figurehead(P.turtle_head())
    s.anchors()

    st = s.g_st
    # quarterdeck: helm and sea chart
    s.put(st, P.helm(), s.deck_pos(0.045, 0, qd["y"]), 0)
    s.put(st, P.chart_table(), s.deck_pos(0.13, 0, qd["y"]), 0)

    # cabin under the quarterdeck is the infirmary
    inf = st.add(Model("Infirmary", attrs={"Station": "Infirmary"}))
    zb = qd["z_edge"]
    for z_off, side in ((4.5, -1), (12.0, -1), (5.0, 1)):
        t = h.t_of_z(zb + z_off)
        s.put(inf, P.bed((90, 150, 110)), s.deck_pos(t, side * s.inner_x(t, 1.8)), 0)
    t = h.t_of_z(zb + 12.0)
    s.put(inf, P.medicine_cabinet(), s.deck_pos(t, s.inner_x(t, 0.7)), math.pi / 2)
    s.put(inf, P.herb_sign(), (0, s.deck_y + 8.0 - 0.1, zb - 0.25))
    s.lantern_on((0, s.deck_y + 5.4, zb + 8.0), group=inf)

    # galley deckhouse between the masts, door facing aft
    W, D, H = 12.0, 11.0, 9.5
    gal = s.deckhouse("Galley", "Galley", W, D, H, (190, 140, 92))
    s.put(gal, P.stove(H - 2.8 + 2.4), (0, 0, D / 2 - TH - 1.6), 0)
    s.put(gal, P.long_table(5.0), (0, 0, -0.6), 0)
    s.put(gal, P.barrel(), (-W / 2 + 1.9, 0, D / 2 - 2.0))
    s.lantern_on((0, H - 2.2, -2.0), group=gal)
    s.put(st, gal, s.deck_pos(0.56), math.pi)

    # main deck stations
    s.put(st, P.stash_chest(), s.deck_pos(0.37), 0)
    s.put(st, P.ready_bell(), s.deck_pos(0.40, 4.6), 0)
    for i, t in enumerate((0.415, 0.45, 0.485)):
        x = s.inner_x(t, 0.9)
        s.put(st, P.crew_chest(i * 2 + 1, s.paint), s.deck_pos(t, x), math.pi / 2)
        s.put(st, P.crew_chest(i * 2 + 2, s.paint), s.deck_pos(t, -x), -math.pi / 2)
    s.put(st, P.workbench(), s.deck_pos(0.655, s.inner_x(0.655, 1.3)), math.pi / 2)
    for t in (0.355, 0.78):
        for side in (1, -1):
            x = s.inner_x(t, 3.2)
            s.put(st, P.cannon(), s.deck_pos(t, side * x), 0 if side > 0 else math.pi)

    pr = s.g_props
    for t, x in ((0.86, 2.5), (0.83, -2.8), (0.88, -0.5)):
        s.put(pr, P.barrel(), s.deck_pos(t, x))
    s.put(pr, P.crate(), s.deck_pos(0.675, -s.inner_x(0.675, 2.2)), 0.2)
    s.put(pr, P.rope_coil(), s.deck_pos(0.72, 3.5))
    s.lantern_on((0, qd["wall_top"] + 0.6, h.z(0, 1) - 0.4))
    for sx in (-1, 1):
        s.lantern_on((sx * (h.x(0, 1) - 0.6), qd["wall_top"] + 0.6, h.z(0, 1) - 0.4), rng=12, brightness=1.0)
    return s


# ================================================================ tier 3: galleon


def build_galleon():
    s = ShipBuilder("Galleon", 3, L=124, B=36, keel_y=-9, top_y=7.8, deck_y=3.6, sheer_stern=2.0,
                    sheer_bow=3.6, nseg=26, paint=(40, 70, 150), trim=P.GOLD, sail_stripe=True)
    h = s.h
    qd = s.castle("Quarterdeck", 0.0, 5 / 26, 9.0, at_stern=True, wall_color=s.paint, cap_color=P.GOLD)
    fc = s.castle("Forecastle", 22 / 26, 1.0, 8.0, at_stern=False, wall_color=s.paint, cap_color=P.GOLD)
    s.build_hull()
    s.main_deck()

    mizzen = s.mast("MizzenMast", 0.27, 48, 2.4, [(0.52, 24, 0.28, False), (0.80, 17, 0.55, False)])
    main = s.mast("MainMast", 0.50, 66, 3.0,
                  [(0.42, 36, 0.20, True), (0.66, 28, 0.45, False), (0.87, 19, 0.69, False)],
                  flag=True, nest_frac=0.47)
    fore = s.mast("ForeMast", 0.74, 56, 2.6, [(0.44, 30, 0.19, True), (0.70, 23, 0.47, False)])
    s.stay(mizzen, main)
    s.stay(main, fore)
    s.bowsprit_and_jib(fore, 22)
    s.figurehead(P.serpent_head())
    s.anchors()

    st = s.g_st
    # quarterdeck: helm and sea chart
    s.put(st, P.helm(), s.deck_pos(0.05, 0, qd["y"]), 0)
    s.put(st, P.chart_table(), s.deck_pos(0.14, 0, qd["y"]), 0)

    # captain's cabin under the quarterdeck: desk at the stern, crew chests along both walls
    zb = qd["z_edge"]
    cab = st.add(Model("CaptainsCabin"))
    t = h.t_of_z(h.z(0, 1) - 4.5)
    s.put(cab, P.captains_desk(), s.deck_pos(t), 0)
    for i, z_off in enumerate((3.5, 7.0, 10.5)):
        t = h.t_of_z(zb + z_off)
        x = s.inner_x(t, 0.9)
        s.put(cab, P.crew_chest(i * 2 + 1, s.paint), s.deck_pos(t, x), math.pi / 2)
        s.put(cab, P.crew_chest(i * 2 + 2, s.paint), s.deck_pos(t, -x), -math.pi / 2)
    s.lantern_on((0, s.deck_y + 6.2, zb + 9.0), group=cab)
    s.put(st, P.recruit_board(), (-5.6, s.deck_y + 4.6, zb - 0.3), 0)
    # stern windows
    wy = s.deck_y + 4.4
    wz = h.z(0, min(1.0, h.s_at(0, wy))) + 0.05
    for x in (-9.0, -3.0, 3.0, 9.0):
        s.g_hull.add(Part("SternWindow", (3.0, 2.6, 0.5), (x, wy, wz), color=(255, 214, 140),
                          material="Glass", transparency=0.25))

    # galley (aft of the main mast, door forward) and infirmary (forward of it, door aft)
    W, D, H = 12.0, 14.0, 9.5
    gal = s.deckhouse("Galley", "Galley", W, D, H, (200, 168, 120))
    s.put(gal, P.stove(H - 2.8 + 2.4), (0, 0, D / 2 - TH - 1.6), 0)
    s.put(gal, P.long_table(6.5), (0, 0, -1.2), 0)
    s.put(gal, P.barrel(), (-W / 2 + 1.9, 0, D / 2 - 2.0))
    s.put(gal, P.barrel(), (W / 2 - 1.9, 0, D / 2 - 2.0))
    s.lantern_on((0, H - 2.2, -3.0), group=gal)
    s.put(st, gal, s.deck_pos(0.385), 0)

    inf = s.deckhouse("Infirmary", "Infirmary", W, D, H, (214, 206, 186))
    for sx in (-1, 1):
        s.put(inf, P.bed((70, 110, 170)), (sx * (W / 2 - TH - 1.8), 0, 1.4), 0)
    s.put(inf, P.medicine_cabinet(), (0, 0, D / 2 - TH - 0.7), 0)
    s.put(inf, P.herb_sign(), (0, 8.5, -(D / 2) - 0.15))
    s.lantern_on((0, H - 2.2, 0), group=inf)
    s.put(st, inf, s.deck_pos(0.62), math.pi)

    # workshop inside the forecastle
    ws = st.add(Model("Workshop", attrs={"Station": "Workshop"}))
    zf = fc["z_edge"]
    s.put(ws, P.forge(), (0, s.deck_y, zf - 7.5), 0)
    s.put(ws, P.anvil(), (-3.2, s.deck_y, zf - 3.6), 0.3)
    s.put(ws, P.workbench(), (s.inner_x(h.t_of_z(zf - 4.5), 1.3), s.deck_y, zf - 4.5), math.pi / 2)
    s.put(ws, P.tool_rack(), (-4.2, s.deck_y, zf - 1.0), 0)
    s.lantern_on((0, s.deck_y + 5.6, zf - 3.0), group=ws)

    # main deck
    zm = main["z"]
    s.put(st, P.stash_chest(), (-4.2, s.deck_y, zm + 4.6), 0)
    s.put(st, P.ready_bell(), (4.4, s.deck_y, zm + 4.6), 0)
    for t in (0.33, 0.43, 0.57, 0.67):
        for side in (1, -1):
            x = s.inner_x(t, 3.2)
            s.put(st, P.cannon(), s.deck_pos(t, side * x), 0 if side > 0 else math.pi)
    s.spawn((-9.0, s.deck_y + 0.5, zm - 2.0))

    pr = s.g_props
    for t, sx in ((0.715, 1), (0.692, 1), (0.24, 0)):
        s.put(pr, P.barrel(), s.deck_pos(t, sx * s.inner_x(t, 1.7) if sx else -7.0))
    s.put(pr, P.crate(), s.deck_pos(0.71, -s.inner_x(0.71, 2.2)), 0.4)
    s.put(pr, P.crate(), s.deck_pos(0.243, 7.5), -0.2)
    s.put(pr, P.rope_coil(), s.deck_pos(0.47, 7.0))
    for sx in (-1, 0, 1):
        s.lantern_on((sx * (h.x(0, 1) - 1.0) * 0.8, qd["wall_top"] + 0.6, h.z(0, 1) - 0.4), rng=14, brightness=1.2)
    s.lantern_on((5.0, s.deck_y, zb - 1.6), post=5.5)
    return s
