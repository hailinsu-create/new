#!/usr/bin/env python3
"""Build Cubism-import PNG layers from the master painting.

Produces full-canvas RGBA layers under characters/moxi/cubism/psd-layers/.
FREE Cubism can key at most two parameters per ArtMesh; keep mouth / eyes
as their own layers so ParamMouthOpenY and EyeOpen do not share an object.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path("/workspace")
MASTER = ROOT / "characters/moxi/art/00_master_reference.png"
MASTER_ALPHA = ROOT / "characters/moxi/art/00_master_transparent.png"
PORTRAIT = ROOT / "public/characters/moxi/portrait-rig"
OUT = ROOT / "characters/moxi/cubism/psd-layers"

MOUTH = (753, 401)
MOUTH_TILT = -0.175
SKIN = (231, 205, 189, 255)


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def paint_open_mouth(size: tuple[int, int]) -> Image.Image:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = MOUTH
    cover = (36, 22)
    draw.ellipse(
        (cx - cover[0], cy - cover[1] + 2, cx + cover[0], cy + cover[1] + 8),
        fill=SKIN,
    )
    rx, ry = 11, 13
    draw.ellipse((cx - rx, cy - 2, cx + rx, cy + ry * 2 - 2), fill=(122, 69, 76, 255))
    draw.ellipse(
        (cx - int(rx * 0.68), cy + 2, cx + int(rx * 0.68), cy + int(ry * 1.5)),
        fill=(58, 24, 30, 255),
    )
    teeth = [
        (cx - 7, cy + 1),
        (cx + 7, cy + 1),
        (cx + 6, cy + 5),
        (cx - 6, cy + 5),
    ]
    draw.polygon(teeth, fill=(247, 236, 230, 240))
    draw.ellipse(
        (cx - 5, cy + 10, cx + 5, cy + 16),
        fill=(196, 112, 122, 200),
    )
    return layer.rotate(
        np.degrees(MOUTH_TILT),
        resample=Image.BICUBIC,
        center=MOUTH,
        fillcolor=(0, 0, 0, 0),
    )


def extract_mouth_closed(master: Image.Image) -> Image.Image:
    arr = np.array(master)
    height, width = arr.shape[:2]
    yy, xx = np.ogrid[:height, :width]
    cx, cy = MOUTH
    mask = ((xx - cx) / 34) ** 2 + ((yy - cy) / 22) ** 2 <= 1.0
    out = np.zeros_like(arr)
    out[mask] = arr[mask]
    image = Image.fromarray(out)
    alpha = Image.fromarray((mask * 255).astype(np.uint8))
    image.putalpha(alpha)
    return image.filter(ImageFilter.GaussianBlur(0.4))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    master = load_rgba(MASTER)
    body = load_rgba(PORTRAIT / "base.png")
    alpha = load_rgba(MASTER_ALPHA).split()[-1]
    body.putalpha(alpha)
    eye_l = load_rgba(PORTRAIT / "eye_left.png")
    eye_r = load_rgba(PORTRAIT / "eye_right.png")
    bangs = load_rgba(PORTRAIT / "bangs.png")
    hair = load_rgba(PORTRAIT / "hair_lock.png")
    tassel = load_rgba(PORTRAIT / "tassel.png")

    body.save(OUT / "02_body.png")
    extract_mouth_closed(master).save(OUT / "05_mouth_closed.png")
    paint_open_mouth(master.size).save(OUT / "05_mouth_open.png")
    eye_l.save(OUT / "04_eye_left.png")
    eye_r.save(OUT / "04_eye_right.png")
    bangs.save(OUT / "06_hair_front.png")
    hair.save(OUT / "01_hair_lock.png")
    tassel.save(OUT / "07_tassel.png")

    preview = Image.new("RGBA", master.size, (0, 0, 0, 0))
    for name in (
        "02_body.png",
        "01_hair_lock.png",
        "04_eye_left.png",
        "04_eye_right.png",
        "05_mouth_open.png",
        "06_hair_front.png",
        "07_tassel.png",
    ):
        layer = load_rgba(OUT / name)
        preview = Image.alpha_composite(preview, layer)
    preview.save(OUT / "preview_stack.png")
    print("wrote", OUT)


if __name__ == "__main__":
    main()
