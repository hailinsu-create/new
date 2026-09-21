#!/usr/bin/env python3
"""Headless WWII spare tire / truck wheel — Look stream art study.

Deterministic. No GUI. Fat rubber tire + iron hub with lug bolts. Distinct from
jerry can and oil drum: top-down iso must read as a wheel (ring + hub), not a
drum or can.

    blender-headless --python ambush_loop/ArtSource/build_spare_tire.py

Writes (next to this script):
  spare_tire.glb
  spare_tire_turnaround.png
  spare_tire_iso.png
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
GLB_PATH = os.path.join(OUT_DIR, "spare_tire.glb")
PNG_PATH = os.path.join(OUT_DIR, "spare_tire_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "spare_tire_iso.png")

TAU = math.pi * 2.0
SEGMENTS = 28
LUGS = 6
# Tire sits upright on Z; outer radius ~0.22, width ~0.12.
OUTER_R = 0.22
INNER_R = 0.14
RIM_R = 0.135
HUB_R = 0.055
WIDTH = 0.12


def _torus_shell(
    name: str,
    outer_r: float,
    inner_r: float,
    half_w: float,
    material: bpy.types.Material,
    z0: float = 0.0,
) -> bpy.types.Object:
    """Approximate tire as a lathed rectangle ring (no true torus needed)."""
    mesh = bpy.data.meshes.new(name + "Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    # Profile rings: outer face, tread outer, tread inner, inner face — top then bottom.
    rings_r = [outer_r, outer_r, inner_r, inner_r]
    rings_z = [z0 + half_w, z0 - half_w, z0 - half_w, z0 + half_w]
    verts: list[Vector] = []
    ring_idx: list[list[int]] = []
    for r, z in zip(rings_r, rings_z):
        ri = []
        for i in range(SEGMENTS):
            a = TAU * i / SEGMENTS
            ri.append(len(verts))
            verts.append(Vector((r * math.cos(a), r * math.sin(a), z)))
        ring_idx.append(ri)
    faces: list[tuple[int, ...]] = []
    for k in range(len(ring_idx)):
        a_ring = ring_idx[k]
        b_ring = ring_idx[(k + 1) % len(ring_idx)]
        for i in range(SEGMENTS):
            j = (i + 1) % SEGMENTS
            faces.append((a_ring[i], a_ring[j], b_ring[j], b_ring[i]))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(material)
    return obj


def _disc(
    name: str,
    radius: float,
    half_h: float,
    loc: Vector,
    material: bpy.types.Material,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    verts: list[Vector] = [Vector((0.0, 0.0, -half_h)), Vector((0.0, 0.0, half_h))]
    bot = []
    top = []
    for i in range(SEGMENTS):
        a = TAU * i / SEGMENTS
        c, s = math.cos(a) * radius, math.sin(a) * radius
        bot.append(len(verts))
        verts.append(Vector((c, s, -half_h)))
        top.append(len(verts))
        verts.append(Vector((c, s, half_h)))
    faces: list[tuple[int, ...]] = []
    for i in range(SEGMENTS):
        j = (i + 1) % SEGMENTS
        faces.append((0, bot[j], bot[i]))
        faces.append((1, top[i], top[j]))
        faces.append((bot[i], bot[j], top[j], top[i]))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj.location = loc
    mesh.materials.append(material)
    return obj


def _cyl(
    name: str,
    radius: float,
    height: float,
    loc: Vector,
    material: bpy.types.Material,
    segments: int = 12,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    hz = height * 0.5
    verts: list[Vector] = []
    for i in range(segments):
        a = TAU * i / segments
        verts.append(Vector((math.cos(a) * radius, math.sin(a) * radius, -hz)))
    for i in range(segments):
        a = TAU * i / segments
        verts.append(Vector((math.cos(a) * radius, math.sin(a) * radius, hz)))
    faces: list[tuple[int, ...]] = []
    for i in range(segments):
        j = (i + 1) % segments
        faces.append((i, j, segments + j, segments + i))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple(range(segments, segments * 2)))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj.location = loc
    mesh.materials.append(material)
    return obj


def _build() -> bpy.types.Object:
    rubber = studio.mat("TireRubber", (0.06, 0.06, 0.055), 0.88, spec=0.04, metal=0.0)
    rubber_dk = studio.mat("TireRubberDk", (0.04, 0.04, 0.038), 0.92, spec=0.03)
    iron = studio.mat("TireIron", (0.22, 0.20, 0.16), 0.42, spec=0.28, metal=0.55)
    iron_dk = studio.mat("TireIronDk", (0.12, 0.11, 0.09), 0.50, spec=0.22, metal=0.48)
    rust = studio.mat("TireRust", (0.42, 0.22, 0.10), 0.78, spec=0.10, metal=0.20)

    root = bpy.data.objects.new("SpareTire", None)
    bpy.context.collection.objects.link(root)

    tire = _torus_shell("TireBody", OUTER_R, INNER_R, WIDTH * 0.5, rubber)
    tire.parent = root

    # Tread ribs on the outer equator (boxes jutting out slightly).
    for i in range(16):
        a = TAU * i / 16.0
        rib = studio.box(
            "Tread_%d" % i,
            Vector((0.018, 0.010, WIDTH * 0.72)),
            Vector((math.cos(a) * (OUTER_R + 0.006), math.sin(a) * (OUTER_R + 0.006), 0.0)),
            rubber_dk,
        )
        rib.rotation_euler = (0.0, 0.0, a)
        rib.parent = root

    rim = _torus_shell("RimRing", RIM_R, HUB_R + 0.012, WIDTH * 0.28, iron)
    rim.parent = root

    hub = _disc("Hub", HUB_R, WIDTH * 0.22, Vector((0.0, 0.0, 0.0)), iron_dk)
    hub.parent = root

    # Center cap.
    cap = _disc("HubCap", HUB_R * 0.55, WIDTH * 0.10, Vector((0.0, 0.0, WIDTH * 0.18)), iron)
    cap.parent = root

    # Lug bolts on a bolt circle.
    bolt_r = HUB_R * 0.72
    for i in range(LUGS):
        a = TAU * i / LUGS + 0.12
        lug = _cyl(
            "Lug_%d" % i,
            0.008,
            WIDTH * 0.55,
            Vector((math.cos(a) * bolt_r, math.sin(a) * bolt_r, WIDTH * 0.12)),
            rust if i % 2 == 0 else iron,
            segments=8,
        )
        lug.parent = root

    # Valve stem — small nipple on the rim.
    valve = _cyl(
        "Valve",
        0.006,
        0.028,
        Vector((RIM_R * 0.92, 0.0, WIDTH * 0.22)),
        iron_dk,
        segments=8,
    )
    valve.parent = root

    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.0))
    studio.shoot_turnaround(look, dist=0.85, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.18)
    studio.shoot_iso(look, ISO_PATH, Vector((0.55, -0.70, 0.55)))
    studio.export_glb("SpareTire", GLB_PATH)
    print("LOOK_TIRE_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_TIRE_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_TIRE_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_TIRE_FAIL", exc, file=sys.stderr)
        raise
