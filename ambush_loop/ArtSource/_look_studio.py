#!/usr/bin/env python3
"""Shared headless studio for Ambush Loop Look props.

Each build_<asset>.py still owns its mesh. This module only does lights,
cameras, clay/shaded contact sheets, iso bake, and GLB export.
"""

from __future__ import annotations

import os

import bpy
from mathutils import Vector


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll in (
        bpy.data.meshes,
        bpy.data.materials,
        bpy.data.images,
        bpy.data.cameras,
        bpy.data.lights,
        bpy.data.curves,
    ):
        for block in list(coll):
            coll.remove(block)
    for font in list(bpy.data.fonts):
        try:
            bpy.data.fonts.remove(font)
        except Exception:
            pass


def mat(name: str, color: tuple, rough: float, spec: float = 0.08, metal: float = 0.0) -> bpy.types.Material:
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    elif "Specular" in bsdf.inputs:
        bsdf.inputs["Specular"].default_value = spec
    return m


def box(name: str, size: Vector, loc: Vector, material: bpy.types.Material) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    sx, sy, sz = size.x * 0.5, size.y * 0.5, size.z * 0.5
    verts = [
        Vector((-sx, -sy, -sz)), Vector((sx, -sy, -sz)),
        Vector((sx, sy, -sz)), Vector((-sx, sy, -sz)),
        Vector((-sx, -sy, sz)), Vector((sx, -sy, sz)),
        Vector((sx, sy, sz)), Vector((-sx, sy, sz)),
    ]
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
        (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0),
    ]
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj.location = loc
    mesh.materials.append(material)
    return obj


def letter_bars(letter: str) -> list[tuple[float, float, float, float]]:
    """Unit-square bars (x0, z0, x1, z1) for a fat stencil glyph."""
    L = letter.upper()
    if L == "A":
        return [(0.08, 0.00, 0.30, 0.78), (0.70, 0.00, 0.92, 0.78), (0.18, 0.78, 0.82, 1.00), (0.22, 0.38, 0.78, 0.56)]
    if L == "C":
        return [(0.10, 0.00, 0.90, 0.18), (0.10, 0.82, 0.90, 1.00), (0.10, 0.18, 0.32, 0.82)]
    if L == "E":
        return [(0.10, 0.00, 0.32, 1.00), (0.32, 0.82, 0.90, 1.00), (0.32, 0.40, 0.78, 0.58), (0.32, 0.00, 0.90, 0.18)]
    if L == "F":
        return [(0.10, 0.00, 0.32, 1.00), (0.32, 0.82, 0.90, 1.00), (0.32, 0.42, 0.74, 0.58)]
    if L == "I":
        return [(0.38, 0.00, 0.62, 1.00)]
    if L == "L":
        return [(0.10, 0.00, 0.32, 1.00), (0.32, 0.00, 0.90, 0.18)]
    if L == "N":
        return [(0.08, 0.00, 0.28, 1.00), (0.72, 0.00, 0.92, 1.00), (0.28, 0.38, 0.72, 0.72)]
    if L == "O":
        return [(0.08, 0.00, 0.92, 0.20), (0.08, 0.80, 0.92, 1.00), (0.08, 0.20, 0.28, 0.80), (0.72, 0.20, 0.92, 0.80)]
    if L == "R":
        return [
            (0.08, 0.00, 0.28, 1.00),
            (0.28, 0.82, 0.88, 1.00),
            (0.70, 0.50, 0.90, 0.82),
            (0.28, 0.42, 0.78, 0.58),
            (0.52, 0.00, 0.88, 0.42),
        ]
    if L == "S":
        return [
            (0.10, 0.82, 0.90, 1.00),
            (0.10, 0.42, 0.90, 0.58),
            (0.10, 0.00, 0.90, 0.18),
            (0.10, 0.58, 0.30, 0.82),
            (0.70, 0.18, 0.90, 0.42),
        ]
    if L == "T":
        return [(0.08, 0.82, 0.92, 1.00), (0.38, 0.00, 0.62, 0.82)]
    return [(0.20, 0.20, 0.80, 0.80)]


def stamp_word(
    root: bpy.types.Object,
    word: str,
    material: bpy.types.Material,
    face_y: float,
    box_w: float,
    box_h: float,
    origin_z: float,
    thick: float = 0.0022,
    prefix: str = "Stamp",
) -> None:
    origin_x = -box_w * 0.5
    slot = box_w / float(max(len(word), 1))
    pad = slot * 0.10
    glyph_w = slot - pad
    n = 0
    for i, ch in enumerate(word):
        gx0 = origin_x + slot * i + pad * 0.5
        for x0, z0, x1, z1 in letter_bars(ch):
            bw = max(0.006, (x1 - x0) * glyph_w)
            bh = max(0.006, (z1 - z0) * box_h)
            cx = gx0 + (x0 + x1) * 0.5 * glyph_w
            cz = origin_z + (z0 + z1) * 0.5 * box_h
            bar = box(
                "%s_%d" % (prefix, n),
                Vector((bw, thick, bh)),
                Vector((cx, face_y, cz)),
                material,
            )
            bar.parent = root
            n += 1


