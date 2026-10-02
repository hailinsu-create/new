#!/usr/bin/env python3
"""Headless WWII sandbag stack — PaperRoute Look stream.

Three olive canvas bags with visible sag seams. Art study until a later
Look commit wires the iso into the west wall.

    blender-headless --python ambush_loop/ArtSource/build_sandbag.py
"""

from __future__ import annotations

import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import _look_studio as studio  # noqa: E402

OUT_DIR = HERE
GLB_PATH = os.path.join(OUT_DIR, "sandbag.glb")
PNG_PATH = os.path.join(OUT_DIR, "sandbag_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "sandbag_iso.png")


def _bag(name: str, size: Vector, loc: Vector, yaw: float, material) -> bpy.types.Object:
    obj = studio.box(name, size, loc, material)
    obj.rotation_euler = (0.06, 0.0, yaw)
    return obj


def _build() -> bpy.types.Object:
    canvas = studio.mat("BagCanvas", (0.38, 0.36, 0.22), 0.88)
    canvas_dk = studio.mat("BagCanvasDk", (0.28, 0.26, 0.16), 0.90)
    twine = studio.mat("BagTwine", (0.22, 0.18, 0.10), 0.70)

    root = bpy.data.objects.new("Sandbag", None)
    bpy.context.collection.objects.link(root)

    b0 = _bag("Bag0", Vector((0.42, 0.18, 0.14)), Vector((-0.08, 0.02, 0.07)), 0.18, canvas)
    b0.parent = root
    b1 = _bag("Bag1", Vector((0.40, 0.17, 0.13)), Vector((0.14, -0.02, 0.07)), -0.22, canvas_dk)
    b1.parent = root
    b2 = _bag("Bag2", Vector((0.36, 0.16, 0.12)), Vector((0.02, 0.00, 0.20)), 0.08, canvas)
    b2.parent = root

    for i, (x, z) in enumerate(((-0.08, 0.13), (0.14, 0.13), (0.02, 0.26))):
        tie = studio.box("BagTie_%d" % i, Vector((0.04, 0.03, 0.03)), Vector((x, 0.0, z)), twine)
        tie.parent = root

    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.12))
    studio.shoot_turnaround(look, dist=0.95, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.28)
    studio.shoot_iso(look, ISO_PATH, Vector((0.65, -0.80, 0.62)))
    studio.export_glb("Sandbag", GLB_PATH)
    print("LOOK_SANDBAG_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_SANDBAG_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_SANDBAG_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_SANDBAG_FAIL", exc, file=sys.stderr)
        raise
