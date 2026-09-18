#!/usr/bin/env python3
"""Headless WWII courtyard crate — PaperRoute Look stream (art study).

Deterministic. No GUI. Does not import into the playable Godot world.

    blender-headless --python ambush_loop/ArtSource/build_yard_crate.py

Writes next to this script:
  yard_crate.glb
  yard_crate_turnaround.png  (front/side/rear × clay/shaded)
"""

from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
GLB_PATH = os.path.join(OUT_DIR, "yard_crate.glb")
PNG_PATH = os.path.join(OUT_DIR, "yard_crate_turnaround.png")

# Mailbox-scale: ~0.62 × 0.42 × 0.38 m. Seeded so the GLB is bit-stable
# across headless runs on the same Blender.
SEED = 194406
BOARD_COUNT = 5


def _clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        bpy.data.meshes.remove(block)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)
    for cam in list(bpy.data.cameras):
        bpy.data.cameras.remove(cam)
    for lite in list(bpy.data.lights):
        bpy.data.lights.remove(lite)


def _mat(name: str, color: tuple, rough: float, spec: float = 0.08) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
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


def _build_crate() -> bpy.types.Object:
    pine = _mat("CratePine", (0.34, 0.24, 0.12), 0.72)
    strap = _mat("CrateIron", (0.12, 0.11, 0.10), 0.38, spec=0.22)
    lid = _mat("CrateLid", (0.30, 0.22, 0.11), 0.68)
    stencil = _mat("CrateStencil", (0.22, 0.26, 0.14), 0.55)

    root = bpy.data.objects.new("YardCrate", None)
    bpy.context.collection.objects.link(root)

    body = _box("CrateBody", Vector((0.62, 0.42, 0.34)), Vector((0, 0, 0.19)), pine)
    body.parent = root

    cap = _box("CrateLid", Vector((0.64, 0.44, 0.04)), Vector((0, 0, 0.38)), lid)
    cap.parent = root

    for i, x in enumerate((-0.22, 0.0, 0.22)):
        band = _box(
            "CrateStrap_%d" % i,
            Vector((0.04, 0.44, 0.36)),
            Vector((x, 0, 0.20)),
            strap,
        )
        band.parent = root

    for y in (-0.20, 0.20):
        rail = _box(
            "CrateRail_%s" % ("s" if y < 0 else "n"),
            Vector((0.64, 0.03, 0.03)),
            Vector((0, y, 0.05)),
            strap,
        )
        rail.parent = root

    # Board seams as shallow inset strips so the silhouette reads as planks.
    gap = 0.42 / float(BOARD_COUNT)
    for i in range(1, BOARD_COUNT):
        y = -0.21 + gap * i
        seam = _box(
            "CrateSeam_%d" % i,
            Vector((0.60, 0.006, 0.32)),
            Vector((0, y, 0.19)),
            _mat("CrateSeam_%d" % i, (0.18, 0.12, 0.06), 0.85),
        )
        seam.parent = root

    mark = _box("CrateMark", Vector((0.16, 0.008, 0.08)), Vector((0.0, -0.215, 0.24)), stencil)
    mark.parent = root

    bpy.context.view_layer.update()
    return root


def _camera_at(name: str, loc: Vector, look: Vector) -> bpy.types.Object:
    cam_data = bpy.data.cameras.new(name)
    cam_data.lens = 50
    cam = bpy.data.objects.new(name, cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = loc
    direction = look - loc
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return cam


def _lights() -> None:
    key = bpy.data.lights.new("Key", "AREA")
    key.energy = 250
    key.size = 1.6
    key.color = (1.0, 0.93, 0.78)
    ko = bpy.data.objects.new("Key", key)
    ko.location = Vector((1.6, -1.8, 2.2))
    bpy.context.collection.objects.link(ko)

    fill = bpy.data.lights.new("Fill", "AREA")
    fill.energy = 80
    fill.size = 2.4
    fill.color = (0.55, 0.62, 0.70)
    fo = bpy.data.objects.new("Fill", fill)
    fo.location = Vector((-1.8, 1.2, 1.4))
    bpy.context.collection.objects.link(fo)

    rim = bpy.data.lights.new("Rim", "AREA")
    rim.energy = 120
    rim.size = 1.2
    rim.color = (0.70, 0.78, 0.90)
    ro = bpy.data.objects.new("Rim", rim)
    ro.location = Vector((0.2, 2.0, 1.8))
    bpy.context.collection.objects.link(ro)


def _clay_override() -> bpy.types.Material:
    return _mat("Clay", (0.62, 0.60, 0.56), 0.92, spec=0.04)


def _apply_override(mat: bpy.types.Material | None) -> dict:
    """Swap every mesh material; return restore map."""
    saved = {}
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        slots = []
        for i, slot in enumerate(obj.material_slots):
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
    """2×3 contact sheet: clay front/side/rear over shaded front/side/rear."""
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
        row = 1 - (idx // 3)  # clay on top row in image space (y up)
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
    root = bpy.data.objects.get("YardCrate")
    if root is None:
        raise RuntimeError("YardCrate missing")
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
        export_extras=False,
        export_cameras=False,
        export_lights=False,
    )


def main() -> None:
    _clear_scene()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys() else "BLENDER_EEVEE"
    scene.render.resolution_x = 320
    scene.render.resolution_y = 240
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (0.10, 0.10, 0.09, 1.0)
    bg.inputs[1].default_value = 0.6
    scene.world = world

    _build_crate()
    _lights()
    look = Vector((0.0, 0.0, 0.20))
    dist = 1.55
    cams = {
        "front": _camera_at("CamFront", Vector((0.0, -dist, 0.55)), look),
        "side": _camera_at("CamSide", Vector((dist, 0.0, 0.55)), look),
        "rear": _camera_at("CamRear", Vector((0.0, dist, 0.55)), look),
    }

    tmp = os.path.join(OUT_DIR, "_turn_tmp")
    os.makedirs(tmp, exist_ok=True)
    clay = _clay_override()
    saved = _apply_override(clay)
    for name, cam in cams.items():
        _render_still(cam, os.path.join(tmp, "clay_%s.png" % name))
    _restore(saved)
    for name, cam in cams.items():
        _render_still(cam, os.path.join(tmp, "shade_%s.png" % name))
    _compose_turnaround(tmp)
    _export_glb()
    print("LOOK_CRATE_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_CRATE_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_CRATE_FAIL", exc, file=sys.stderr)
        raise
