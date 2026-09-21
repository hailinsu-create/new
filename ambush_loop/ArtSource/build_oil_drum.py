#!/usr/bin/env python3
"""Headless WWII oil drum — Look stream art study.

Deterministic. No GUI. Compact dented steel 55-gal drum: olive body, darker
rolled top/bottom rims, two belly bands, one pressed front plate with an OIL
stencil. Art study until a later Look commit wires the iso into a scene.

    blender-headless --python ambush_loop/ArtSource/build_oil_drum.py

Writes (next to this script):
  oil_drum.glb
  oil_drum_turnaround.png
  oil_drum_iso.png
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
GLB_PATH = os.path.join(OUT_DIR, "oil_drum.glb")
PNG_PATH = os.path.join(OUT_DIR, "oil_drum_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "oil_drum_iso.png")

TAU = math.pi * 2.0
SEGMENTS = 24
R = 0.17
H = 0.58
BODY_Z = (0.0, 0.13, 0.20, 0.235, 0.29, 0.345, 0.38, 0.45, 0.56)
DENT_Z = 0.29
DENT_Z_FLAT = 0.055
DENT_Z_SPAN = 0.10
DENT_A = -math.pi * 0.5
DENT_A_FLAT = 0.60
DENT_A_SPAN = 0.85
DENT_INSET = 0.145
DENT_DEPTH = 0.025


def _wrap(a: float) -> float:
    while a > math.pi:
        a -= TAU
    while a < -math.pi:
        a += TAU
    return a


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


def _press_front(obj: bpy.types.Object) -> None:
    for v in obj.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if r < 1e-6:
            continue
        da = abs(_wrap(math.atan2(v.co.y, v.co.x) - DENT_A))
        dz = abs(v.co.z - DENT_Z)
        if da <= DENT_A_FLAT and dz <= DENT_Z_FLAT:
            v.co.y = -DENT_INSET
            continue
        if da < DENT_A_SPAN and dz < DENT_Z_SPAN:
            fa = (DENT_A_SPAN - da) / (DENT_A_SPAN - DENT_A_FLAT)
            fz = (DENT_Z_SPAN - dz) / (DENT_Z_SPAN - DENT_Z_FLAT)
            w = min(max(0.0, fa), max(0.0, fz))
            scale = (r - DENT_DEPTH * w) / r
            v.co.x *= scale
            v.co.y *= scale


def _build() -> bpy.types.Object:
    olive = studio.mat("OilOlive", (0.22, 0.24, 0.13), 0.55, spec=0.16, metal=0.22)
    olive_dk = studio.mat("OilOliveDk", (0.13, 0.14, 0.09), 0.62, spec=0.14, metal=0.18)
    iron = studio.mat("OilIron", (0.18, 0.17, 0.14), 0.40, spec=0.28, metal=0.45)
    stencil = studio.mat("OilStencil", (0.11, 0.12, 0.08), 0.90, spec=0.04)

    root = bpy.data.objects.new("OilDrum", None)
    bpy.context.collection.objects.link(root)

    body = _lathe("OilBody", [(R, z) for z in BODY_Z], olive)
    _press_front(body)
    body.parent = root

    rim = _lathe(
        "OilBottomRim",
        [(0.156, 0.0), (0.184, 0.0), (0.184, 0.045), (0.156, 0.045)],
        olive_dk,
        closed=True,
    )
    rim.parent = root

    rim = _lathe(
        "OilTopRim",
        [(0.156, 0.535), (0.184, 0.535), (0.184, 0.58), (0.156, 0.58)],
        olive_dk,
        closed=True,
    )
    rim.parent = root

    for i, z0 in enumerate((0.165, 0.375)):
        band = _lathe(
            "OilBellyBand_%d" % i,
            [(0.16, z0), (0.178, z0), (0.178, z0 + 0.04), (0.16, z0 + 0.04)],
            olive_dk,
            closed=True,
        )
        band.parent = root

    for i, (bx, by) in enumerate(((0.058, 0.030), (-0.050, -0.055))):
        bung = _lathe(
            "OilBung_%d" % i,
            [(0.024, 0.552), (0.024, 0.572), (0.016, 0.580)],
            iron,
        )
        bung.location = Vector((bx, by, 0.0))
        bung.parent = root

    studio.stamp_word(
        root,
        "OIL",
        stencil,
        face_y=-0.1462,
        box_w=0.14,
        box_h=0.05,
        origin_z=0.265,
        prefix="OilStamp",
    )
    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.28))
    studio.shoot_turnaround(look, dist=1.30, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.42)
    studio.shoot_iso(look, ISO_PATH, Vector((0.70, -0.95, 0.78)))
    studio.export_glb("OilDrum", GLB_PATH)
    print("LOOK_OIL_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_OIL_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_OIL_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_OIL_FAIL", exc, file=sys.stderr)
        raise
