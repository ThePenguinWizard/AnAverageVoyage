"""Tiny helpers for building Roblox part models in Python and writing them as Rojo .model.json files.

Coordinates are Roblox studs: X right, Y up, Z back (a model's front faces -Z).
A rotation is a tuple of three column vectors (X, Y, Z): the part's Right, Up and Back axes in world space.
"""

import json
import math

# ---------------------------------------------------------------- vector math


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul(a, s):
    return (a[0] * s, a[1] * s, a[2] * s)


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def length(a):
    return math.sqrt(dot(a, a))


def norm(a):
    n = length(a)
    if n < 1e-9:
        return (0.0, 0.0, 0.0)
    return (a[0] / n, a[1] / n, a[2] / n)


def lerp(a, b, t):
    return a + (b - a) * t


def vlerp(a, b, t):
    return (lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t))


def mid(a, b):
    return vlerp(a, b, 0.5)


IDENT = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


def rot_apply(R, v):
    return add(add(mul(R[0], v[0]), mul(R[1], v[1])), mul(R[2], v[2]))


def rot_mul(A, B):
    """A * B: apply B in A's frame (like CFrame * CFrame)."""
    return (rot_apply(A, B[0]), rot_apply(A, B[1]), rot_apply(A, B[2]))


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return ((1.0, 0.0, 0.0), (0.0, c, s), (0.0, -s, c))


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return ((c, 0.0, -s), (0.0, 1.0, 0.0), (s, 0.0, c))


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return ((c, s, 0.0), (-s, c, 0.0), (0.0, 0.0, 1.0))


def frame_xy(xv, yv):
    """Orthonormal frame whose X follows xv and whose Y is as close to yv as possible."""
    X = norm(xv)
    Y = norm(sub(yv, mul(X, dot(yv, X))))
    if length(Y) < 1e-6:
        alt = (0.0, 0.0, 1.0) if abs(X[1]) > 0.9 else (0.0, 1.0, 0.0)
        Y = norm(sub(alt, mul(X, dot(alt, X))))
    Z = cross(X, Y)
    return (X, Y, Z)


def look_at(pos, target, up=(0.0, 1.0, 0.0)):
    """Same orientation as Roblox CFrame.lookAt(pos, target)."""
    back = norm(sub(pos, target))
    right = norm(cross(up, back))
    upv = cross(back, right)
    return (right, upv, back)


# ---------------------------------------------------------------- instances


def rgb(c):
    return [round(c[0] / 255.0, 4), round(c[1] / 255.0, 4), round(c[2] / 255.0, 4)]


class Inst:
    """A Roblox instance in a model tree. Parts carry size, position and rotation."""

    def __init__(self, class_name, name, props=None, attrs=None):
        self.class_name = class_name
        self.name = name
        self.props = dict(props or {})
        self.attrs = dict(attrs or {})
        self.children = []
        self._names = {}
        self.is_part = False
        self.size = None
        self.pos = None
        self.rot = None
        self.shape = None
        self.color = None

    def add(self, child):
        base = child.name
        count = self._names.get(base, 0)
        self._names[base] = count + 1
        if count:
            child.name = "%s%d" % (base, count + 1)
        self.children.append(child)
        return child

    def parts(self):
        if self.is_part:
            yield self
        for c in self.children:
            yield from c.parts()

    def to_json(self, root=False):
        d = {}
        if not root:
            d["name"] = self.name
        d["className"] = self.class_name
        props = dict(self.props)
        if self.is_part:
            props["Size"] = [round(v, 3) for v in self.size]
            X, Y, Z = self.rot
            p = self.pos
            props["CFrame"] = [round(p[0], 3), round(p[1], 3), round(p[2], 3),
                               round(X[0], 5), round(Y[0], 5), round(Z[0], 5),
                               round(X[1], 5), round(Y[1], 5), round(Z[1], 5),
                               round(X[2], 5), round(Y[2], 5), round(Z[2], 5)]
        if props:
            d["properties"] = props
        if self.attrs:
            d["attributes"] = self.attrs
        if self.children:
            d["children"] = [c.to_json() for c in self.children]
        return d


def Model(name, attrs=None):
    return Inst("Model", name, attrs=attrs)


