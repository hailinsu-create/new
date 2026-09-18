#!/usr/bin/env python3
"""Headless WWII rifle crate / gun-case — PaperRoute Look stream.

Long pine case, plank seams on the SIDE, flush RIFLE stencil on FRONT.
Art study only this commit — not imported into the yard yet.

    blender-headless --python ambush_loop/ArtSource/build_gun_case.py
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
GLB_PATH = os.path.join(OUT_DIR, "gun_case.glb")
PNG_PATH = os.path.join(OUT_DIR, "gun_case_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "gun_case_iso.png")

# Longer than the ammo crate: rifle-length silhouette.
W, D, H = 0.92, 0.22, 0.16
PLANK = 0.016
GAP = 0.003
FRONT_N = 6
SIDE_N = 3
LID_N = 6


def _build() -> bpy.types.Object:
    pine = studio.mat("CasePine", (0.34, 0.24, 0.12), 0.76)
    pine_dk = studio.mat("CasePineDk", (0.22, 0.15, 0.08), 0.84)
    pine_lid = studio.mat("CaseLid", (0.30, 0.21, 0.10), 0.70)
    iron = studio.mat("CaseIron", (0.14, 0.13, 0.12), 0.38, spec=0.22, metal=0.35)
    stencil = studio.mat("CaseStencil", (0.12, 0.16, 0.08), 0.92, spec=0.02)

    root = bpy.data.objects.new("GunCase", None)
    bpy.context.collection.objects.link(root)

    floor = studio.box("CaseFloor", Vector((W - 0.02, D - 0.016, 0.012)), Vector((0, 0, 0.012)), pine_dk)
    floor.parent = root

    inner_w = W - PLANK * 2.0
    slat_w = (inner_w - GAP * (FRONT_N - 1)) / float(FRONT_N)
    x0 = -inner_w * 0.5 + slat_w * 0.5
    for i in range(FRONT_N):
        x = x0 + i * (slat_w + GAP)
        m = pine if i % 2 == 0 else pine_dk
        for y, tag in ((-D * 0.5 + PLANK * 0.5, "f"), (D * 0.5 - PLANK * 0.5, "b")):
            slat = studio.box(
                "CaseSlat_%s_%d" % (tag, i),
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
                "CaseSide_%s_%d" % (tag, i),
                Vector((PLANK, slat_d, H - 0.016)),
                Vector((x, y, H * 0.5)),
                m,
            )
            slat.parent = root

    for sx, sy, tag in ((-1, -1, "sw"), (1, -1, "se"), (1, 1, "ne"), (-1, 1, "nw")):
        post = studio.box(
            "CasePost_%s" % tag,
            Vector((PLANK * 1.1, PLANK * 1.1, H)),
            Vector((sx * (W * 0.5 - PLANK * 0.4), sy * (D * 0.5 - PLANK * 0.4), H * 0.5)),
            pine_dk,
        )
        post.parent = root

    lid_z = H + 0.014
    lid_span = D + 0.016
    lid_d = (lid_span - GAP * (LID_N - 1)) / float(LID_N)
    ly0 = -lid_span * 0.5 + lid_d * 0.5
    for i in range(LID_N):
        y = ly0 + i * (lid_d + GAP)
        board = studio.box(
            "CaseLid_%d" % i,
            Vector((W + 0.016, lid_d, 0.022)),
            Vector((0, y, lid_z)),
            pine_lid if i % 2 == 0 else pine,
        )
        board.parent = root

    for i, x in enumerate((-0.34, 0.0, 0.34)):
        band = studio.box(
            "CaseStrap_%d" % i,
            Vector((0.028, D + 0.01, H + 0.01)),
            Vector((x, 0, H * 0.5 - 0.004)),
            iron,
        )
        band.parent = root
    latch = studio.box("CaseLatch", Vector((0.08, 0.022, 0.03)), Vector((0.0, -D * 0.5 - 0.008, H - 0.02)), iron)
    latch.parent = root

    studio.stamp_word(
        root,
        "RIFLE",
        stencil,
        face_y=-D * 0.5 - 0.0012,
        box_w=0.62,
        box_h=0.09,
        origin_z=0.065,
        thick=0.0036,
        prefix="CaseStamp",
    )
    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.12))
    studio.shoot_turnaround(look, dist=1.35, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.42)
    studio.shoot_iso(look, ISO_PATH, Vector((0.95, -1.15, 0.85)))
    studio.export_glb("GunCase", GLB_PATH)
    print("LOOK_GUN_CASE_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_GUN_CASE_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_GUN_CASE_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_GUN_CASE_FAIL", exc, file=sys.stderr)
        raise
