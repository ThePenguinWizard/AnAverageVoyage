"""Blender side of the generator: put generated ships into a scene, render previews, export FBX meshes."""

import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

# Roblox (x, y-up, z) -> Blender (x, -z, z-up)
CONV = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
ROOT_COLLECTION = "Voyage"


def rb(v):
    return Vector((v[0], -v[2], v[1]))


def _mesh(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    return me


def unit_meshes():
    h = 0.5
    cube = _mesh("wg_cube", [(x, y, z) for x in (-h, h) for y in (-h, h) for z in (-h, h)],
                 [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
    wedge = _mesh("wg_wedge", [(-h, -h, -h), (h, -h, -h), (h, -h, h), (-h, -h, h), (-h, h, h), (h, h, h)],
                  [(0, 1, 2, 3), (3, 2, 5, 4), (0, 4, 5, 1), (0, 3, 4), (1, 5, 2)])
    n = 16
    verts = []
    for x in (-h, h):
        for i in range(n):
            a = i * 2 * math.pi / n
            verts.append((x, h * math.cos(a), h * math.sin(a)))
    faces = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    faces.append(tuple(range(n)))
    faces.append(tuple(range(2 * n - 1, n - 1, -1)))
    cyl = _mesh("wg_cyl", verts, faces)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=8, radius=0.5)
    sphere = bpy.data.meshes.new("wg_ball")
    bm.to_mesh(sphere)
    bm.free()
    return {"cube": cube, "wedge": wedge, "cyl": cyl, "ball": sphere}


def new_collection(name, parent):
    c = bpy.data.collections.new(name)
    parent.children.link(c)
    return c


def reset_root(wipe_file):
    """Start from an empty file (background runs) or just replace our own collection (live sessions)."""
    if wipe_file:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    old = bpy.data.collections.get(ROOT_COLLECTION)
    if old:
        for o in list(old.all_objects):
            bpy.data.objects.remove(o, do_unlink=True)
        for c in list(old.children_recursive):
            bpy.data.collections.remove(c)
        bpy.data.collections.remove(old)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    return new_collection(ROOT_COLLECTION, bpy.context.scene.collection)


def add_parts(model, coll, meshes):
    for p in model.parts():
        if p.props.get("Transparency", 0) >= 1:
            continue
        if p.shape == "Cylinder":
            kind = "cyl"
        elif p.shape == "Ball":
            kind = "ball"
        elif p.class_name == "WedgePart":
            kind = "wedge"
        else:
            kind = "cube"
        obj = bpy.data.objects.new(p.name, meshes[kind])
        coll.objects.link(obj)
        size = p.size
        if kind == "ball":
            m = min(size)
            size = (m, m, m)
        X, Y, Z = p.rot
        R = Matrix(((X[0], Y[0], Z[0]), (X[1], Y[1], Z[1]), (X[2], Y[2], Z[2])))
        M = (CONV @ R @ Matrix.Diagonal(Vector(size))).to_4x4()
        M.translation = rb(p.pos)
        obj.matrix_world = M
        c = p.color
        obj.color = (c[0] / 255, c[1] / 255, c[2] / 255, 1.0)


def add_mesh(name, buf, coll, offset=(0, 0, 0)):
    """Create a Blender object from a MeshBuf (ship-local Roblox coordinates), moved by `offset` (Roblox)."""
    me = _mesh(name, [tuple(rb(v)) for v in buf.verts], buf.faces)
    if buf.smooth:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.002)
        bm.to_mesh(me)
        bm.free()
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
        me.set_sharp_from_angle(angle=math.radians(40))
    me.update()
    obj = bpy.data.objects.new(name, me)
    coll.objects.link(obj)
    obj.location = rb(offset)
    c = buf.color
    obj.color = (c[0] / 255, c[1] / 255, c[2] / 255, 1.0)
    return obj


def export_fbx(objs, path):
    """Export objects to FBX at the origin (their scene location is ignored)."""
    saved = [(o, o.location.copy()) for o in objs]
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in objs:
        o.location = (0, 0, 0)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, axis_forward="-Z",
                             axis_up="Y", apply_scale_options="FBX_SCALE_ALL", bake_space_transform=True,
                             mesh_smooth_type="FACE", colors_type="SRGB", add_leaf_bones=False)
    for o, loc in saved:
        o.location = loc
        o.select_set(False)


VIEWS = [
    # name, eye (roblox), target (roblox), lens, show water
    ("overview", (190, 140, 170), (0, 0, -170), 30, True),
    ("sloop", (-40, 26, -40), (-80, 6, 10), 35, True),
    ("sloop_aft", (-118, 30, 58), (-80, 6, 10), 35, True),
    ("brig", (40, 40, -62), (-12, 10, 0), 35, True),
    ("brig_aft", (-62, 42, 78), (-12, 8, 0), 35, True),
    ("galleon", (160, 55, -90), (72, 14, -6), 35, True),
    ("galleon_aft", (0, 60, 100), (72, 10, -6), 35, True),
    ("galleon_deck", (96, 58, 40), (72, 4, -10), 30, True),
    ("galleon_side_dry", (190, 6, -6), (72, 4, -6), 40, False),
]


def render(out_dir, views=None):
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0))
    water = bpy.context.active_object
    water.scale = (2400, 2400, 1)
    water.color = (0.11, 0.3, 0.62, 1.0)
    world = bpy.data.worlds.new("Sky")
    world.color = (0.62, 0.6, 0.85)
    scene.world = world
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "OBJECT"
    shading.show_shadows = True
    shading.shadow_intensity = 0.4
    shading.show_cavity = True
    shading.cavity_type = "WORLD"
    shading.show_backface_culling = True
    scene.display.light_direction = (0.45, -0.35, 0.82)
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.clip_end = 5000
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for name, eye, target, lens, show_water in (views or VIEWS):
        water.hide_render = not show_water
        cam_data.lens = lens
        e, tg = rb(eye), rb(target)
        cam.location = e
        cam.rotation_euler = (tg - e).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, name + ".png")
        bpy.ops.render.render(write_still=True)
