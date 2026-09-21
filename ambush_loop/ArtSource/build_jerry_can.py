#!/usr/bin/env python3
"""Headless WWII jerry can — Look stream art study.

Deterministic. No GUI. Flat rectangular can (distinct from the squat ammo can):
olive body with corner seams, a darker threaded spout, a top handle arch, and an
X-pressed front panel. Art study until a later Look commit wires the iso into a
scene.

    blender-headless --python ambush_loop/ArtSource/build_jerry_can.py

Writes (next to this script):
  jerry_can.glb
  jerry_can_turnaround.png
  jerry_can_iso.png
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
GLB_PATH = os.path.join(OUT_DIR, "jerry_can.glb")
PNG_PATH = os.path.join(OUT_DIR, "jerry_can_turnaround.png")
ISO_PATH = os.path.join(OUT_DIR, "jerry_can_iso.png")

TAU = math.pi * 2.0
SEGMENTS = 20

# Tall and flat: ~0.34 high, 0.22 wide, 0.14 deep.
W, D, H = 0.22, 0.14, 0.34


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


def _build() -> bpy.types.Object:
    olive = studio.mat("JerryOlive", (0.23, 0.25, 0.14), 0.54, spec=0.16, metal=0.30)
    olive_dk = studio.mat("JerryOliveDk", (0.15, 0.17, 0.09), 0.62, spec=0.14, metal=0.22)
    iron = studio.mat("JerryIron", (0.14, 0.13, 0.11), 0.38, spec=0.30, metal=0.50)
    spout = studio.mat("JerrySpout", (0.11, 0.12, 0.08), 0.46, spec=0.22, metal=0.40)
    stencil = studio.mat("JerryStencil", (0.10, 0.12, 0.08), 0.90, spec=0.04)

    root = bpy.data.objects.new("JerryCan", None)
    bpy.context.collection.objects.link(root)

    body = studio.box("JerryBody", Vector((W, D, H)), Vector((0.0, 0.0, H * 0.5)), olive)
    body.parent = root

    top = studio.box(
        "JerryTop", Vector((W - 0.006, D - 0.006, 0.014)), Vector((0.0, 0.0, H + 0.007)), olive_dk
    )
    top.parent = root
    base = studio.box(
        "JerryBase",
        Vector((W + 0.010, D + 0.010, 0.016)),
        Vector((0.0, 0.0, 0.008)),
        olive_dk,
    )
    base.parent = root

    # Rounded-looking corner seams.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            post = _cyl(
                "JerrySeam_%s%s" % ("l" if sx < 0 else "r", "f" if sy < 0 else "b"),
                0.010,
                H - 0.020,
                Vector((sx * (W * 0.5 - 0.006), sy * (D * 0.5 - 0.006), H * 0.5)),
                olive_dk,
            )
            post.parent = root

    # Vertical press ribs on the broad faces.
    for py in (-D * 0.5 - 0.002, D * 0.5 + 0.002):
        for px in (-0.062, 0.062):
            rib = studio.box(
                "JerryRib_%s_%d" % ("f" if py < 0 else "b", 0 if px < 0 else 1),
                Vector((0.012, 0.004, H - 0.10)),
                Vector((px, py, H * 0.5 + 0.015)),
                olive_dk,
            )
            rib.parent = root

    # X-pressed front panel.
    panel_z = H * 0.55
    panel_y = -D * 0.5 - 0.004
    frame = (
        ("JerryPanelTop", Vector((0.150, 0.006, 0.010)), Vector((0.0, panel_y, panel_z + 0.115))),
        ("JerryPanelBot", Vector((0.150, 0.006, 0.010)), Vector((0.0, panel_y, panel_z - 0.115))),
        ("JerryPanelL", Vector((0.010, 0.006, 0.230)), Vector((-0.070, panel_y, panel_z))),
        ("JerryPanelR", Vector((0.010, 0.006, 0.230)), Vector((0.070, panel_y, panel_z))),
    )
    for name, size, loc in frame:
        piece = studio.box(name, size, loc, olive_dk)
        piece.parent = root
    for i, ang in enumerate((0.7854, -0.7854)):
        bar = studio.box(
            "JerryX_%d" % i,
            Vector((0.226, 0.006, 0.014)),
            Vector((0.0, panel_y - 0.001, panel_z)),
            olive_dk,
        )
        bar.rotation_euler = (0.0, ang, 0.0)
        bar.parent = root

    # Handle arch on the lid.
    arch_z = H + 0.050
    for i, ax in enumerate((-0.036, 0.036)):
        post = studio.box(
            "JerryHandlePost_%d" % i,
            Vector((0.014, 0.020, 0.050)),
            Vector((ax, 0.0, H + 0.026)),
            iron,
        )
        post.parent = root
    arch = studio.box(
        "JerryHandle", Vector((0.100, 0.020, 0.013)), Vector((0.0, 0.0, arch_z)), iron
    )
    arch.parent = root

    # Darker threaded spout at a rear corner.
    spout_x = W * 0.5 - 0.045
    spout_y = D * 0.5 - 0.038
    neck = _cyl(
        "JerryNeck", 0.022, 0.048, Vector((spout_x, spout_y, H + 0.024)), spout
    )
    neck.parent = root
    cap = _cyl(
        "JerryCap", 0.026, 0.014, Vector((spout_x, spout_y, H + 0.055)), iron
    )
    cap.parent = root
    collar = _cyl(
        "JerryCollar", 0.028, 0.008, Vector((spout_x, spout_y, H + 0.012)), iron
    )
    collar.parent = root

    studio.stamp_word(
        root,
        "FUEL",
        stencil,
        face_y=-D * 0.5 - 0.006,
        box_w=0.13,
        box_h=0.032,
        origin_z=0.030,
        prefix="JerryStamp",
    )
    bpy.context.view_layer.update()
    return root


def main() -> None:
    studio.clear_scene()
    studio.setup_scene()
    _build()
    studio.lights()
    look = Vector((0.0, 0.0, 0.18))
    studio.shoot_turnaround(look, dist=1.10, out_dir=OUT_DIR, png_path=PNG_PATH, z_lift=0.38)
    studio.shoot_iso(look, ISO_PATH, Vector((0.72, -0.94, 0.82)))
    studio.export_glb("JerryCan", GLB_PATH)
    print("LOOK_JERRY_GLB", GLB_PATH, "bytes", os.path.getsize(GLB_PATH))
    print("LOOK_JERRY_SHEET", PNG_PATH, "bytes", os.path.getsize(PNG_PATH))
    print("LOOK_JERRY_ISO", ISO_PATH, "bytes", os.path.getsize(ISO_PATH))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("LOOK_JERRY_FAIL", exc, file=sys.stderr)
        raise
