#!/usr/bin/env python3
"""Headless WWII courtyard lamp post — PaperRoute Look stream.

Iron stem + caged sodium lamp. Art study until a later Look commit
replaces the procedural _lamp_post wash.

    blender-headless --python ambush_loop/ArtSource/build_lamp_post.py
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
GLB_PATH = os.path.join(OUT_DIR, "lamp_post.glb")
PNG_PATH = os.path.join(OUT_DIR, "lamp_post_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "lamp_post_iso.png")


def _build() -> bpy.types.Object:
    iron = studio.mat("LampIron", (0.16, 0.15, 0.13), 0.42, spec=0.22, metal=0.45)
    iron_dk = studio.mat("LampIronDk", (0.10, 0.09, 0.08), 0.50, spec=0.16, metal=0.40)
    glass = studio.mat("LampGlass", (0.92, 0.78, 0.42), 0.18, spec=0.4)
    rust = studio.mat("LampRust", (0.42, 0.22, 0.10), 0.72)

    root = bpy.data.objects.new("LampPost", None)
    bpy.context.collection.objects.link(root)

    base = studio.box("LampBase", Vector((0.12, 0.12, 0.04)), Vector((0, 0, 0.02)), iron_dk)
    base.parent = root
    stem = studio.box("LampStem", Vector((0.028, 0.028, 0.72)), Vector((0, 0, 0.40)), iron)
    stem.parent = root
    arm = studio.box("LampArm", Vector((0.16, 0.022, 0.022)), Vector((0.06, 0, 0.74)), iron)
    arm.parent = root
    cage = studio.box("LampCage", Vector((0.10, 0.10, 0.12)), Vector((0.12, 0, 0.68)), iron_dk)
    cage.parent = root
    bulb = studio.box("LampBulb", Vector((0.06, 0.06, 0.07)), Vector((0.12, 0, 0.68)), glass)
    bulb.parent = root
    for i, (dx, dy) in enumerate(((-0.05, 0.0), (0.05, 0.0), (0.0, -0.05), (0.0, 0.05))):
        bar = studio.box(
            "LampBar_%d" % i,
            Vector((0.012 if abs(dx) > 0.01 else 0.09, 0.012 if abs(dy) > 0.01 else 0.09, 0.12)),
            Vector((0.12 + dx, dy, 0.68)),
            rust if i % 2 == 0 else iron,
        )
        bar.parent = root
    cap = studio.box("LampCap", Vector((0.12, 0.12, 0.02)), Vector((0.12, 0, 0.76)), iron)
    cap.parent = root

    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.06, 0.0, 0.42))
    studio.shoot_turnaround(look, dist=1.45, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.55)
    studio.shoot_iso(look, ISO_PATH, Vector((0.90, -1.10, 1.05)))
    studio.export_glb("LampPost", GLB_PATH)
    print("LOOK_LAMP_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_LAMP_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_LAMP_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_LAMP_FAIL", exc, file=sys.stderr)
        raise
