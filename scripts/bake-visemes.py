#!/usr/bin/env python3
"""Bake 8 line-art viseme mouth patches from the original 墨汐 lip geometry.

The rest pose traces the painted smile (thin dark stroke, slight tilt).
Open visemes deform that same lip pair — not an ellipse sticker.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "public/characters/moxi/visemes"
SHEET = ROOT / "public/characters/moxi/visemes/sheet.png"

# Local pixels, origin at the mouth landmark. Matches src/avatar/rig.ts paintLipMesh.
W, H = 160, 120
CX, CY = 80, 52
SCALE = 4  # supersample

LIP_LINE = (58, 34, 38, 255)
LIP_FILL = (92, 48, 54, 230)
LIP_SOFT = (110, 62, 66, 160)
INNER = (36, 16, 20, 255)
INNER_DEEP = (22, 10, 14, 255)
TEETH = (244, 236, 230, 235)
TONGUE = (176, 96, 104, 210)
CORNER = (42, 24, 28, 255)

SHAPES = {
    "rest": {"open": 0.00, "width": 1.00, "round": 0.00, "teeth": 0.00, "tongue": 0.00, "closed": 0.00, "curve": 0.28},
    "A":    {"open": 0.94, "width": 1.16, "round": 0.18, "teeth": 0.12, "tongue": 0.08, "closed": 0.00, "curve": 0.12},
    "E":    {"open": 0.46, "width": 1.22, "round": 0.06, "teeth": 0.42, "tongue": 0.10, "closed": 0.00, "curve": 0.18},
    "I":    {"open": 0.20, "width": 1.30, "round": 0.00, "teeth": 0.62, "tongue": 0.05, "closed": 0.00, "curve": 0.22},
    "O":    {"open": 0.72, "width": 0.70, "round": 0.88, "teeth": 0.06, "tongue": 0.04, "closed": 0.00, "curve": 0.08},
    "U":    {"open": 0.36, "width": 0.52, "round": 1.00, "teeth": 0.00, "tongue": 0.00, "closed": 0.00, "curve": 0.04},
    "M":    {"open": 0.00, "width": 0.88, "round": 0.22, "teeth": 0.00, "tongue": 0.00, "closed": 1.00, "curve": 0.06},
    "F":    {"open": 0.14, "width": 1.04, "round": 0.05, "teeth": 0.82, "tongue": 0.00, "closed": 0.28, "curve": 0.04},
}

ORDER = ["rest", "A", "E", "I", "O", "U", "M", "F"]


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def paint(shape: dict, gain: float = 1.0) -> Image.Image:
    sw, sh = W * SCALE, H * SCALE
    cx, cy = CX * SCALE, CY * SCALE
    g = gain * SCALE
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    open_ = shape["open"]
    width = shape["width"]
    round_ = shape["round"]
    teeth = shape["teeth"]
    tongue = shape["tongue"]
    closed = shape["closed"]
    curve = shape["curve"]

    half = (21.5 * width + open_ * 3.4) * g
    corner = -curve * 5.4 * g
    upper = (-1.4 - curve * 1.6 - open_ * 3.2 * (1 - round_ * 0.4)) * g
    lower = (1.6 + open_ * (13.2 - round_ * 3.4)) * g

    # Lips only — runtime paints a tight skin cover so we don't stamp a visible oval.
    is_closed = closed > 0.65 or open_ < 0.1
    if is_closed:
        dip = 6.4 * curve * g
        press = 1.2 + closed * 0.8
        pts = []
        for i in range(33):
            t = i / 32
            # quadratic: corners up, middle down (smile)
            x = -half + 2 * half * t
            y = corner * (1 - t) + dip * 2 * t * (1 - t) * 2 + corner * 0.72 * t
            # slight original tilt is applied at draw time; keep a hint here
            y += -x * 0.04
            pts.append((cx + x, cy + y))
        d.line(pts, fill=LIP_LINE, width=max(2, int(1.7 * press * SCALE)), joint="curve")
        if curve > 0.18:
            # tiny lower-lip shade, original has a whisper of volume
            shade = [(x, y + 1.4 * SCALE) for x, y in pts[4:-4]]
            d.line(shade, fill=LIP_SOFT, width=max(1, int(0.9 * SCALE)))
        out = img.resize((W, H), Image.Resampling.LANCZOS)
        return out.filter(ImageFilter.GaussianBlur(0.35))

    if round_ > 0.5:
        rx = (5.6 * width + open_ * 4.0) * g
        ry = (4.4 + open_ * 9.6) * g
        lip_t = max(2, int((2.1 + round_ * 0.6) * SCALE))
        # outer lip flesh
        d.ellipse([cx - rx - lip_t, cy - ry - lip_t * 0.6 + 2 * SCALE, cx + rx + lip_t, cy + ry + lip_t * 0.8 + 2 * SCALE], fill=LIP_FILL)
        # cavity
        d.ellipse([cx - rx * 0.78, cy - ry * 0.62 + 3 * SCALE, cx + rx * 0.78, cy + ry * 0.78 + 3 * SCALE], fill=INNER)
        d.ellipse(
            [cx - rx * 0.52, cy - ry * 0.28 + 4 * SCALE, cx + rx * 0.52, cy + ry * 0.48 + 4 * SCALE],
            fill=INNER_DEEP,
        )
        if teeth > 0.08:
            tw = rx * 0.7
            th = 1.8 * SCALE
            d.ellipse([cx - tw, cy - ry * 0.42 + 1.2 * SCALE, cx + tw, cy - ry * 0.42 + 1.2 * SCALE + th * 2], fill=TEETH)
        # lip ring stroke
        d.ellipse(
            [cx - rx - lip_t * 0.15, cy - ry + 2 * SCALE, cx + rx + lip_t * 0.15, cy + ry + 2 * SCALE],
            outline=LIP_LINE,
            width=max(2, int(1.55 * SCALE)),
        )
        out = img.resize((W, H), Image.Resampling.LANCZOS)
        return out.filter(ImageFilter.GaussianBlur(0.35))

    # Almond / smile-open path
    n = 28
    upper_pts = []
    lower_pts = []
    for i in range(n + 1):
        t = i / n
        x = -half + 2 * half * t
        # upper lip: slight smile + open
        u = corner * math.sin(t * math.pi) * 0.15 + upper * math.sin(t * math.pi) + corner * (1 - math.sin(t * math.pi)) * 0.35
        u += -x * 0.035
        # lower lip
        lo = lower * math.sin(t * math.pi) + corner * (1 - math.sin(t * math.pi)) * 0.25
        lo += -x * 0.035
        upper_pts.append((cx + x, cy + u))
        lower_pts.append((cx + x, cy + lo))

    cavity = upper_pts + list(reversed(lower_pts))
    d.polygon(cavity, fill=INNER)
    # deeper center
    deep_rx = half * 0.52
    deep_ry = max(2 * SCALE, (lower - upper) * 0.28)
    d.ellipse([cx - deep_rx, cy + (upper + lower) * 0.42 - deep_ry, cx + deep_rx, cy + (upper + lower) * 0.42 + deep_ry], fill=INNER_DEEP)

    if teeth > 0.12:
        tw = half * (0.62 + teeth * 0.12)
        th = (1.6 + teeth * 1.4) * SCALE
        ty = cy + upper + 1.2 * SCALE
        d.polygon(
            [
                (cx - tw, ty),
                (cx + tw, ty),
                (cx + tw * 0.88, ty + th),
                (cx - tw * 0.88, ty + th),
            ],
            fill=TEETH,
        )
    if tongue > 0.4:
        tr = half * 0.32
        ty = cy + lower * 0.55
        d.ellipse([cx - tr, ty - tr * 0.45, cx + tr, ty + tr * 0.7], fill=TONGUE)

    d.line(upper_pts, fill=LIP_LINE, width=max(2, int(1.7 * SCALE)), joint="curve")
    d.line(lower_pts, fill=LIP_LINE, width=max(2, int(1.85 * SCALE)), joint="curve")
    # lip flesh just outside the cavity
    d.line([(x, y - 1.1 * SCALE) for x, y in upper_pts], fill=LIP_FILL, width=max(2, int(1.2 * SCALE)), joint="curve")
    d.line([(x, y + 1.3 * SCALE) for x, y in lower_pts], fill=LIP_FILL, width=max(2, int(1.6 * SCALE)), joint="curve")
    out = img.resize((W, H), Image.Resampling.LANCZOS)
    return out.filter(ImageFilter.GaussianBlur(0.35))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    meta = {
        "width": W,
        "height": H,
        "cx": CX,
        "cy": CY,
        "ids": ORDER,
        "note": "Line-art visemes deformed from the original 墨汐 smile. Landmark is layout.face.mouth.",
    }
    patches = []
    for vid in ORDER:
        im = paint(SHAPES[vid], gain=1.0)
        dest = OUT / f"{vid}.png"
        im.save(dest)
        patches.append(im)
        print("wrote", dest)

    # contact sheet
    pad = 8
    sheet = Image.new("RGBA", ((W + pad) * 4 + pad, (H + pad) * 2 + pad), (236, 226, 214, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (vid, im) in enumerate(zip(ORDER, patches)):
        r, c = divmod(i, 4)
        x = pad + c * (W + pad)
        y = pad + r * (H + pad)
        sheet.paste(im, (x, y), im)
        draw.text((x + 4, y + 4), vid, fill=(60, 40, 40, 255))
    sheet.save(SHEET)
    (OUT / "meta.json").write_text(json.dumps(meta, indent=2), encoding="utf8")
    print("sheet", SHEET)


if __name__ == "__main__":
    main()
