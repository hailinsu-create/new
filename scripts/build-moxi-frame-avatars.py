#!/usr/bin/env python3
"""Build 墨汐 PNG frame avatars for the Android overlay Plan B engine.

Base art: characters/moxi/cubism/rig/00_full.png (composited bust).
Blink / talk mouths are painted in-place — Cubism FREE eye/mouth mask patches
are intentionally NOT used.

    python3 scripts/build-moxi-frame-avatars.py
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
RIG = ROOT / "characters/moxi/cubism/rig"
OUT = ROOT / "android/app/src/main/res/drawable-xxhdpi"
PREVIEW = ROOT / "assets/moxi-frames"
SIZE = 192
CROP = (520, 340, 1020, 840)


def load_full() -> Image.Image:
    return Image.open(RIG / "00_full.png").convert("RGBA")


def clone_fill(
    im: Image.Image,
    region: tuple[int, int, int, int],
    *,
    src_dy: int = -28,
) -> None:
    """Overwrite an elliptical region by cloning nearby skin pixels (in-place)."""
    x0, y0, x1, y1 = region
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
    px = im.load()
    w, h = im.size
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            nx = (x - cx) / rx
            ny = (y - cy) / ry
            if nx * nx + ny * ny > 1.0:
                continue
            sx, sy = x, y + src_dy
            if 0 <= sx < w and 0 <= sy < h:
                src = px[sx, sy]
                if src[3] > 200:
                    px[x, y] = src


def paint_blink(base: Image.Image) -> Image.Image:
    out = base.copy()
    skin = out.getpixel((780, 610))[:3]
    d = ImageDraw.Draw(out)
    # Amber iris centers measured on 00_full.png
    eyes = [
        (746, 588, 34, 20),
        (865, 585, 36, 21),
    ]
    for cx, cy, rx, ry in eyes:
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(*skin, 255))
        # soft upper lid shade
        shade = tuple(max(c - 18, 0) for c in skin)
        d.ellipse([cx - rx + 2, cy - ry - 1, cx + rx - 2, cy + 2], fill=(*shade, 100))
        d.arc(
            [cx - rx + 2, cy - 4, cx + rx - 2, cy + 12],
            start=18,
            end=162,
            fill=(55, 45, 55, 255),
            width=3,
        )
    return out


def paint_mouth(base: Image.Image, openness: float) -> Image.Image:
    out = base.copy()
    openness = max(0.0, min(1.0, openness))
    # Smile sits left of canvas center (3/4 head turn).
    cx, cy = 752, 690
    clone_fill(out, (cx - 48, cy - 30, cx + 48, cy + 34), src_dy=-26)

    d = ImageDraw.Draw(out)
    if openness < 0.15:
        d.arc([cx - 24, cy - 6, cx + 24, cy + 12], 25, 155, fill=(130, 75, 85, 230), width=2)
        return out

    rw = int(16 + 12 * openness)
    rh = int(4 + 15 * openness)
    d.ellipse([cx - rw, cy - rh, cx + rw, cy + rh], fill=(92, 42, 52, 255))
    d.ellipse(
        [cx - rw + 2, cy - rh + 2, cx + rw - 2, cy + rh - 2],
        fill=(140, 48, 60, 255),
    )
    if openness >= 0.4:
        th = max(2, int(4 * openness))
        d.rectangle(
            [cx - rw + 5, cy - rh + 3, cx + rw - 5, cy - rh + 3 + th],
            fill=(248, 240, 235, 255),
        )
    if openness >= 0.65:
        d.ellipse([cx - 8, cy + 1, cx + 8, cy + rh - 2], fill=(215, 115, 125, 255))
    d.arc(
        [cx - rw + 2, cy - 1, cx + rw - 2, cy + rh],
        5,
        175,
        fill=(200, 120, 130, 200),
        width=2,
    )
    return out


def to_avatar(src: Image.Image, *, blush: float = 0.0, bright: float = 1.0) -> Image.Image:
    bust = src.crop(CROP)
    square = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    bust.thumbnail((SIZE - 4, SIZE - 4), Image.Resampling.LANCZOS)
    ox = (SIZE - bust.width) // 2
    oy = (SIZE - bust.height) // 2 - 2
    square.alpha_composite(bust, (ox, oy))

    if bright != 1.0:
        rgb = ImageEnhance.Brightness(square.convert("RGB")).enhance(bright)
        square = Image.merge("RGBA", (*rgb.split(), square.split()[3]))

    if blush > 0:
        overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(overlay)
        for cx in (62, 130):
            d.ellipse([cx - 13, 98, cx + 13, 120], fill=(220, 95, 115, int(70 * blush)))
        overlay = overlay.filter(ImageFilter.GaussianBlur(3))
        square = Image.alpha_composite(square, overlay)

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).ellipse([1, 1, SIZE - 2, SIZE - 2], fill=255)
    r, g, b, a = square.split()
    a = Image.composite(a, Image.new("L", (SIZE, SIZE), 0), mask)
    return Image.merge("RGBA", (r, g, b, a))


def save(name: str, im: Image.Image) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    PREVIEW.mkdir(parents=True, exist_ok=True)
    path = OUT / f"companion_avatar_{name}.png"
    im.save(path, optimize=True)
    im.save(PREVIEW / f"moxi_{name}.png", optimize=True)
    print(f"wrote {path.relative_to(ROOT)}")


def main() -> None:
    base = load_full()
    save("idle", to_avatar(base))
    save("blink", to_avatar(paint_blink(base)))
    save("talk", to_avatar(base))
    save("mouth_mid", to_avatar(paint_mouth(base, 0.42)))
    save("mouth_open", to_avatar(paint_mouth(base, 0.9)))
    save("surprise", to_avatar(paint_mouth(base, 0.82), bright=1.03))
    save("happy", to_avatar(paint_mouth(base, 0.5), bright=1.04))
    save("think", to_avatar(base, bright=0.94))
    save("care", to_avatar(base, bright=1.02))
    save("shy", to_avatar(base, blush=1.0))

    names = [
        "idle",
        "blink",
        "think",
        "talk",
        "happy",
        "care",
        "surprise",
        "shy",
        "mouth_mid",
        "mouth_open",
    ]
    sheet = Image.new("RGBA", (SIZE * 5 + 24, SIZE * 2 + 24), (18, 28, 36, 255))
    for i, n in enumerate(names):
        im = Image.open(OUT / f"companion_avatar_{n}.png")
        r, c = divmod(i, 5)
        sheet.alpha_composite(im, (12 + c * SIZE, 12 + r * SIZE))
    sheet.convert("RGB").save(PREVIEW / "moxi_frame_sheet.png", quality=92)
    print(f"wrote {PREVIEW.relative_to(ROOT)}/moxi_frame_sheet.png")


if __name__ == "__main__":
    main()
