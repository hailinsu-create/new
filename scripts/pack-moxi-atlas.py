#!/usr/bin/env python3
"""Fill the Cubism-exported atlas using UV rects from moxi.moc3.

Cubism FREE exported a 2048 atlas with valid UVs but empty alpha.
Blit each PSD layer into its UV rectangle so the 7-quad moc3 can draw.
"""

from __future__ import annotations

from pathlib import Path

from moc3 import Moc3
from PIL import Image

ROOT = Path("/workspace")
MOC = ROOT / "public/models/moxi/moxi.moc3"
ATLAS = ROOT / "public/models/moxi/moxi.2048/texture_00.png"
LAYERS = ROOT / "characters/moxi/cubism/psd-layers"

LAYER_PNG = {
    "tassel": "07_tassel.png",
    "hair_front": "06_hair_front.png",
    "mouth_open": "05_mouth_open.png",
    "eye_right": "04_eye_right.png",
    "eye_left": "04_eye_left.png",
    "hair_lock": "01_hair_lock.png",
    "body": "02_body.png",
}

ATLAS_SIZE = 2048


def uv_pixels(uvs: list[float]) -> tuple[int, int, int, int]:
    us = uvs[0::2]
    vs = uvs[1::2]
    x0 = int(round(min(us) * ATLAS_SIZE))
    x1 = int(round(max(us) * ATLAS_SIZE))
    y0 = int(round(min(vs) * ATLAS_SIZE))
    y1 = int(round(max(vs) * ATLAS_SIZE))
    x0 = max(0, min(ATLAS_SIZE - 1, x0))
    y0 = max(0, min(ATLAS_SIZE - 1, y0))
    x1 = max(x0 + 1, min(ATLAS_SIZE, x1))
    y1 = max(y0 + 1, min(ATLAS_SIZE, y1))
    return x0, y0, x1, y1


def main() -> None:
    moc = Moc3.from_file(MOC)
    ids = moc.art_mesh_ids
    uv = moc["uv.xys"]
    begins = moc["art_mesh.uv_begin_indices"]

    atlas = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (0, 0, 0, 0))
    for i, name in enumerate(ids):
        png_name = LAYER_PNG[name]
        src = Image.open(LAYERS / png_name).convert("RGBA")
        bbox = src.getbbox()
        if bbox:
            src = src.crop(bbox)
        start = begins[i]
        rect_uv = uv[start : start + 8]
        x0, y0, x1, y1 = uv_pixels(rect_uv)
        w, h = x1 - x0, y1 - y0
        # Cubism auto-layout may rotate a wide layer into a tall atlas slot.
        if (src.size[0] > src.size[1]) != (w > h):
            src = src.transpose(Image.Transpose.ROTATE_270)
        fitted = src.resize((w, h), Image.Resampling.LANCZOS)
        atlas.alpha_composite(fitted, (x0, y0))
        print(f"{name:12} atlas ({x0:4},{y0:4})-({x1:4},{y1:4}) {w}x{h}  src {src.size}")

    ATLAS.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(ATLAS)
    print("wrote", ATLAS, ATLAS.stat().st_size)


if __name__ == "__main__":
    main()
