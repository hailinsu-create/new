#!/usr/bin/env python3
"""Generate Play listing graphics and Android adaptive launcher icons from 墨汐."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path("/workspace")
RES = ROOT / "android/app/src/main/res"
STORE = ROOT / "docs/play/assets"
FACE = STORE / "moxi_face.png"
INK = (26, 18, 24, 255)
FOAM = (255, 247, 245, 255)
AMBER = (242, 167, 184, 255)
MIST = (196, 168, 176, 255)

DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in (
        "/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
        "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            continue
    return ImageFont.load_default()


def cut_face(path: Path) -> Image.Image:
    src = Image.open(path).convert("RGBA")
    pix = src.load()
    w, h = src.size
    key = pix[2, 2][:3]
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            dist = abs(r - key[0]) + abs(g - key[1]) + abs(b - key[2])
            if a < 16 or dist < 36:
                op[x, y] = (0, 0, 0, 0)
            else:
                op[x, y] = (r, g, b, 255)
    return out


def circle_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((1, 1, size - 2, size - 2), fill=255)
    return mask


def face_circle(size: int) -> Image.Image:
    face = cut_face(FACE).resize((size, size), Image.Resampling.LANCZOS)
    alpha = ImageChops.multiply(face.split()[3], circle_mask(size))
    face.putalpha(alpha)
    return face


def make_legacy_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), INK)
    face = face_circle(int(size * 0.92))
    off = (size - face.size[0]) // 2
    img.alpha_composite(face, (off, off))
    return img


def make_adaptive_fg(size: int = 432) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Safe zone is the inner ~66%. Keep the face inside ~72%.
    inner = int(size * 0.72)
    face = face_circle(inner)
    off = (size - inner) // 2
    img.alpha_composite(face, (off, off))
    return img


def make_adaptive_bg(size: int = 432) -> Image.Image:
    return Image.new("RGBA", (size, size), INK)


def make_play_icon() -> Image.Image:
    return make_legacy_icon(512)


def make_feature_graphic() -> Image.Image:
    img = Image.new("RGB", (1024, 500), INK[:3])
    draw = ImageDraw.Draw(img)
    face = face_circle(320)
    img.paste(face, (70, 90), face)
    title = font(72)
    subtitle = font(28)
    draw.text((430, 140), "旁窗", font=title, fill=FOAM[:3])
    draw.text((430, 240), "屏幕边的扫地僧伴侣", font=subtitle, fill=AMBER[:3])
    draw.text((430, 300), "演示免费  ·  完整陪伴 $0.99", font=font(22), fill=MIST[:3])
    return img


def main() -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    if not FACE.exists():
        raise SystemExit("missing docs/play/assets/moxi_face.png")
    for folder, size in DENSITIES.items():
        dest = RES / folder
        dest.mkdir(parents=True, exist_ok=True)
        icon = make_legacy_icon(size)
        icon.save(dest / "ic_launcher.png", "PNG")
        icon.save(dest / "ic_launcher_round.png", "PNG")

    fg_dir = RES / "drawable"
    fg_dir.mkdir(parents=True, exist_ok=True)
    make_adaptive_fg().save(fg_dir / "ic_launcher_foreground.png", "PNG")
    make_adaptive_bg().save(fg_dir / "ic_launcher_background.png", "PNG")

    play_icon = make_play_icon()
    play_icon.save(STORE / "play_icon_512.png", "PNG")
    make_feature_graphic().save(STORE / "feature_graphic_1024x500.png", "PNG")
    print("wrote launcher icons from moxi_face and", STORE)


if __name__ == "__main__":
    main()
