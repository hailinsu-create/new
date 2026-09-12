#!/usr/bin/env python3
"""Circle-crop harvested Live2D shots (or moxi_face) into 192px fallbacks."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

OUT = Path("/workspace/android/app/src/main/res/drawable-xxhdpi")
HARVEST = Path("/tmp/pangchuang-fallbacks")
FACE = Path("/workspace/docs/play/assets/moxi_face.png")
SIZE = 192

KEEP = {
    "companion_avatar_idle.png",
    "companion_avatar_talk.png",
    "companion_avatar_happy.png",
    "companion_avatar_surprise.png",
}

ALIASES = {
    "companion_avatar_think.png": "companion_avatar_idle.png",
    "companion_avatar_care.png": "companion_avatar_happy.png",
    "companion_avatar_shy.png": "companion_avatar_happy.png",
}

DELETE = {
    "companion_avatar_blink.png",
    "companion_avatar_mouth_mid.png",
    "companion_avatar_mouth_open.png",
}


def cut_dark_bg(src: Image.Image) -> Image.Image:
    src = src.convert("RGBA")
    pix = src.load()
    w, h = src.size
    key = pix[2, 2][:3]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            dist = abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2])
            if a < 12 or (r + g + b < 48 and dist < 40):
                op[x, y] = (0, 0, 0, 0)
            else:
                op[x, y] = (r, g, b, 255)
    return out


def circle(im: Image.Image, size: int) -> Image.Image:
    im = im.convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((1, 1, size - 2, size - 2), fill=255)
    alpha = im.split()[3]
    im.putalpha(ImageChops.multiply(alpha, mask))
    return im


def from_face() -> Image.Image:
    return circle(cut_dark_bg(Image.open(FACE)), SIZE)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    fallback = from_face()
    used_hashes = {}
    for name in KEEP:
        src = HARVEST / name
        if src.exists():
            im = circle(cut_dark_bg(Image.open(src)), SIZE)
            # If harvest is nearly empty (all transparent), fall back to moxi_face.
            extrema = im.split()[3].getextrema()
            if extrema[1] < 16:
                im = fallback.copy()
                print("empty harvest", name, "-> moxi_face")
            else:
                print("using harvest", name)
        else:
            im = fallback.copy()
            print("missing harvest", name, "-> moxi_face")
        dest = OUT / name
        im.save(dest, "PNG")
        used_hashes[name] = dest.read_bytes()

    # Distinctness check: if harvest collapsed to one image, still ship one idle
    unique = {data for data in used_hashes.values()}
    print("unique fallback files", len(unique), "of", len(KEEP))

    for alias, src_name in ALIASES.items():
        data = used_hashes.get(src_name) or fallback.tobytes()
        (OUT / alias).write_bytes(used_hashes[src_name] if src_name in used_hashes else fallback.tobytes())
        print("alias", alias, "->", src_name)

    # Remove the unused mouth/blink copies so we do not pretend they are moods.
    for name in DELETE:
        p = OUT / name
        if p.exists():
            p.unlink()
            print("deleted", name)


if __name__ == "__main__":
    main()
