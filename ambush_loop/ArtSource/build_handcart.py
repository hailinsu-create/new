#!/usr/bin/env python3
"""Headless WWII wooden handcart — Look stream art study.

Deterministic. No GUI. Two-wheel pine cart with plank bed, side rails, and a
pushed handle. Iso must read as cart (wheels + poles), not a crate or pallet.

    blender-headless --python ambush_loop/ArtSource/build_handcart.py

Writes:
  handcart.glb
  handcart_turnaround.png
  handcart_iso.png
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
GLB_PATH = os.path.join(OUT_DIR, "handcart.glb")
PNG_PATH = os.path.join(OUT_DIR, "handcart_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "handcart_iso.png")

TAU = math.pi * 2.0


def _cyl(
    name: str,
    radius: float,
    height: float,
    loc: Vector,
    material: bpy.types.Material,
    segments: int = 16,
    axis: str = "X",
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
    if axis == "X":
        obj.rotation_euler = (0.0, math.pi * 0.5, 0.0)
    elif axis == "Y":
        obj.rotation_euler = (math.pi * 0.5, 0.0, 0.0)
    mesh.materials.append(material)
    return obj


def _build() -> bpy.types.Object:
    pine = studio.mat("CartPine", (0.42, 0.30, 0.14), 0.72, spec=0.08)
    pine_dk = studio.mat("CartPineDk", (0.28, 0.18, 0.08), 0.80, spec=0.06)
    iron = studio.mat("CartIron", (0.16, 0.15, 0.13), 0.40, spec=0.28, metal=0.50)
    rubber = studio.mat("CartRubber", (0.08, 0.08, 0.07), 0.90, spec=0.04)

    root = bpy.data.objects.new("Handcart", None)
    bpy.context.collection.objects.link(root)

    # Bed planks (length along X, width along Y).
    bed = studio.box("CartBed", Vector((0.52, 0.28, 0.028)), Vector((0.0, 0.0, 0.14)), pine)
    bed.parent = root
    for i, ox in enumerate((-0.16, 0.0, 0.16)):
        plank = studio.box(
            "CartPlank_%d" % i,
            Vector((0.14, 0.26, 0.012)),
            Vector((ox, 0.0, 0.162)),
            pine_dk if i % 2 else pine,
        )
        plank.parent = root

    # Side rails.
    for sy in (-1.0, 1.0):
        rail = studio.box(
            "Rail_%s" % ("s" if sy < 0 else "n"),
            Vector((0.50, 0.018, 0.06)),
            Vector((0.0, sy * 0.14, 0.18)),
            pine_dk,
        )
        rail.parent = root
        post_f = studio.box(
            "PostF_%s" % ("s" if sy < 0 else "n"),
            Vector((0.018, 0.018, 0.10)),
            Vector((0.22, sy * 0.14, 0.20)),
            pine,
        )
        post_f.parent = root
        post_b = studio.box(
            "PostB_%s" % ("s" if sy < 0 else "n"),
            Vector((0.018, 0.018, 0.10)),
            Vector((-0.22, sy * 0.14, 0.20)),
            pine,
        )
        post_b.parent = root

    # Axle + two wheels under mid-bed.
    axle = _cyl("Axle", 0.012, 0.34, Vector((0.06, 0.0, 0.08)), iron, axis="Y")
    axle.parent = root
    for i, sy in enumerate((-1.0, 1.0)):
        tire = _cyl(
            "Wheel_%d" % i,
            0.09,
            0.028,
            Vector((0.06, sy * 0.16, 0.08)),
            rubber,
            segments=18,
            axis="Y",
        )
        tire.parent = root
        hub = _cyl(
            "Hub_%d" % i,
            0.028,
            0.034,
            Vector((0.06, sy * 0.16, 0.08)),
            iron,
            segments=12,
            axis="Y",
        )
        hub.parent = root

    # Push handles extending rearward (−X).
    for sy in (-1.0, 1.0):
        pole = studio.box(
            "Handle_%s" % ("s" if sy < 0 else "n"),
            Vector((0.36, 0.016, 0.016)),
            Vector((-0.38, sy * 0.10, 0.22)),
            pine_dk,
        )
        pole.parent = root
    grip = studio.box("Grip", Vector((0.018, 0.22, 0.018)), Vector((-0.55, 0.0, 0.22)), iron)
    grip.parent = root

    # Front nose board.
    nose = studio.box("Nose", Vector((0.02, 0.26, 0.05)), Vector((0.26, 0.0, 0.16)), pine_dk)
    nose.parent = root

    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.14))
    studio.shoot_turnaround(look, dist=1.10, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.28)
    studio.shoot_iso(look, ISO_PATH, Vector((0.85, -1.05, 0.72)))
    studio.export_glb("Handcart", GLB_PATH)
    print("LOOK_CART_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_CART_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_CART_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_CART_FAIL", exc, file=sys.stderr)
        raise