def camera_at(name: str, loc: Vector, look: Vector, ortho: float = 0.0) -> bpy.types.Object:
    cam_data = bpy.data.cameras.new(name)
    if ortho > 0.0:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    else:
        cam_data.lens = 50
    cam = bpy.data.objects.new(name, cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (look - loc).to_track_quat("-Z", "Y").to_euler()
    return cam


def lights() -> None:
    key = bpy.data.lights.new("Key", "AREA")
    key.energy = 240
    key.size = 1.5
    key.color = (1.0, 0.93, 0.78)
    ko = bpy.data.objects.new("Key", key)
    ko.location = Vector((1.5, -1.6, 2.0))
    bpy.context.collection.objects.link(ko)

    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 75
    fill.size = 2.2
    fill.color = (0.55, 0.62, 0.70)
    fo = bpy.data.objects.new("Fill", fill)
    fo.location = Vector((-1.6, 1.1, 1.3))
    bpy.context.collection.objects.link(fo)

    rim = bpy.data.lights.new("Rim", "AREA")
    rim.energy = 115
    rim.size = 1.1
    rim.color = (0.70, 0.78, 0.90)
    ro = bpy.data.objects.new("Rim", rim)
    ro.location = Vector((0.15, 1.8, 1.6))
    bpy.context.collection.objects.link(ro)


def clay() -> bpy.types.Material:
    return mat("Clay", (0.62, 0.60, 0.56), 0.92, spec=0.04)


def apply_override(material: bpy.types.Material | None) -> dict:
    saved = {}
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        slots = []
        for slot in obj.material_slots:
            slots.append(slot.material)
            if material is not None:
                slot.material = material
        saved[obj.name] = slots
    return saved


def restore(saved: dict) -> None:
    for obj in bpy.data.objects:
        if obj.name not in saved:
            continue
        for i, m in enumerate(saved[obj.name]):
            if i < len(obj.material_slots):
                obj.material_slots[i].material = m


def render_still(cam: bpy.types.Object, path: str) -> None:
    scene = bpy.context.scene
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def compose_turnaround(tmpdir: str, png_path: str) -> None:
    names = [
        "clay_front", "clay_side", "clay_rear",
        "shade_front", "shade_side", "shade_rear",
    ]
    images = [bpy.data.images.load(os.path.join(tmpdir, n + ".png")) for n in names]
    w, h = images[0].size
    sheet_w, sheet_h = w * 3, h * 2
    sheet = bpy.data.images.new("Turnaround", width=sheet_w, height=sheet_h, alpha=False)
    pixels = [0.08] * (sheet_w * sheet_h * 4)
    for idx, img in enumerate(images):
        col = idx % 3
        row = 1 - (idx // 3)
        px = list(img.pixels)
        iw, ih = img.size
        for y in range(ih):
            for x in range(iw):
                si = ((row * ih + y) * sheet_w + (col * iw + x)) * 4
                ii = (y * iw + x) * 4
                pixels[si:si + 4] = px[ii:ii + 4]
    sheet.pixels = pixels
    sheet.filepath_raw = png_path
    sheet.file_format = "PNG"
    sheet.save()


def export_glb(root_name: str, glb_path: str) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.get(root_name)
    if root is None:
        raise RuntimeError("%s missing" % root_name)
    root.select_set(True)
    for obj in bpy.data.objects:
        if obj.parent == root:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_extras=False,
        export_cameras=False,
        export_lights=False,
    )


def setup_scene(res=(280, 210)) -> bpy.types.Scene:
    scene = bpy.context.scene
    engines = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys()
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = res[0]
    scene.render.resolution_y = res[1]
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.10, 0.10, 0.09, 1.0)
    bg.inputs[1].default_value = 0.6
    scene.world = world
    return scene


def shoot_turnaround(
    look: Vector,
    dist: float,
    out_dir: str,
    png_path: str,
    z_lift: float = 0.32,
) -> None:
    cams = {
        "front": camera_at("CamFront", Vector((0.0, -dist, z_lift)), look),
        "side": camera_at("CamSide", Vector((dist, 0.0, z_lift)), look),
        "rear": camera_at("CamRear", Vector((0.0, dist, z_lift)), look),
    }
    tmp = os.path.join(out_dir, "_turn_tmp")
    os.makedirs(tmp, exist_ok=True)
    clay_mat = clay()
    saved = apply_override(clay_mat)
    for name, cam in cams.items():
        render_still(cam, os.path.join(tmp, "clay_%s.png" % name))
    restore(saved)
    for name, cam in cams.items():
        render_still(cam, os.path.join(tmp, "shade_%s.png" % name))
    compose_turnaround(tmp, png_path)


def shoot_iso(look: Vector, iso_path: str, loc: Vector, res: int = 256) -> None:
    scene = bpy.context.scene
    scene.render.film_transparent = True
    scene.render.resolution_x = res
    scene.render.resolution_y = res
    iso = camera_at("CamIso", loc, look)
    render_still(iso, iso_path)