def Part(name, size, pos, rot=IDENT, color=(200, 200, 200), material="SmoothPlastic",
         cls="Part", shape=None, collide=True, transparency=0.0, shadow=True, attrs=None):
    p = Inst(cls, name, attrs=attrs)
    p.is_part = True
    p.size = (max(size[0], 0.05), max(size[1], 0.05), max(size[2], 0.05))
    p.pos = pos
    p.rot = rot
    p.shape = shape
    p.color = color
    p.props["Anchored"] = True
    p.props["Color"] = rgb(color)
    p.props["Material"] = material
    p.props["TopSurface"] = "Smooth"
    p.props["BottomSurface"] = "Smooth"
    if shape:
        p.props["Shape"] = shape
    if not collide:
        p.props["CanCollide"] = False
    if not shadow:
        p.props["CastShadow"] = False
    if transparency > 0:
        p.props["Transparency"] = transparency
    return p


def Wedge(name, size, pos, rot=IDENT, **kw):
    """Roblox WedgePart: full back face (+Z), slope rising from the front-bottom edge to the back-top edge."""
    return Part(name, size, pos, rot, cls="WedgePart", **kw)


def light(color=(255, 196, 120), brightness=1.5, rng=16, shadows=False):
    return Inst("PointLight", "Light", props={
        "Color": rgb(color), "Brightness": brightness, "Range": rng, "Shadows": shadows})


def fire(size=3, heat=6):
    return Inst("Fire", "Fire", props={
        "Size": size, "Heat": heat, "Color": rgb((236, 139, 70)), "SecondaryColor": rgb((139, 80, 55))})


# ---------------------------------------------------------------- shape helpers

VERT = rot_z(math.pi / 2)  # turns a cylinder's X axis to point up


def vcyl(name, bottom, height, diameter, color, material="SmoothPlastic", **kw):
    """Vertical cylinder standing on `bottom`."""
    pos = (bottom[0], bottom[1] + height / 2.0, bottom[2])
    return Part(name, (height, diameter, diameter), pos, VERT, color, material, shape="Cylinder", **kw)


def disc(name, center, diameter, thickness, color, material="SmoothPlastic", **kw):
    """Flat horizontal disc centred on `center`."""
    return Part(name, (thickness, diameter, diameter), center, VERT, color, material, shape="Cylinder", **kw)


def ball(name, center, diameter, color, material="SmoothPlastic", **kw):
    return Part(name, (diameter, diameter, diameter), center, IDENT, color, material, shape="Ball", **kw)


def cyl_between(name, p0, p1, diameter, color, material="SmoothPlastic", **kw):
    d = sub(p1, p0)
    R = frame_xy(d, (0.0, 1.0, 0.0) if abs(norm(d)[1]) < 0.9 else (0.0, 0.0, 1.0))
    return Part(name, (length(d), diameter, diameter), mid(p0, p1), R, color, material, shape="Cylinder", **kw)


def box_between(name, p0, p1, width, height, color, material="SmoothPlastic", up=None, extra_len=0.0, **kw):
    """Box running from p0 to p1. `height` lies along `up` (default world up), `width` across."""
    d = sub(p1, p0)
    if up is None:
        up = (0.0, 1.0, 0.0) if abs(norm(d)[1]) < 0.9 else (0.0, 0.0, 1.0)
    R = frame_xy(d, up)
    return Part(name, (length(d) + extra_len, height, width), mid(p0, p1), R, color, material, **kw)


def quad_box(name, p0, p1, p2, p3, thickness, outward, color, material="SmoothPlastic",
             overlap=(0.3, 0.2), **kw):
    """Plank filling the quad p0-p1-p2-p3 (p0->p1 is the lower edge, p3->p2 the upper edge).

    The plank's outer face lies on the quad; its thickness grows away from `outward`.
    """
    a = mid(p0, p3)
    b = mid(p1, p2)
    lo = mid(p0, p1)
    up = mid(p3, p2)
    xv = sub(b, a)
    yv = sub(up, lo)
    X, Y, Z = frame_xy(xv, yv)
    lx = length(xv) + overlap[0]
    ly = abs(dot(yv, Y)) + overlap[1]
    c = mul(add(add(p0, p1), add(p2, p3)), 0.25)
    inward = Z if dot(Z, outward) < 0 else mul(Z, -1.0)
    center = add(c, mul(inward, thickness / 2.0))
    return Part(name, (lx, ly, thickness), center, (X, Y, Z), color, material, **kw)


def transform(inst, pos, rot=IDENT):
    for p in inst.parts():
        p.pos = add(pos, rot_apply(rot, p.pos))
        p.rot = rot_mul(rot, p.rot)
    return inst


def place(inst, pos, yaw=0.0):
    return transform(inst, pos, rot_y(yaw))


