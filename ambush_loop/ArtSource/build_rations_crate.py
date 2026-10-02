#!/usr/bin/env python3
"""Headless WWII rations crate — second crate variant (Look stream).

Darker pine, RATIONS stencil. Art study until a later Look commit.

    blender-headless --python ambush_loop/ArtSource/build_rations_crate.py
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
GLB_PATH = os.path.join(OUT_DIR, "rations_crate.glb")
PNG_PATH = os.path.join(OUT_DIR, "rations_crate_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "rations_crate_iso.png")

W, D, H = 0.48, 0.36, 0.30
PLANK = 0.016
GAP = 0.003
FRONT_N = 4
SIDE_N = 3
LID_N = 4


def _build() -> bpy.types.Object:
    pine = studio.mat("RatPine", (0.26, 0.16, 0.08), 0.80)
    pine_dk = studio.mat("RatPineDk", (0.16, 0.10, 0.05), 0.86)
    iron = studio.mat("RatIron", (0.18, 0.14, 0.10), 0.42, spec=0.18, metal=0.28)
    stencil = studio.mat("RatStencil", (0.55, 0.42, 0.16), 0.88, spec=0.04)

    root = bpy.data.objects.new("RationsCrate", None)
    bpy.context.collection.objects.link(root)

    floor = studio.box("RatFloor", Vector((W - 0.02, D - 0.016, 0.012)), Vector((0, 0, 0.012)), pine_dk)
    floor.parent = root

    inner_w = W - PLANK * 2.0
    slat_w = (inner_w - GAP * (FRONT_N - 1)) / float(FRONT_N)
    x0 = -inner_w * 0.5 + slat_w * 0.5
    for i in range(FRONT_N):
        x = x0 + i * (slat_w + GAP)
        m = pine if i % 2 == 0 else pine_dk
        for y, tag in ((-D * 0.5 + PLANK * 0.5, "f"), (D * 0.5 - PLANK * 0.5, "b")):
            slat = studio.box(
                "RatSlat_%s_%d" % (tag, i),
                Vector((slat_w, PLANK, H - 0.016)),
                Vector((x, y, H * 0.5)),
                m,
            )
            slat.parent = root

    inner_d = D - PLANK * 2.0
    slat_d = (inner_d - GAP * (SIDE_N - 1)) / float(SIDE_N)
    y0 = -inner_d * 0.5 + slat_d * 0.5
    for i in range(SIDE_N):
        y = y0 + i * (slat_d + GAP)
        m = pine_dk if i % 2 == 0 else pine
        for x, tag in ((-W * 0.5 + PLANK * 0.5, "l"), (W * 0.5 - PLANK * 0.5, "r")):
            slat = studio.box(
                "RatSide_%s_%d" % (tag, i),
                Vector((PLANK, slat_d, H - 0.016)),
                Vector((x, y, H * 0.5)),
                m,
            )
            slat.parent = root

    lid_z = H + 0.014
    lid_span = D + 0.014
    lid_d = (lid_span - GAP * (LID_N - 1)) / float(LID_N)
    ly0 = -lid_span * 0.5 + lid_d * 0.5
    for i in range(LID_N):
        y = ly0 + i * (lid_d + GAP)
        board = studio.box(
            "RatLid_%d" % i,
            Vector((W + 0.014, lid_d, 0.022)),
            Vector((0, y, lid_z)),
            pine if i % 2 == 0 else pine_dk,
        )
        board.parent = root

    for i, x in enumerate((-0.14, 0.14)):
        band = studio.box(
            "RatStrap_%d" % i,
            Vector((0.028, D + 0.01, H + 0.01)),
            Vector((x, 0, H * 0.5)),
            iron,
        )
        band.parent = root

    studio.stamp_word(
        root,
        "RATION",
        stencil,
        face_y=-D * 0.5 - 0.0012,
        box_w=0.38,
        box_h=0.08,
        origin_z=0.12,
        prefix="RatStamp",
    )
    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.18))
    studio.shoot_turnaround(look, dist=1.15, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.40)
    studio.shoot_iso(look, ISO_PATH, Vector((0.85, -1.05, 0.85)))
    studio.export_glb("RationsCrate", GLB_PATH)
    print("LOOK_RATIONS_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_RATIONS_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_RATIONS_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_RATIONS_FAIL", exc, file=sys.stderr)
        raise
