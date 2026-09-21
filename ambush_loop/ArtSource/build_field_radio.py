#!/usr/bin/env python3
"""Headless WWII field radio — Look stream art study.

Deterministic. No GUI. Compact olive-drab transceiver: boxy body with a metal
face plate of dials, a whip antenna, a side handset with a drooping cord, and a
leather carry-strap hint. Art study until a later Look commit wires the iso
into a scene.

    blender-headless --python ambush_loop/ArtSource/build_field_radio.py

Writes (next to this script):
  field_radio.glb
  field_radio_turnaround.png
  field_radio_iso.png
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
GLB_PATH = os.path.join(OUT_DIR, "field_radio.glb")
PNG_PATH = os.path.join(OUT_DIR, "field_radio_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "field_radio_iso.png")

TAU = math.pi * 2.0
SEGMENTS = 16

W, D, H = 0.28, 0.18, 0.22


def _cyl(
    name: str,
    radius: float,
    height: float,
    loc: Vector,
    material: bpy.types.Material,
    segments: int = SEGMENTS,
    axis: str = "Z",
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


def _tube(
    name: str,
    points: list[Vector],
    radius: float,
    material: bpy.types.Material,
    sides: int = 8,
) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name + "Mesh")
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    verts: list[Vector] = []
    rings: list[list[int]] = []
    n = len(points)
    for i, p in enumerate(points):
        if i == 0:
            t = points[1] - points[0]
        elif i == n - 1:
            t = points[-1] - points[-2]
        else:
            t = points[i + 1] - points[i - 1]
        t.normalize()
        up = Vector((0.0, 0.0, 1.0))
        if abs(t.dot(up)) > 0.9:
            up = Vector((1.0, 0.0, 0.0))
        n1 = t.cross(up).normalized()
        n2 = t.cross(n1).normalized()
        ring = []
        for k in range(sides):
            a = TAU * k / sides
            ring.append(len(verts))
            verts.append(p + n1 * (math.cos(a) * radius) + n2 * (math.sin(a) * radius))
        rings.append(ring)
    faces: list[tuple[int, ...]] = []
    for i in range(n - 1):
        for k in range(sides):
            j = (k + 1) % sides
            faces.append((rings[i][k], rings[i][j], rings[i + 1][j], rings[i + 1][k]))
    faces.append(tuple(reversed(rings[0])))
    faces.append(tuple(rings[-1]))
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(material)
    return obj


def _build() -> bpy.types.Object:
    olive = studio.mat("RadioOlive", (0.22, 0.24, 0.14), 0.55, spec=0.16, metal=0.30)
    olive_dk = studio.mat("RadioOliveDk", (0.15, 0.16, 0.09), 0.62, spec=0.14, metal=0.24)
    metal = studio.mat("RadioMetal", (0.24, 0.24, 0.22), 0.34, spec=0.34, metal=0.65)
    iron = studio.mat("RadioIron", (0.14, 0.13, 0.11), 0.38, spec=0.30, metal=0.50)
    dial = studio.mat("RadioDial", (0.08, 0.08, 0.07), 0.30, spec=0.34, metal=0.20)
    leather = studio.mat("RadioStrap", (0.20, 0.12, 0.06), 0.74, spec=0.10)

    root = bpy.data.objects.new("FieldRadio", None)
    bpy.context.collection.objects.link(root)

    body = studio.box("RadioBody", Vector((W, D, H)), Vector((0.0, 0.0, H * 0.5)), olive)
    body.parent = root

    base = studio.box(
        "RadioBase",
        Vector((W + 0.012, D + 0.012, 0.018)),
        Vector((0.0, 0.0, 0.009)),
        olive_dk,
    )
    base.parent = root

    top = studio.box(
        "RadioTop",
        Vector((W + 0.008, D + 0.008, 0.014)),
        Vector((0.0, 0.0, H + 0.007)),
        olive_dk,
    )
    top.parent = root

    face_y = -D * 0.5 - 0.004
    face = studio.box(
        "RadioFace",
        Vector((W - 0.05, 0.008, H - 0.06)),
        Vector((-0.02, face_y, H * 0.5 + 0.005)),
        metal,
    )
    face.parent = root

    dial_z = -D * 0.5 - 0.012
    specs = (
        ("RadioDialBig", 0.030, -0.075, 0.150),
        ("RadioDialMid", 0.021, -0.075, 0.075),
        ("RadioKnobLo", 0.013, 0.010, 0.075),
        ("RadioToggle", 0.009, 0.010, 0.150),
    )
    for name, r, x, z in specs:
        knob = _cyl(name, r, 0.016, Vector((x, dial_z, z)), dial, axis="Y")
        knob.parent = root

    mast_x = W * 0.5 - 0.030
    mast_y = D * 0.5 - 0.030
    collar = _cyl(
        "RadioAntennaBase", 0.009, 0.028, Vector((mast_x, mast_y, H + 0.014)), iron
    )
    collar.parent = root
    mast_h = 0.42
    mast = _cyl(
        "RadioAntenna",
        0.0032,
        mast_h,
        Vector((mast_x, mast_y, H + 0.028 + mast_h * 0.5)),
        metal,
        segments=10,
    )
    mast.parent = root

    grip_x = W * 0.5 + 0.021
    grip = studio.box(
        "RadioHandset", Vector((0.030, 0.048, 0.115)), Vector((grip_x, 0.0, 0.120)), olive_dk
    )
    grip.parent = root
    for i, gz in enumerate((0.066, 0.174)):
        cup = studio.box(
            "RadioHandsetCup_%d" % i,
            Vector((0.036, 0.056, 0.020)),
            Vector((grip_x, 0.0, gz)),
            iron,
        )
        cup.parent = root

    cord_pts = [
        Vector((grip_x + 0.010, 0.0, 0.178)),
        Vector((grip_x + 0.038, 0.0, 0.212)),
        Vector((grip_x + 0.022, 0.0, 0.242)),
        Vector((W * 0.5 - 0.030, 0.0, H + 0.020)),
    ]
    cord = _tube("RadioCord", cord_pts, 0.0042, iron)
    cord.parent = root

    strap_x = -0.060
    strap = studio.box(
        "RadioStrapBar", Vector((0.022, 0.130, 0.010)), Vector((strap_x, 0.0, H + 0.048)), leather
    )
    strap.parent = root
    for i, sy in enumerate((-0.050, 0.050)):
        post = studio.box(
            "RadioStrapPost_%d" % i,
            Vector((0.012, 0.012, 0.048)),
            Vector((strap_x, sy, H + 0.026)),
            leather,
        )
        post.parent = root

    studio.stamp_word(
        root,
        "RADIO",
        iron,
        face_y=-D * 0.5 - 0.009,
        box_w=0.20,
        box_h=0.030,
        origin_z=0.040,
        prefix="RadioStamp",
    )
    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.30))
    studio.shoot_turnaround(look, dist=1.35, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.44)
    studio.shoot_iso(look, ISO_PATH, Vector((0.78, -1.02, 0.86)))
    studio.export_glb("FieldRadio", GLB_PATH)
    print("LOOK_RADIO_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_RADIO_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_RADIO_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_RADIO_FAIL", exc, file=sys.stderr)
        raise