def write_model(inst, path):
    data = inst.to_json(root=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, separators=(",", ":"))
        f.write("\n")
    return sum(1 for _ in inst.parts())


# ---------------------------------------------------------------- triangle meshes (exported to FBX by Blender)


class MeshBuf:
    """A triangle/quad mesh in Roblox coordinates. Grids share vertices (smooth); separate calls stay sharp."""

    def __init__(self, color=(200, 200, 200), material="SmoothPlastic", smooth=True):
        self.verts = []
        self.faces = []
        self.color = color
        self.material = material
        self.smooth = smooth

    def _normal(self, idx):
        a, b, c = self.verts[idx[0]], self.verts[idx[1]], self.verts[idx[2]]
        return cross(sub(b, a), sub(c, a))

    def grid(self, rows, outward):
        """rows: equal-length lists of points. Faces are wound so their normals agree with `outward`."""
        base = len(self.verts)
        n = len(rows[0])
        for r in rows:
            self.verts.extend(r)
        faces = []
        for i in range(len(rows) - 1):
            for j in range(n - 1):
                a = base + i * n + j
                faces.append((a, a + 1, a + n + 1, a + n))
        flip = False
        for f in faces:
            nrm = self._normal(f)
            if length(nrm) > 1e-9:
                flip = dot(nrm, outward) < 0
                break
        for f in faces:
            self.faces.append(tuple(reversed(f)) if flip else f)

    def poly(self, pts, outward):
        base = len(self.verts)
        self.verts.extend(pts)
        f = tuple(range(base, base + len(pts)))
        if dot(self._normal(f), outward) < 0:
            f = tuple(reversed(f))
        self.faces.append(f)

    def tube(self, sections, closed_ring=True):
        """Loft through cross-sections (each a list of points around the profile). Faces point away from the axis."""
        n = len(sections[0])
        for k in range(n if closed_ring else n - 1):
            k2 = (k + 1) % n
            rows = [[s[k] for s in sections], [s[k2] for s in sections]]
            cen = mul(add(add(sections[0][k], sections[0][k2]), add(sections[1][k], sections[1][k2])), 0.25)
            mid_all = (0.0, 0.0, 0.0)
            for p in sections[0]:
                mid_all = add(mid_all, p)
            mid_all = mul(mid_all, 1.0 / n)
            self.grid(rows, sub(cen, mid_all))

    def bounds(self):
        xs = [v[0] for v in self.verts]
        ys = [v[1] for v in self.verts]
        zs = [v[2] for v in self.verts]
        return (min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs))


# ---------------------------------------------------------------- meshes as parts (two wedges per triangle)


def tri_wedges(name, a, b, c, thickness, outward, color, material="SmoothPlastic", **kw):
    """Two WedgeParts that exactly fill triangle abc. The slab grows away from `outward`."""
    ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
    abd, acd, bcd = dot(ab, ab), dot(ac, ac), dot(bc, bc)
    if abd > acd and abd > bcd:
        c, a = a, c
    elif acd > bcd and acd > abd:
        a, b = b, a
    ab, ac, bc = sub(b, a), sub(c, a), sub(c, b)
    n = cross(ac, ab)
    if length(n) < 1e-6:
        return []
    right = norm(n)
    up = norm(cross(bc, right))
    back = norm(bc)
    height = abs(dot(ab, up))
    if height < 0.02:
        return []
    inward = right if dot(right, outward) < 0 else mul(right, -1.0)
    off = mul(inward, thickness / 2.0)
    out = []
    d1, d2 = abs(dot(ab, back)), abs(dot(ac, back))
    if d1 > 0.02:
        out.append(Wedge(name, (thickness, height, d1), add(mid(a, b), off), (right, up, back),
                         color=color, material=material, **kw))
    if d2 > 0.02:
        out.append(Wedge(name, (thickness, height, d2), add(mid(a, c), off), (mul(right, -1.0), up, mul(back, -1.0)),
                         color=color, material=material, **kw))
    return out


def mesh_to_parts(buf, name, thickness, material="SmoothPlastic", **kw):
    """Turn a MeshBuf into a Model of wedge pairs (faces must be wound outward)."""
    m = Model(name)
    for f in buf.faces:
        pts = [buf.verts[i] for i in f]
        for k in range(1, len(pts) - 1):
            a, b, c = pts[0], pts[k], pts[k + 1]
            outward = cross(sub(b, a), sub(c, a))
            for w in tri_wedges(name, a, b, c, thickness, outward, buf.color, material, **kw):
                m.add(w)
    return m
