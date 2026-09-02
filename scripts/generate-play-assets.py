#!/usr/bin/env python3
"""Generate Play listing graphics and Android adaptive launcher icons."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path("/workspace")
RES = ROOT / "android/app/src/main/res"
STORE = ROOT / "docs/play/assets"
INK = (26, 18, 24, 255)
FOAM = (255, 247, 245, 255)
AMBER = (242, 167, 184, 255)
YELLOW = (245, 196, 72, 255)
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


def draw_window_mark(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill) -> None:
    x0, y0, x1, y1 = box
    w = x1 - x0
    r = max(8, w // 6)
    draw.rounded_rectangle(box, radius=r, fill=fill)
    hole = w // 3
    cx = (x0 + x1) // 2
    cy = y0 + int(w * 0.38)
    draw.ellipse((cx - hole // 2, cy - hole // 2, cx + hole // 2, cy + hole // 2), fill=INK[:3])


def make_legacy_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), INK)
    draw = ImageDraw.Draw(img)
    pad = size // 8
    draw_window_mark(draw, (pad, pad, size - pad, size - pad), YELLOW)
    return img


def make_adaptive_fg(size: int = 432) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    # Safe zone is the inner 66%; keep the glyph inside ~72%.
    pad = int(size * 0.18)
    draw_window_mark(draw, (pad, pad, size - pad, size - pad), YELLOW)
    return img


def make_adaptive_bg(size: int = 432) -> Image.Image:
    return Image.new("RGBA", (size, size), INK)


def make_play_icon() -> Image.Image:
    size = 512
    img = Image.new("RGBA", (size, size), INK)
    draw = ImageDraw.Draw(img)
    pad = 64
    draw_window_mark(draw, (pad, pad, size - pad, size - pad), YELLOW)
    return img


def make_feature_graphic() -> Image.Image:
    img = Image.new("RGB", (1024, 500), INK[:3])
    draw = ImageDraw.Draw(img)
    # Left glyph
    gx0, gy0, gx1, gy1 = 80, 90, 380, 390
    draw.rounded_rectangle((gx0, gy0, gx1, gy1), radius=48, fill=YELLOW)
    hole = 96
    cx, cy = 230, 190
    draw.ellipse((cx - hole // 2, cy - hole // 2, cx + hole // 2, cy + hole // 2), fill=INK[:3])
    title = font(72)
    subtitle = font(28)
    draw.text((430, 150), "旁窗", font=title, fill=FOAM[:3])
    draw.text((430, 250), "屏幕边的扫地僧伴侣", font=subtitle, fill=AMBER[:3])
    draw.text((430, 310), "演示免费  ·  完整陪伴 $0.99", font=font(22), fill=MIST[:3])
    return img


def main() -> None:
    STORE.mkdir(parents=True, exist_ok=True)
    for folder, size in DENSITIES.items():
        dest = RES / folder
        dest.mkdir(parents=True, exist_ok=True)
        make_legacy_icon(size).save(dest / "ic_launcher.png", "PNG")
        make_legacy_icon(size).save(dest / "ic_launcher_round.png", "PNG")

    fg_dir = RES / "drawable"
    fg_dir.mkdir(parents=True, exist_ok=True)
    make_adaptive_fg().save(fg_dir / "ic_launcher_foreground.png", "PNG")
    make_adaptive_bg().save(fg_dir / "ic_launcher_background.png", "PNG")

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)

    play_icon = make_play_icon()
    play_icon.save(STORE / "play_icon_512.png", "PNG")
    make_feature_graphic().save(STORE / "feature_graphic_1024x500.png", "PNG")
    print("wrote launcher icons and", STORE)


if __name__ == "__main__":
    main()
