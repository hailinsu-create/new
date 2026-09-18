#!/usr/bin/env python3
"""Headless WWII courtyard crate — PaperRoute Look stream.

Deterministic. No GUI. Defect pass vs yard_crate_turnaround.png:
  - shaded SIDE must show plank seams (not a flat pine slab)
  - FRONT stencil is painted/stamped letters, not a raised plus

    blender-headless --python ambush_loop/ArtSource/build_yard_crate.py

Writes next to this script:
  yard_crate.glb
  yard_crate_turnaround.png  (front/side/rear × clay/shaded)
  yard_crate_iso.png         (3/4 bake for the 2D yard, transparent)
  yard_crate_top.png         (top bake)
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
ISO_PATH = os.path.join(OUT_DIR, "yard_crate_iso.png")
TOP_PATH = os.path.join(OUT_DIR, "yard_crate_top.png")

SEED = 194406
# Mailbox-scale outer hull.
W, D, H = 0.62, 0.42, 0.34
PLANK = 0.018
GAP = 0.004
FRONT_N = 5
SIDE_N = 4
LID_N = 5


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
    for curve in list(bpy.data.curves):
        bpy.data.curves.remove(curve)
    for font in list(bpy.data.fonts):
        try:
            bpy.data.fonts.remove(font)
        except Exception:
            pass


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


def _letter_bars(letter: str) -> list[tuple[float, float, float, float]]:
    """Unit-square bars (x0, z0, x1, z1) in 0..1 for a block stencil glyph."""
    # Keep strokes fat so a 3/4 bake still reads at ~64px.
    if letter == "A":
        return [
            (0.08, 0.00, 0.30, 0.78),
            (0.70, 0.00, 0.92, 0.78),
            (0.18, 0.78, 0.82, 1.00),
            (0.22, 0.38, 0.78, 0.56),
        ]
    if letter == "M":
        return [
            (0.04, 0.00, 0.24, 1.00),
            (0.76, 0.00, 0.96, 1.00),
            (0.24, 0.62, 0.44, 1.00),
            (0.56, 0.62, 0.76, 1.00),
            (0.40, 0.28, 0.60, 0.68),
        ]
    if letter == "O":
        return [
            (0.08, 0.00, 0.92, 0.20),
            (0.08, 0.80, 0.92, 1.00),
            (0.08, 0.20, 0.28, 0.80),
            (0.72, 0.20, 0.92, 0.80),
        ]
    return []


def _stamp_letters(root: bpy.types.Object, mat: bpy.types.Material) -> None:
    """Flush painted stencil on the front (Y-) face — not a raised plus."""
    word = "AMMO"
    face_y = -D * 0.5 - 0.0012
    box_w = 0.46
    box_h = 0.11
    origin_x = -box_w * 0.5
    origin_z = 0.20
    slot = box_w / float(len(word))
    pad = 0.012
    glyph_w = slot - pad
    thick = 0.0022
    n = 0
    for i, ch in enumerate(word):
        gx0 = origin_x + slot * i + pad * 0.5
        for x0, z0, x1, z1 in _letter_bars(ch):
            bw = max(0.008, (x1 - x0) * glyph_w)
            bh = max(0.008, (z1 - z0) * box_h)
            cx = gx0 + (x0 + x1) * 0.5 * glyph_w
            cz = origin_z + (z0 + z1) * 0.5 * box_h
            bar = _box(
                "CrateStamp_%d" % n,
                Vector((bw, thick, bh)),
                Vector((cx, face_y, cz)),
                mat,
            )
            bar.parent = root
            n += 1


def _build_crate() -> bpy.types.Object:
    pine = _mat("CratePine", (0.36, 0.25, 0.12), 0.74)
    pine_dark = _mat("CratePineDark", (0.24, 0.16, 0.08), 0.82)
    pine_lid = _mat("CrateLid", (0.32, 0.22, 0.10), 0.70)
    strap = _mat("CrateIron", (0.13, 0.12, 0.11), 0.36, spec=0.24)
    stencil = _mat("CrateStencil", (0.16, 0.20, 0.10), 0.92, spec=0.02)

    root = bpy.data.objects.new("YardCrate", None)
    bpy.context.collection.objects.link(root)

    # Floor of the box (not a solid hull — sides are real planks).
    floor = _box("CrateFloor", Vector((W - 0.02, D - 0.02, 0.016)), Vector((0, 0, 0.018)), pine_dark)
    floor.parent = root

    # Front / back: vertical slats so the LONG faces read as boards.
    inner_w = W - PLANK * 2.0
    slat_w = (inner_w - GAP * (FRONT_N - 1)) / float(FRONT_N)
    x0 = -inner_w * 0.5 + slat_w * 0.5
    for i in range(FRONT_N):
        x = x0 + i * (slat_w + GAP)
        mat = pine if i % 2 == 0 else pine_dark
        for y, tag in ((-D * 0.5 + PLANK * 0.5, "f"), (D * 0.5 - PLANK * 0.5, "b")):
            slat = _box(
                "CrateSlat_%s_%d" % (tag, i),
                Vector((slat_w, PLANK, H - 0.02)),
                Vector((x, y, H * 0.5)),
                mat,
            )
            slat.parent = root

    # Left / right: vertical slats so the SIDE (shaded-side panel) is not a slab.
    inner_d = D - PLANK * 2.0
    slat_d = (inner_d - GAP * (SIDE_N - 1)) / float(SIDE_N)
    y0 = -inner_d * 0.5 + slat_d * 0.5
    for i in range(SIDE_N):
        y = y0 + i * (slat_d + GAP)
        mat = pine_dark if i % 2 == 0 else pine
        for x, tag in ((-W * 0.5 + PLANK * 0.5, "l"), (W * 0.5 - PLANK * 0.5, "r")):
            slat = _box(
                "CrateSide_%s_%d" % (tag, i),
                Vector((PLANK, slat_d, H - 0.02)),
                Vector((x, y, H * 0.5)),
                mat,
            )
            slat.parent = root

    # Corner posts so seams don't open at the silhouette.
    for sx, sy, tag in (
        (-1, -1, "sw"), (1, -1, "se"), (1, 1, "ne"), (-1, 1, "nw")
    ):
        post = _box(
            "CratePost_%s" % tag,
            Vector((PLANK * 1.15, PLANK * 1.15, H)),
            Vector((sx * (W * 0.5 - PLANK * 0.4), sy * (D * 0.5 - PLANK * 0.4), H * 0.5)),
            pine_dark,
        )
        post.parent = root

    # Lid boards (along X) with visible gaps.
    lid_z = H + 0.018
    lid_span = D + 0.02
    lid_d = (lid_span - GAP * (LID_N - 1)) / float(LID_N)
    ly0 = -lid_span * 0.5 + lid_d * 0.5
    for i in range(LID_N):
        y = ly0 + i * (lid_d + GAP)
        board = _box(
            "CrateLid_%d" % i,
            Vector((W + 0.02, lid_d, 0.028)),
            Vector((0, y, lid_z)),
            pine_lid if i % 2 == 0 else pine,
        )
        board.parent = root

    # Iron straps wrap the long axis — three bands, plus skids.
    for i, x in enumerate((-0.20, 0.0, 0.20)):
        band = _box(
            "CrateStrap_%d" % i,
            Vector((0.034, D + 0.012, H + 0.012)),
            Vector((x, 0, H * 0.5 - 0.004)),
            strap,
        )
        band.parent = root
    for y in (-D * 0.5 + 0.03, D * 0.5 - 0.03):
        rail = _box(
            "CrateRail_%s" % ("s" if y < 0 else "n"),
            Vector((W + 0.02, 0.028, 0.028)),
            Vector((0, y, 0.02)),
            strap,
        )
        rail.parent = root

    _stamp_letters(root, stencil)
    bpy.context.view_layer.update()
    return root


def _camera_at(name: str, loc: Vector, look: Vector, ortho: float = 0.0) -> bpy.types.Object:
    cam_data = bpy.data.cameras.new(name)
    if ortho > 0.0:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    else:
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


def _studio_world(scene: bpy.types.Scene, rgb: tuple, strength: float) -> None:
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs[0].default_value = (*rgb, 1.0)
    bg.inputs[1].default_value = strength
    scene.world = world


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
    _studio_world(scene, (0.10, 0.10, 0.09), 0.6)

    _build_crate()
    _lights()
    look = Vector((0.0, 0.0, 0.22))
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

    # 2D yard bakes — transparent, same mesh, no studio wash.
    scene.render.film_transparent = True
    scene.render.resolution_x = 256
    scene.render.resolution_y = 256
    iso = _camera_at("CamIso", Vector((1.05, -1.25, 1.05)), look)
    _render_still(iso, ISO_PATH)
    scene.render.resolution_x = 256
    scene.render.resolution_y = 192
    top = _camera_at("CamTop", Vector((0.0, 0.0, 1.55)), Vector((0.0, 0.0, 0.0)), ortho=0.85)
    _render_still(top, TOP_PATH)

    _export_glb()
    print("LOOK_CRATE_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_CRATE_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_CRATE_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))
    print("LOOK_CRATE_TOP", TOP_PATH, "bytes", os.path.getsize(TOP_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_CRATE_FAIL", exc, file=sys.stderr)
        raise
