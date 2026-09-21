#!/usr/bin/env python3
"""Headless WWII wooden barrel — Look stream art study.

Deterministic. No GUI. Compact oak barrel: faceted stave body with alternating
light/dark oak, three iron hoops, gentle bulge, top bung. Distinct from the
olive steel oil drum — no OIL stencil. Art study until a later Look commit.

    blender-headless --python ambush_loop/ArtSource/build_wooden_barrel.py

Writes (next to this script):
  wooden_barrel.glb
  wooden_barrel_turnaround.png
  wooden_barrel_iso.png
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
GLB_PATH = os.path.join(OUT_DIR, "wooden_barrel.glb")
PNG_PATH = os.path.join(OUT_DIR, "wooden_barrel_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "wooden_barrel_iso.png")

TAU = math.pi * 2.0
SEGMENTS = 16
PROFILE = [
    (0.140, 0.000),
    (0.150, 0.030),
    (0.158, 0.120),
    (0.160, 0.250),
    (0.158, 0.380),
    (0.150, 0.470),
    (0.140, 0.500),
]
HOOPS = (
    (0.030, 0.075, 0.150),
    (0.225, 0.275, 0.160),
    (0.425, 0.470, 0.151),
)


def _lathe(
    name: str,
    profile: list[tuple[float, float]],
    material: bpy.types.Material,
    closed: bool = False,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    verts: list[Vector] = []
    rings: list[list[int]] = []
    for r, z in profile:
        ring = []
        for i in range(SEGMENTS):
            a = TAU * i / SEGMENTS
            ring.append(len(verts))
            verts.append(Vector((r * math.cos(a), r * math.sin(a), z)))
        rings.append(ring)
    faces = []
    span = len(rings) if closed else len(rings) - 1
    for k in range(span):
        a_ring = rings[k]
        b_ring = rings[(k + 1) % len(rings)]
        for i in range(SEGMENTS):
            j = (i + 1) % SEGMENTS
            faces.append((a_ring[i], a_ring[j], b_ring[j], b_ring[i]))
    if not closed:
        faces.append(tuple(reversed(rings[0])))
        faces.append(tuple(rings[-1]))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(material)
    return obj


def _stave_lathe(
    name: str,
    profile: list[tuple[float, float]],
    mats: tuple[bpy.types.Material, bpy.types.Material],
) -> bpy.types.Object:
    obj = _lathe(name, profile, mats[0])
    obj.data.materials.append(mats[1])
    for poly in obj.data.polygons:
        c = poly.center
        if math.hypot(c.x, c.y) < 1e-5:
            poly.material_index = 0
            continue
        a = math.atan2(c.y, c.x) % TAU
        seg = int(a / (TAU / SEGMENTS))
        poly.material_index = 0 if seg % 2 == 0 else 1
    return obj


def _build() -> bpy.types.Object:
    oak = studio.mat("WoodOak", (0.52, 0.35, 0.17), 0.74)
    oak_dk = studio.mat("WoodOakDk", (0.41, 0.27, 0.13), 0.80)
    iron = studio.mat("WoodIron", (0.19, 0.19, 0.20), 0.38, spec=0.30, metal=0.50)
    bung_mat = studio.mat("WoodBung", (0.34, 0.23, 0.12), 0.70)

    root = bpy.data.objects.new("WoodenBarrel", None)
    bpy.context.collection.objects.link(root)

    body = _stave_lathe("WoodBody", PROFILE, (oak, oak_dk))
    body.parent = root

    for i, (z0, z1, rb) in enumerate(HOOPS):
        hoop = _lathe(
            "WoodHoop_%d" % i,
            [(rb - 0.004, z0), (rb + 0.007, z0), (rb + 0.007, z1), (rb - 0.004, z1)],
            iron,
            closed=True,
        )
        hoop.parent = root

    bung = _lathe(
        "WoodBung",
        [(0.021, 0.490), (0.021, 0.514), (0.013, 0.523)],
        bung_mat,
    )
    bung.location = Vector((0.086, 0.0, 0.0))
    bung.parent = root

    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.25))
    studio.shoot_turnaround(look, dist=1.15, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.40)
    studio.shoot_iso(look, ISO_PATH, Vector((0.80, -1.00, 0.80)))
    studio.export_glb("WoodenBarrel", GLB_PATH)
    print("LOOK_WOOD_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_WOOD_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_WOOD_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_WOOD_FAIL", exc, file=sys.stderr)
        raise
