#!/usr/bin/env python3
"""Headless WWII fence section — PaperRoute Look stream.

Two posts + three rails. Art study until a later Look commit wires the
iso into the west alley.

    blender-headless --python ambush_loop/ArtSource/build_fence_section.py
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
GLB_PATH = os.path.join(OUT_DIR, "fence_section.glb")
PNG_PATH = os.path.join(OUT_DIR, "fence_section_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "fence_section_iso.png")


def _build() -> bpy.types.Object:
    wood = studio.mat("FenceWood", (0.28, 0.20, 0.10), 0.82)
    wood_dk = studio.mat("FenceWoodDk", (0.18, 0.12, 0.06), 0.86)
    iron = studio.mat("FenceIron", (0.16, 0.15, 0.13), 0.40, spec=0.20, metal=0.30)

    root = bpy.data.objects.new("FenceSection", None)
    bpy.context.collection.objects.link(root)

    for i, x in enumerate((-0.38, 0.38)):
        post = studio.box(
            "FencePost_%d" % i,
            Vector((0.06, 0.06, 0.72)),
            Vector((x, 0.0, 0.36)),
            wood_dk if i == 0 else wood,
        )
        post.parent = root
        cap = studio.box("FenceCap_%d" % i, Vector((0.08, 0.08, 0.03)), Vector((x, 0.0, 0.74)), iron)
        cap.parent = root

    for i, z in enumerate((0.18, 0.38, 0.58)):
        rail = studio.box(
            "FenceRail_%d" % i,
            Vector((0.78, 0.03, 0.04)),
            Vector((0.0, 0.0, z)),
            wood if i % 2 == 0 else wood_dk,
        )
        rail.parent = root

    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.36))
    studio.shoot_turnaround(look, dist=1.35, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.48)
    studio.shoot_iso(look, ISO_PATH, Vector((0.95, -1.15, 0.95)))
    studio.export_glb("FenceSection", GLB_PATH)
    print("LOOK_FENCE_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_FENCE_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_FENCE_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as extra:
        print("LOOK_FENCE_FAIL", extra, file=sys.stderr)
        raise
