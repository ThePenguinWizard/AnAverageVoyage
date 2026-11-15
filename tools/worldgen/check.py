"""Overlap checks for generated ships: parts poking into other parts, and sails poking into parts."""

from rbx import add, cross, dot, length, mul, norm, sub

SKIP_OWNERS = {"Colliders", "Shell"}


def walk(inst, path=()):
    for c in inst.children:
        yield from walk(c, path + (c.name,))
    if inst.is_part:
        yield path, inst


def owner(path):
    if not path:
        return "?"
    if path[0] in ("Stations", "Props", "Rigging") and len(path) > 2:
        return path[0] + "/" + path[1]
    return path[0]


def penetration(a, b):
    """Depth by which two oriented boxes overlap (0 if they don't)."""
    d = sub(b.pos, a.pos)
    axes = list(a.rot) + list(b.rot)
    for i in range(3):
        for j in range(3):
            c = cross(a.rot[i], b.rot[j])
            if length(c) > 1e-6:
                axes.append(norm(c))
    best = 1e9
    for ax in axes:
        ra = sum(abs(dot(ax, a.rot[i])) * a.size[i] / 2 for i in range(3))
        rb = sum(abs(dot(ax, b.rot[i])) * b.size[i] / 2 for i in range(3))
        o = ra + rb - abs(dot(ax, d))
        if o <= 0:
            return 0.0
        best = min(best, o)
    return best


def part_overlaps(model, threshold=0.35, ignore=()):
    items = []
    for path, p in walk(model):
        o = owner(path)
        if o in SKIP_OWNERS or p.props.get("CanCollide") is False and o.startswith("Rigging"):
            continue
        items.append((o, path, p, length(p.size) / 2))
    worst = {}
    for i in range(len(items)):
        oa, pa, a, ra = items[i]
        for j in range(i + 1, len(items)):
            ob, pb, b, rb = items[j]
            if oa == ob:
                continue
            if length(sub(a.pos, b.pos)) > ra + rb:
                continue
            key = tuple(sorted((oa, ob)))
            if any(set(key) == set(ig) for ig in ignore):
                continue
            pen = penetration(a, b)
            if pen > threshold and pen > worst.get(key, (0,))[0]:
                worst[key] = (round(pen, 2), "/".join(pa), "/".join(pb))
    return sorted(((k, v) for k, v in worst.items()), key=lambda kv: -kv[1][0])


def verts_inside_parts(model, verts, margin=0.05, skip_owners=()):
    """Mesh vertices (ship-local) that sit inside any part. Returns {owner: count}."""
    hits = {}
    boxes = []
    for path, p in walk(model):
        o = owner(path)
        if o in SKIP_OWNERS or o in skip_owners:
            continue
        boxes.append((o, p, length(p.size) / 2))
    for v in verts:
        for o, p, r in boxes:
            d = sub(v, p.pos)
            if length(d) > r:
                continue
            if all(abs(dot(d, p.rot[i])) < p.size[i] / 2 - margin for i in range(3)):
                hits[o] = hits.get(o, 0) + 1
    return hits
