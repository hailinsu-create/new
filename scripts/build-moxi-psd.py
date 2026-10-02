#!/usr/bin/env python3
"""Build a Cubism-import PSD from the 墨汐 layer PNGs.

Cubism Editor opens this PSD (File > Open). Each named layer becomes an
ArtMesh. Mouth and eyes stay separate so FREE's 2-parameter-per-object
limit can still key ParamMouthOpenY / ParamEyeLOpen / ParamEyeROpen.

The PSD is gitignored under characters/moxi/cubism/import/.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter
from pytoshop import enums
from pytoshop.user.nested_layers import Image as PsdImage
from pytoshop.user.nested_layers import nested_layers_to_psd

ROOT = Path("/workspace")
LAYERS = ROOT / "characters/moxi/cubism/psd-layers"
SHEET = ROOT / "characters/moxi/art/layers_transparent/06_mouth_sheet.png"
MASTER_ALPHA = ROOT / "characters/moxi/art/00_master_transparent.png"
OUT_PSD = ROOT / "characters/moxi/cubism/import/moxi.psd"
WINE_COPY = ROOT / "tools/cubism/wineprefix/drive_c/moxi/moxi.psd"

CANVAS = (1536, 1024)
MOUTH = (753, 401)
MOUTH_TILT_DEG = -10.0
MOUTH_TARGET_W = 34
SKIN = (231, 205, 189, 255)

# Photoshop layer panel: index 0 is the front-most layer.
FRONT_TO_BACK = (
    "07_tassel.png",
    "06_hair_front.png",
    "05_mouth_open.png",
    "04_eye_right.png",
    "04_eye_left.png",
    "01_hair_lock.png",
    "02_body.png",
)

LAYER_NAMES = {
    "07_tassel.png": "tassel",
    "06_hair_front.png": "hair_front",
    "05_mouth_open.png": "mouth_open",
    "04_eye_right.png": "eye_right",
    "04_eye_left.png": "eye_left",
    "01_hair_lock.png": "hair_lock",
    "02_body.png": "body",
}


def chroma_mask(arr: np.ndarray) -> np.ndarray:
    r, g, b, a = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2], arr[:, :, 3]
    green = (g > 180) & (r < 90) & (b < 90)
    return (a > 10) & (~green)


def extract_sheet_mouth() -> Image.Image:
    """Middle-column open mouth from the 2x3 sheet (talk viseme)."""
    arr = np.array(Image.open(SHEET).convert("RGBA"))
    mask = chroma_mask(arr)
    # Bottom row, middle column (see x-runs / y-runs in the sheet).
    cell = mask[637:773, 601:950]
    ys, xs = np.where(cell)
    if len(xs) == 0:
        raise RuntimeError("open mouth cell is empty")
    x0, x1 = int(xs.min()), int(xs.max()) + 1
    y0, y1 = int(ys.min()), int(ys.max()) + 1
    crop = arr[637 + y0 : 637 + y1, 601 + x0 : 601 + x1].copy()
    local = chroma_mask(crop)
    crop[:, :, 3] = np.where(local, crop[:, :, 3], 0)
    return Image.fromarray(crop)


def load_body() -> Image.Image:
    """Portrait-rig base with the painted backdrop knocked out.

    Cubism auto-mesh follows alpha. A solid gray rectangle would become
    one huge ArtMesh and show as a card in the floating window.
    """
    body = Image.open(LAYERS / "02_body.png").convert("RGBA")
    alpha = Image.open(MASTER_ALPHA).convert("RGBA").split()[-1]
    body.putalpha(alpha)
    return body


def paint_mouth_open() -> Image.Image:
    sprite = extract_sheet_mouth()
    scale = MOUTH_TARGET_W / sprite.size[0]
    new_size = (
        max(1, int(round(sprite.size[0] * scale))),
        max(1, int(round(sprite.size[1] * scale))),
    )
    sprite = sprite.resize(new_size, Image.Resampling.LANCZOS)
    sprite = sprite.rotate(
        MOUTH_TILT_DEG,
        resample=Image.Resampling.BICUBIC,
        expand=True,
        fillcolor=(0, 0, 0, 0),
    )

    layer = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    cx, cy = MOUTH
    # Skin cover hides the painted closed mouth on `body` when this layer is shown.
    cover = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    from PIL import ImageDraw

    draw = ImageDraw.Draw(cover)
    draw.ellipse((cx - 22, cy - 10, cx + 22, cy + 16), fill=SKIN)
    cover = cover.filter(ImageFilter.GaussianBlur(0.6))
    layer = Image.alpha_composite(layer, cover)

    x = cx - sprite.size[0] // 2
    y = cy - sprite.size[1] // 2 + 4
    layer.alpha_composite(sprite, (x, y))
    return layer


def alpha_bbox(arr: np.ndarray, pad: int = 2) -> tuple[int, int, int, int]:
    ys, xs = np.where(arr[:, :, 3] > 8)
    if len(xs) == 0:
        return (0, 0, 1, 1)
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(arr.shape[1], int(xs.max()) + 1 + pad)
    y1 = min(arr.shape[0], int(ys.max()) + 1 + pad)
    return x0, y0, x1, y1


def pil_to_psd_image(name: str, image: Image.Image) -> PsdImage:
    arr = np.array(image.convert("RGBA"))
    x0, y0, x1, y1 = alpha_bbox(arr)
    crop = np.ascontiguousarray(arr[y0:y1, x0:x1])
    channels = {
        0: crop[:, :, 0],
        1: crop[:, :, 1],
        2: crop[:, :, 2],
        -1: crop[:, :, 3],
    }
    return PsdImage(
        name=name,
        visible=True,
        opacity=255,
        top=int(y0),
        left=int(x0),
        bottom=int(y1),
        right=int(x1),
        channels=channels,
        color_mode=enums.ColorMode.rgb,
    )


def main() -> None:
    LAYERS.mkdir(parents=True, exist_ok=True)
    mouth = paint_mouth_open()
    mouth.save(LAYERS / "05_mouth_open.png")
    body = load_body()
    body.save(LAYERS / "02_body.png")

    images = {
        "05_mouth_open.png": mouth,
        "02_body.png": body,
    }
    preview = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for filename in reversed(FRONT_TO_BACK):
        layer = images.get(filename)
        if layer is None:
            layer = Image.open(LAYERS / filename).convert("RGBA")
        preview = Image.alpha_composite(preview, layer)
    preview.save(LAYERS / "preview_stack.png")

    psd_layers = []
    for filename in FRONT_TO_BACK:
        image = images.get(filename)
        if image is None:
            image = Image.open(LAYERS / filename).convert("RGBA")
        psd_layers.append(pil_to_psd_image(LAYER_NAMES[filename], image))

    # pytoshop takes size as (width, height) despite the docstring.
    psd = nested_layers_to_psd(
        psd_layers,
        color_mode=enums.ColorMode.rgb,
        compression=enums.Compression.raw,
        size=CANVAS,
    )
    OUT_PSD.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PSD.open("wb") as handle:
        psd.write(handle)

    if WINE_COPY.parent.parent.exists():
        WINE_COPY.parent.mkdir(parents=True, exist_ok=True)
        with WINE_COPY.open("wb") as handle:
            psd.write(handle)

    print("wrote", OUT_PSD, "bytes", OUT_PSD.stat().st_size)
    if WINE_COPY.exists():
        print("wine copy", WINE_COPY)


if __name__ == "__main__":
    main()
