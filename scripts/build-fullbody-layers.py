#!/usr/bin/env python3
"""Split the 墨汐 full-body plate into canvas-sized transparent layers."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "public/characters/moxi/fullbody-rig/plate.png"
OUT = ROOT / "public/characters/moxi/fullbody-rig"

W, H = 1536, 2304

# Tuned against the generated standing plate.
META = {
    "width": W,
    "height": H,
    "eyeLeft": {"cx": 686, "cy": 292, "box": [648, 266, 728, 320]},
    "eyeRight": {"cx": 792, "cy": 270, "box": [754, 244, 840, 300]},
    "mouth": {"cx": 756, "cy": 354, "box": [722, 342, 792, 368]},
    "head": {"cx": 750, "cy": 270, "box": [560, 39, 1000, 470]},
    "bangs": {"cx": 750, "cy": 155, "box": [620, 70, 940, 300]},
    "hairLock": {"cx": 560, "cy": 300, "box": [470, 210, 660, 540]},
    "crane": {"cx": 850, "cy": 545, "box": [810, 515, 900, 585]},
    "tassel": {"cx": 760, "cy": 880, "box": [710, 820, 820, 1040]},
    "shawlLeft": {"cx": 500, "cy": 720, "box": [337, 560, 620, 1720]},
    "shawlRight": {"cx": 1080, "cy": 700, "box": [900, 540, 1291, 1720]},
    "skirt": {"cx": 770, "cy": 820, "box": [560, 790, 980, 1780]},
    "hem": {"cx": 770, "cy": 1580, "box": [560, 1480, 1000, 1800]},
    "hip": {"cx": 770, "cy": 820},
    "plant": {"cx": 800, "cy": 2240},
    "skin": [247, 223, 207],
}


def blank() -> Image.Image:
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def copy_box(src: Image.Image, box: list[int], feather: int = 0) -> Image.Image:
    out = blank()
    x0, y0, x1, y1 = box
    crop = src.crop((x0, y0, x1, y1))
    if feather:
        mask = Image.new("L", crop.size, 0)
        d = ImageDraw.Draw(mask)
        d.rectangle([feather, feather, crop.size[0] - feather - 1, crop.size[1] - feather - 1], fill=255)
        mask = mask.filter(ImageFilter.GaussianBlur(feather))
        crop = crop.copy()
        a = crop.split()[3]
        crop.putalpha(ImageChops.multiply(a, mask))
    out.paste(crop, (x0, y0), crop)
    return out


def extract_color_region(
    src: Image.Image,
    predicate,
    seed_boxes: list[list[int]],
    feather: float = 2,
) -> Image.Image:
    px = src.load()
    mark = Image.new("L", (W, H), 0)
    mp = mark.load()
    from collections import deque

    q: deque[tuple[int, int]] = deque()
    seen = bytearray(W * H)

    def idx(x: int, y: int) -> int:
        return y * W + x

    for x0, y0, x1, y1 in seed_boxes:
        for y in range(max(0, y0), min(H, y1), 2):
            for x in range(max(0, x0), min(W, x1), 2):
                r, g, b, a = px[x, y]
                if a < 80:
                    continue
                if predicate(r, g, b, a):
                    q.append((x, y))
                    seen[idx(x, y)] = 1

    while q:
        x, y = q.popleft()
        r, g, b, a = px[x, y]
        if a < 40 or not predicate(r, g, b, a):
            continue
        mp[x, y] = 255
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and not seen[idx(nx, ny)]:
                seen[idx(nx, ny)] = 1
                q.append((nx, ny))

    if feather:
        mark = mark.filter(ImageFilter.MaxFilter(3))
        mark = mark.filter(ImageFilter.GaussianBlur(feather))
    out = blank()
    out.paste(src, (0, 0), mark)
    return out


def is_gray_cloth(r: int, g: int, b: int, a: int) -> bool:
    if a < 80:
        return False
    mx, mn = max(r, g, b), min(r, g, b)
    if mx - mn > 38:
        return False
    lum = (r + g + b) / 3
    return 38 < lum < 178


def is_skirt(r: int, g: int, b: int, a: int) -> bool:
    if a < 80:
        return False
    lum = (r + g + b) / 3
    # black qipao
    if lum < 55 and mx_diff(r, g, b) < 28:
        return True
    # teal lining / piping
    if 30 < r < 110 and 70 < g < 160 and 80 < b < 175 and g > r + 8 and b > r:
        return True
    return False


def mx_diff(r: int, g: int, b: int) -> int:
    return max(r, g, b) - min(r, g, b)


def is_teal_tassel(r: int, g: int, b: int, a: int) -> bool:
    if a < 80:
        return False
    return 20 < r < 120 and 60 < g < 160 and 80 < b < 180 and g > r + 15 and b > r + 10


def is_white_crane(r: int, g: int, b: int, a: int) -> bool:
    if a < 80:
        return False
    # origami paper is near-white; skip peach skin
    return r > 200 and g > 198 and b > 195 and abs(r - g) < 16 and abs(g - b) < 16


def is_hair(r: int, g: int, b: int, a: int) -> bool:
    if a < 80:
        return False
    lum = (r + g + b) / 3
    if lum > 170:
        return False
    # dark teal / cyan tips
    if b > r + 8 and g > r and lum < 140:
        return True
    if lum < 70 and b >= g:
        return True
    return False


def main() -> None:
    src = Image.open(SRC).convert("RGBA")
    assert src.size == (W, H), src.size
    OUT.mkdir(parents=True, exist_ok=True)

    eye_l = copy_box(src, META["eyeLeft"]["box"], feather=6)
    eye_r = copy_box(src, META["eyeRight"]["box"], feather=6)
    bangs = extract_color_region(
        src,
        is_hair,
        [META["bangs"]["box"]],
        feather=1.6,
    )
    # keep bangs in the upper face only
    bangs_mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(bangs_mask).rectangle(META["bangs"]["box"], fill=255)
    bangs_mask = bangs_mask.filter(ImageFilter.GaussianBlur(18))
    ba = bangs.split()[3]
    bangs.putalpha(ImageChops.multiply(ba, bangs_mask))

    hair_lock = extract_color_region(
        src,
        is_hair,
        [META["hairLock"]["box"]],
        feather=1.4,
    )
    lock_mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(lock_mask).rectangle(META["hairLock"]["box"], fill=255)
    lock_mask = lock_mask.filter(ImageFilter.GaussianBlur(14))
    hair_lock.putalpha(ImageChops.multiply(hair_lock.split()[3], lock_mask))

    shawl_l = extract_color_region(
        src,
        is_gray_cloth,
        [[337, 580, 580, 1720]],
        feather=1.2,
    )
    shawl_r = extract_color_region(
        src,
        is_gray_cloth,
        [[980, 540, 1291, 1720]],
        feather=1.2,
    )

    def gate_layer(layer: Image.Image, box: list[int], blur: int) -> Image.Image:
        fade = Image.new("L", (W, H), 0)
        ImageDraw.Draw(fade).rectangle(box, fill=255)
        fade = fade.filter(ImageFilter.GaussianBlur(blur))
        layer.putalpha(ImageChops.multiply(layer.split()[3], fade))
        return layer

    shawl_l = gate_layer(shawl_l, [337, 560, 640, 1740], 18)
    shawl_r = gate_layer(shawl_r, [900, 530, 1291, 1760], 18)

    skirt = extract_color_region(
        src,
        is_skirt,
        [[560, 800, 1000, 1785]],
        feather=1.0,
    )
    skirt_gate = Image.new("L", (W, H), 0)
    ImageDraw.Draw(skirt_gate).rectangle([520, 790, 1040, 1810], fill=255)
    skirt_gate = skirt_gate.filter(ImageFilter.GaussianBlur(12))
    skirt.putalpha(ImageChops.multiply(skirt.split()[3], skirt_gate))

    hem = extract_color_region(
        src,
        is_skirt,
        [META["hem"]["box"]],
        feather=1.2,
    )
    hem_gate = Image.new("L", (W, H), 0)
    ImageDraw.Draw(hem_gate).rectangle(META["hem"]["box"], fill=255)
    hem_gate = hem_gate.filter(ImageFilter.GaussianBlur(18))
    hem.putalpha(ImageChops.multiply(hem.split()[3], hem_gate))

    tassel = extract_color_region(
        src,
        is_teal_tassel,
        [META["tassel"]["box"]],
        feather=1.0,
    )
    crane = copy_box(src, META["crane"]["box"], feather=4)

    legs = blank()
    legs.paste(src.crop((560, 1760, 1120, 2268)), (560, 1760))
    fade = Image.new("L", (W, H), 0)
    ImageDraw.Draw(fade).rectangle([560, 1820, 1120, 2268], fill=255)
    fade = fade.filter(ImageFilter.GaussianBlur(20))
    legs.putalpha(ImageChops.multiply(src.split()[3], fade))

    eye_l.save(OUT / "eye_left.png")
    eye_r.save(OUT / "eye_right.png")
    bangs.save(OUT / "bangs.png")
    hair_lock.save(OUT / "hair_lock.png")
    shawl_l.save(OUT / "shawl_left.png")
    shawl_r.save(OUT / "shawl_right.png")
    skirt.save(OUT / "skirt.png")
    hem.save(OUT / "hem.png")
    tassel.save(OUT / "tassel.png")
    crane.save(OUT / "crane.png")
    legs.save(OUT / "legs.png")
    (OUT / "meta.json").write_text(json.dumps(META, indent=2, ensure_ascii=False) + "\n")

    def stats(name: str, im: Image.Image) -> None:
        bb = im.getbbox()
        print(f"{name:12} bbox={bb}")

    for name in [
        "plate",
        "eye_left",
        "eye_right",
        "bangs",
        "hair_lock",
        "shawl_left",
        "shawl_right",
        "skirt",
        "hem",
        "tassel",
        "crane",
        "legs",
    ]:
        stats(name, Image.open(OUT / f"{name}.png"))


if __name__ == "__main__":
    main()
