"""Big soft cumulus clouds for the horizon, built in Blender as heaps of overlapping puffs.

Vertex colours carry the shading (bright tops, dusky undersides); in Roblox the MeshPart colour tints them per sea.
Each cloud is built about 100 units wide and scaled up when placed.
"""

import random

import bmesh
import bpy
from mathutils import Matrix, Vector

# rows of puffs from the base up: (count, half-width fraction, radius, height of centres)
LAYERS = ((7, 0.86, 13.0, 9.0), (6, 0.66, 14.5, 20.0), (5, 0.46, 14.0, 32.0), (3, 0.26, 12.5, 43.0), (2, 0.1, 10.0, 52.0))


def make_cloud(name, seed, coll, width=100.0):
    rnd = random.Random(seed)
    half = width / 2
    bm = bmesh.new()
    for layer, (count, spread, rad, zc) in enumerate(LAYERS):
        for i in range(count):
            # spread the puffs evenly across the row, then jitter them
            u = (i + 0.5) / count * 2 - 1
            x = (u + rnd.uniform(-0.12, 0.12)) * half * spread
            y = rnd.uniform(-1, 1) * 6.0
            z = zc + rnd.uniform(-2.5, 2.5)
            r = rad * rnd.uniform(0.82, 1.2)
            made = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=r,
                                              matrix=Matrix.Translation((x, y, z)) @ Matrix.Diagonal((1.0, 0.8, 0.92, 1.0)))
            del made
    for v in bm.verts:  # flat underside
        if v.co.z < 3.0:
            v.co.z = 3.0 + (v.co.z - 3.0) * 0.15
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    me.update()

    top = max(v.co.z for v in me.vertices)
    light = Vector((0.45, -0.35, 0.82)).normalized()
    hi, lo = Vector((1.0, 0.97, 0.93)), Vector((0.52, 0.46, 0.64))
    col = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
    shade = []
    for v in me.vertices:
        k = 0.5 + 0.5 * v.normal.dot(light)
        shade.append(max(0.0, min(1.0, 0.12 + 0.62 * k + 0.32 * (v.co.z / top))))
    for poly in me.polygons:
        for li in poly.loop_indices:
            c = lo.lerp(hi, shade[me.loops[li].vertex_index])
            col.data[li].color = (c.x, c.y, c.z, 1.0)
    me.color_attributes.active_color = col
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    obj.color = (1.0, 0.82, 0.7, 1.0)
    return obj
