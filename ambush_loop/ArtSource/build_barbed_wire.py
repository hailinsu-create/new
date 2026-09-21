#!/usr/bin/env python3
"""Headless WWII barbed-wire coil — Look stream art study.

Deterministic. No GUI. Tight oval helix of dark iron wire with barbs. Top-down
iso must read as a wire coil (helical mass with stakes), not a flat gray ring.

    blender-headless --python ambush_loop/ArtSource/build_barbed_wire.py
"""

from __future__ import annotations

import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import _look_studio as studio  # noqa: E402

OUT_DIR = HERE
GLB_PATH = os.path.join(OUT_DIR, "barbed_wire.glb")
PNG_PATH = os.path.join(OUT_DIR, "barbed_wire_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "barbed_wire_iso.png")

TAU = math.pi * 2.0


def _seg(
    name: str,
    p0: Vector,
    p1: Vector,
    radius: float,
    material: bpy.types.Material,
) -> bpy.types.Object:
    d = p1 - p0
    length = max(0.008, d.length)
    mid = (p0 + p1) * 0.5
    mesh = bpy.data.meshes.new(name + "Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    segs = 6
    hz = length * 0.5
    verts: list[Vector] = []
    for i in range(segs):
        a = TAU * i / segs
        verts.append(Vector((math.cos(a) * radius, math.sin(a) * radius, -hz)))
    for i in range(segs):
        a = TAU * i / segs
        verts.append(Vector((math.cos(a) * radius, math.sin(a) * radius, hz)))
    faces: list[tuple[int, ...]] = []
    for i in range(segs):
        j = (i + 1) % segs
        faces.append((i, j, segs + j, segs + i))
    faces.append(tuple(reversed(range(segs))))
    faces.append(tuple(range(segs, segs * 2)))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(material)
    obj.location = mid
    # Align +Z to direction.
    if length > 1e-6:
        obj.rotation_euler = d.normalized().to_track_quat("Z", "Y").to_euler()
    return obj


def _build() -> bpy.types.Object:
    iron = studio.mat("WireIron", (0.20, 0.18, 0.14), 0.36, spec=0.32, metal=0.58)
    iron_dk = studio.mat("WireIronDk", (0.10, 0.09, 0.07), 0.52, spec=0.22, metal=0.48)
    rust = studio.mat("WireRust", (0.44, 0.24, 0.10), 0.78, spec=0.10, metal=0.18)

    root = bpy.data.objects.new("BarbedWire", None)
    bpy.context.collection.objects.link(root)

    # Continuous oval helix — reads as a coil from iso, not a flat washer.
    turns = 5.5
    steps = 72
    pts: list[Vector] = []
    for i in range(steps + 1):
        t = i / float(steps)
        ang = t * turns * TAU
        # Radius breathes so the coil has body.
        breathe = 0.9 + 0.18 * math.sin(t * math.pi)
        rx = 0.135 * breathe
        ry = 0.110 * breathe
        z = 0.02 + t * 0.16
        pts.append(Vector((math.cos(ang) * rx, math.sin(ang) * ry, z)))

    for i in range(len(pts) - 1):
        mat = iron if i % 3 else iron_dk
        seg = _seg("Coil_%d" % i, pts[i], pts[i + 1], 0.007, mat)
        seg.parent = root
        if i % 5 == 0:
            # Tiny barb cross.
            p = pts[i]
            b1 = studio.box(
                "BarbA_%d" % i,
                Vector((0.028, 0.004, 0.004)),
                p + Vector((0.0, 0.0, 0.008)),
                rust,
            )
            b1.rotation_euler = (0.3, 0.5, ang if False else (i * 0.4))
            b1.parent = root
            b2 = studio.box(
                "BarbB_%d" % i,
                Vector((0.004, 0.022, 0.004)),
                p + Vector((0.0, 0.0, 0.008)),
                rust,
            )
            b2.parent = root

    # Two wooden/iron stakes the coil leans on.
    for sx, sy in ((-0.11, -0.04), (0.12, 0.05)):
        stake = studio.box(
            "Stake_%s" % ("l" if sx < 0 else "r"),
            Vector((0.016, 0.016, 0.26)),
            Vector((sx, sy, 0.13)),
            iron_dk,
        )
        stake.parent = root

    # Ground shadow pad (thin, darker than coil).
    pad = studio.box("CoilPad", Vector((0.30, 0.26, 0.010)), Vector((0.0, 0.0, 0.005)), iron_dk)
    pad.parent = root

    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.09))
    studio.shoot_turnaround(look, dist=0.70, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.20)
    studio.shoot_iso(look, ISO_PATH, Vector((0.50, -0.65, 0.48)))
    studio.export_glb("BarbedWire", GLB_PATH)
    print("LOOK_WIRE_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_WIRE_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_WIRE_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_WIRE_FAIL", exc, file=sys.stderr)
        raise
