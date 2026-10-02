#!/usr/bin/env python3
"""Headless WWII ammo can — PaperRoute Look stream (second prop).

Deterministic. No GUI. Metal .30-cal can silhouette next to the yard crate.

    blender-headless --python ambush_loop/ArtSource/build_ammo_can.py

Writes:
  ammo_can.glb
  ammo_can_turnaround.png
  ammo_can_iso.png
"""

from __future__ import annotations

import os
import sys

import bpy
from mathutils import Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
GLB_PATH = os.path.join(OUT_DIR, "ammo_can.glb")
PNG_PATH = os.path.join(OUT_DIR, "ammo_can_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "ammo_can_iso.png")

# Smaller than the crate: ~0.28 × 0.14 × 0.18 m.
W, D, H = 0.28, 0.14, 0.18


def _clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for coll, attr in (
        (bpy.data.meshes, "meshes"),
        (bpy.data.materials, "materials"),
        (bpy.data.images, "images"),
        (bpy.data.cameras, "cameras"),
        (bpy.data.lights, "lights"),
        (bpy.data.curves, "curves"),
    ):
        for block in list(coll):
            coll.remove(block)


def _mat(name: str, color: tuple, rough: float, spec: float = 0.18, metal: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if "Metallic" in bsdf.inputs:
        bsdf.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    elif "Specular" in bsdf.inputs:
        bsdf.inputs["Specular"].default_value = spec
    return mat


def _box(name: str, size: Vector, loc: Vector, mat: bpy.types.Material) -> bpy.types.Object:
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
    mesh.materials.append(mat)
    return obj


def _letter_bars(letter: str) -> list[tuple[float, float, float, float]]:
    if letter == "3":
        return [
            (0.10, 0.80, 0.90, 1.00),
            (0.10, 0.40, 0.90, 0.58),
            (0.10, 0.00, 0.90, 0.18),
            (0.70, 0.58, 0.90, 0.80),
            (0.70, 0.18, 0.90, 0.40),
        ]
    if letter == "0":
        return [
            (0.10, 0.00, 0.90, 0.18),
            (0.10, 0.82, 0.90, 1.00),
            (0.10, 0.18, 0.32, 0.82),
            (0.68, 0.18, 0.90, 0.82),
        ]
    if letter == "C":
        return [
            (0.10, 0.00, 0.90, 0.18),
            (0.10, 0.82, 0.90, 1.00),
            (0.10, 0.18, 0.32, 0.82),
        ]
    if letter == "A":
        return [
            (0.08, 0.00, 0.30, 0.78),
            (0.70, 0.00, 0.92, 0.78),
            (0.18, 0.78, 0.82, 1.00),
            (0.22, 0.38, 0.78, 0.56),
        ]
    if letter == "L":
        return [
            (0.10, 0.00, 0.32, 1.00),
            (0.32, 0.00, 0.90, 0.18),
        ]
    return []


def _stamp(root: bpy.types.Object, mat: bpy.types.Material) -> None:
    word = "30CAL"
    face_y = -D * 0.5 - 0.001
    box_w = 0.22
    box_h = 0.055
    origin_x = -box_w * 0.5
    origin_z = 0.07
    slot = box_w / float(len(word))
    n = 0
    for i, ch in enumerate(word):
        gx0 = origin_x + slot * i
        for x0, z0, x1, z1 in _letter_bars(ch):
            bw = max(0.004, (x1 - x0) * (slot * 0.88))
            bh = max(0.004, (z1 - z0) * box_h)
            cx = gx0 + (x0 + x1) * 0.5 * (slot * 0.88)
            cz = origin_z + (z0 + z1) * 0.5 * box_h
            bar = _box(
                "CanStamp_%d" % n,
                Vector((bw, 0.002, bh)),
                Vector((cx, face_y, cz)),
                mat,
            )
            bar.parent = root
            n += 1


def _build() -> bpy.types.Object:
    olive = _mat("CanOlive", (0.22, 0.24, 0.14), 0.55, spec=0.16, metal=0.18)
    olive_dk = _mat("CanOliveDk", (0.16, 0.18, 0.10), 0.62, spec=0.14, metal=0.12)
    iron = _mat("CanIron", (0.18, 0.17, 0.14), 0.38, spec=0.28, metal=0.45)
    stencil = _mat("CanStencil", (0.10, 0.12, 0.08), 0.9, spec=0.04)

    root = bpy.data.objects.new("AmmoCan", None)
    bpy.context.collection.objects.link(root)

    body = _box("CanBody", Vector((W, D, H)), Vector((0, 0, H * 0.5)), olive)
    body.parent = root
    lid = _box("CanLid", Vector((W + 0.008, D + 0.008, 0.018)), Vector((0, 0, H + 0.004)), olive_dk)
    lid.parent = root
    # Latch rib on the front lip.
    latch = _box("CanLatch", Vector((0.06, 0.02, 0.03)), Vector((0.0, -D * 0.5 - 0.008, H - 0.01)), iron)
    latch.parent = root
    # Wire handle hoop (three boxes).
    handle = _box("CanHandle", Vector((0.12, 0.012, 0.012)), Vector((0.0, 0.0, H + 0.05)), iron)
    handle.parent = root
    for x in (-0.055, 0.055):
        post = _box(
            "CanHandlePost_%s" % ("l" if x < 0 else "r"),
            Vector((0.012, 0.012, 0.05)),
            Vector((x, 0.0, H + 0.028)),
            iron,
        )
        post.parent = root
    # Side beads so the silhouette is a can, not a brick.
    for y in (-D * 0.5, D * 0.5):
        bead = _box(
            "CanBead_%s" % ("s" if y < 0 else "n"),
            Vector((W + 0.004, 0.008, 0.012)),
            Vector((0, y, H * 0.45)),
            iron,
        )
        bead.parent = root
    _stamp(root, stencil)
    bpy.context.view_layer.update()
    return root


def _camera_at(name: str, loc: Vector, look: Vector) -> bpy.types.Object:
    cam_data = bpy.data.cameras.new(name)
    cam_data.lens = 50
    cam = bpy.data.objects.new(name, cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    cam.rotation_euler = (look - loc).to_track_quat("-Z", "Y").to_euler()
    return cam


def _lights() -> None:
    key = bpy.data.lights.new("Key", "AREA")
    key.energy = 220
    key.size = 1.4
    key.color = (1.0, 0.93, 0.78)
    ko = bpy.data.objects.new("Key", key)
    ko.location = Vector((1.2, -1.4, 1.6))
    bpy.context.collection.objects.link(ko)
    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 70
    fill.size = 2.0
    fill.color = (0.55, 0.62, 0.70)
    fo = bpy.data.objects.new("Fill", fill)
    fo.location = Vector((-1.4, 1.0, 1.1))
    bpy.context.collection.objects.link(fo)
    rim = bpy.data.lights.new("Rim", "AREA")
    rim.energy = 110
    rim.size = 1.0
    rim.color = (0.70, 0.78, 0.90)
    ro = bpy.data.objects.new("Rim", rim)
    ro.location = Vector((0.1, 1.5, 1.4))
    bpy.context.collection.objects.link(ro)


def _mat_clay() -> bpy.types.Material:
    return _mat("Clay", (0.62, 0.60, 0.56), 0.92, spec=0.04)


def _apply_override(mat: bpy.types.Material | None) -> dict:
    saved = {}
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        slots = []
        for slot in obj.material_slots:
            slots.append(slot.material)
            if mat is not None:
                slot.material = mat
        saved[obj.name] = slots
    return saved


def _restore(saved: dict) -> None:
    for obj in bpy.data.objects:
        if obj.name not in saved:
            continue
        for i, mat in enumerate(saved[obj.name]):
            if i < len(obj.material_slots):
                obj.material_slots[i].material = mat


def _render_still(cam: bpy.types.Object, path: str) -> None:
    scene = bpy.context.scene
    scene.camera = cam
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def _compose_turnaround(tmpdir: str) -> None:
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
    sheet.filepath_raw = PNG_PATH
    sheet.file_format = "PNG"
    sheet.save()


def _export_glb() -> None:
    bpy.ops.object.select_all(action="DESELECT")
    root = bpy.data.objects.get("AmmoCan")
    if root is None:
        raise RuntimeError("AmmoCan missing")
    root.select_set(True)
    for obj in bpy.data.objects:
        if obj.parent == root:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    bpy.ops.export_scene.gltf(
        filepath=GLB_PATH,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )


def main() -> None:
    _clear_scene()
    scene = bpy.context.scene
    engines = bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys()
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = 320
    scene.render.resolution_y = 240
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.10, 0.10, 0.09, 1.0)
    bg.inputs[1].default_value = 0.6
    scene.world = world

    _build()
    _lights()
    look = Vector((0.0, 0.0, 0.12))
    dist = 0.85
    cams = {
        "front": _camera_at("CamFront", Vector((0.0, -dist, 0.32)), look),
        "side": _camera_at("CamSide", Vector((dist, 0.0, 0.32)), look),
        "rear": _camera_at("CamRear", Vector((0.0, dist, 0.32)), look),
    }
    tmp = os.path.join(OUT_DIR, "_turn_tmp")
    os.makedirs(tmp, exist_ok=True)
    clay = _mat_clay()
    saved = _apply_override(clay)
    for name, cam in cams.items():
        _render_still(cam, os.path.join(tmp, "clay_%s.png" % name))
    _restore(saved)
    for name, cam in cams.items():
        _render_still(cam, os.path.join(tmp, "shade_%s.png" % name))
    _compose_turnaround(tmp)

    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    iso = _camera_at("CamIso", Vector((0.55, -0.7, 0.55)), look)
    _render_still(iso, ISO_PATH)
    _export_glb()
    print("LOOK_CAN_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_CAN_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_CAN_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_CAN_FAIL", exc, file=sys.stderr)
        raise
