#!/usr/bin/env python3
"""Rebuild Moxi portrait-rig layers from the master painting.

Cleans socket holes, speckles, and dark fringes; extracts hair-only bangs
for destination-out; strips bangs out of the eye cutouts.
"""

from __future__ import annotations

import os
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path("/workspace")
MASTER_PATH = ROOT / "characters/moxi/art/00_master_reference.png"
CURRENT_DIR = ROOT / "public/characters/moxi/portrait-rig"
DESTS = [
    ROOT / "public/characters/moxi/portrait-rig",
    ROOT / "characters/moxi/portrait-rig",
]
DEBUG = Path("/tmp/moxi-inspect")

LEFT_EYE = (657, 307)
RIGHT_EYE = (802, 289)
SKIN = np.array([247, 223, 207], dtype=np.float32)


def box_filter(arr: np.ndarray, radius: int) -> np.ndarray:
    pad = np.pad(arr, radius, mode="edge")
    integral = np.pad(np.cumsum(np.cumsum(pad, 0), 1), ((1, 0), (1, 0)), constant_values=0)
    height, width = arr.shape
    y0 = np.arange(height)
    x0 = np.arange(width)
    y1 = y0 + 2 * radius + 1
    x1 = x0 + 2 * radius + 1
    window = (
        integral[np.ix_(y1, x1)]
        - integral[np.ix_(y0, x1)]
        - integral[np.ix_(y1, x0)]
        + integral[np.ix_(y0, x0)]
    )
    return window / float((2 * radius + 1) ** 2)


def dilate_down(mask: np.ndarray, steps: int = 1) -> np.ndarray:
    current = mask.copy()
    for _ in range(steps):
        nxt = current.copy()
        nxt[1:, :] |= current[:-1, :]
        nxt[:, 1:] |= current[:, :-1]
        nxt[:, :-1] |= current[:, 1:]
        current = nxt
    return current


def inpaint_from(
    rgb: np.ndarray,
    hole: np.ndarray,
    source: np.ndarray,
    radius: int = 8,
    passes: int = 8,
    fallback: np.ndarray | None = None,
) -> np.ndarray:
    work = rgb.astype(np.float32)
    valid = (source & ~hole).astype(np.float32)
    remaining = hole.copy()
    fill_color = SKIN if fallback is None else fallback.astype(np.float32)
    for _ in range(passes):
        density = box_filter(valid, radius)
        filled = np.stack(
            [box_filter(work[:, :, c] * valid, radius) for c in range(3)],
            axis=-1,
        )
        fill = filled / np.maximum(density, 1e-4)[:, :, None]
        take = remaining & (density > 0.06)
        work[take] = fill[take]
        valid[take] = 1.0
        remaining[take] = False
        if not remaining.any():
            break
    if remaining.any():
        work[remaining] = fill_color
    return np.clip(work, 0, 255)


def inpaint_rgb(rgb: np.ndarray, hole: np.ndarray, radius: int = 6, passes: int = 6) -> np.ndarray:
    source = np.ones(rgb.shape[:2], dtype=bool)
    return inpaint_from(rgb, hole, source, radius=radius, passes=passes)


def connected_from(seeds: np.ndarray, allowed: np.ndarray, limit: int = 800) -> np.ndarray:
    current = seeds & allowed
    for _ in range(limit):
        nxt = current.copy()
        nxt[1:, :] |= current[:-1, :]
        nxt[:-1, :] |= current[1:, :]
        nxt[:, 1:] |= current[:, :-1]
        nxt[:, :-1] |= current[:, 1:]
        nxt[1:, 1:] |= current[:-1, :-1]
        nxt[1:, :-1] |= current[:-1, 1:]
        nxt[:-1, 1:] |= current[1:, :-1]
        nxt[:-1, :-1] |= current[1:, 1:]
        nxt &= allowed
        if nxt.sum() == current.sum():
            return nxt
        current = nxt
    return current


def dilate(mask: np.ndarray, steps: int = 1) -> np.ndarray:
    current = mask.copy()
    for _ in range(steps):
        nxt = current.copy()
        nxt[1:, :] |= current[:-1, :]
        nxt[:-1, :] |= current[1:, :]
        nxt[:, 1:] |= current[:, :-1]
        nxt[:, :-1] |= current[:, 1:]
        current = nxt
    return current


def erode(mask: np.ndarray, steps: int = 1) -> np.ndarray:
    return ~dilate(~mask, steps)


def luma(rgb: np.ndarray) -> np.ndarray:
    return (
        0.2126 * rgb[:, :, 0]
        + 0.7152 * rgb[:, :, 1]
        + 0.0722 * rgb[:, :, 2]
    )


def ellipse_mask(
    shape: tuple[int, int],
    cx: float,
    cy: float,
    rx: float,
    ry: float,
) -> np.ndarray:
    height, width = shape
    yy, xx = np.ogrid[:height, :width]
    return ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2 <= 1.0


def hair_like(rgb: np.ndarray) -> np.ndarray:
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    lum = luma(rgb)
    skin = (r > 158) & (g > 128) & (b > 108) & (r + 8 >= g) & (g + 18 >= b)
    dark = (lum < 88) & (np.maximum(np.maximum(r, g), b) < 120)
    teal = (b > r + 6) & (g > r - 4) & (lum < 165) & (lum > 28)
    charcoal = (lum < 55) & (np.abs(r - g) < 18) & (np.abs(g - b) < 22)
    return (dark | teal | charcoal) & ~skin


def defringe(rgba: np.ndarray) -> np.ndarray:
    out = rgba.copy()
    alpha = out[:, :, 3]
    rgb = out[:, :, :3].astype(np.float32)
    lum = luma(out)
    dust = (alpha > 0) & (alpha < 150) & (lum < 32)
    out[dust, 3] = 0
    alpha = out[:, :, 3]
    fringe = (alpha > 0) & (alpha < 220)
    if not fringe.any():
        return out
    opaque = alpha >= 220
    if opaque.any():
        hole = fringe | ~opaque
        filled = inpaint_rgb(out[:, :, :3], hole, radius=3, passes=5)
        out[fringe, :3] = filled[fringe]
    still = (out[:, :, 3] > 0) & (out[:, :, 3] < 90) & (luma(out) < 40)
    out[still, 3] = 0
    return out


def rgba_from(rgb: np.ndarray, alpha_mask: np.ndarray, soft: int = 1) -> np.ndarray:
    alpha = np.zeros(rgb.shape[:2], dtype=np.float32)
    alpha[alpha_mask] = 255
    if soft:
        alpha = box_filter(alpha, soft)
        alpha[alpha_mask] = np.maximum(alpha[alpha_mask], 220)
        alpha[~dilate(alpha_mask, soft + 1)] = 0
    out = np.zeros((rgb.shape[0], rgb.shape[1], 4), dtype=np.uint8)
    out[:, :, :3] = rgb
    out[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    out[~dilate(alpha_mask, soft + 2), :3] = 0
    return defringe(out)


def remove_speckles(rgb: np.ndarray, skin_mask: np.ndarray) -> np.ndarray:
    work = rgb.copy()
    lum = luma(work)
    neighborhood = box_filter(lum, 2)
    darker = skin_mask & (neighborhood > 140) & (lum < neighborhood - 42) & (lum < 110)
    if not darker.any():
        return work
    # keep only tiny islands
    island = darker.copy()
    grown = dilate(island, 1)
    # discard clusters that remain large after a coarse connected count via blur
    density = box_filter(island.astype(np.float32), 2)
    tiny = island & (density < 0.35)
    if tiny.any():
        filled = inpaint_rgb(work, tiny, radius=2, passes=3)
        work[tiny] = filled[tiny]
    return work


def save_png(path: Path, rgba: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(rgba, "RGBA").save(path, optimize=True)
    print(f"wrote {path} ({path.stat().st_size} bytes)")


def main() -> None:
    DEBUG.mkdir(parents=True, exist_ok=True)
    master = np.array(Image.open(MASTER_PATH).convert("RGB"))
    height, width = master.shape[:2]
    current_hair = np.array(Image.open(CURRENT_DIR / "hair_lock.png").convert("RGBA"))
    current_tassel = np.array(Image.open(CURRENT_DIR / "tassel.png").convert("RGBA"))

    lum = luma(master)
    r = master[:, :, 0].astype(np.float32)
    g = master[:, :, 1].astype(np.float32)
    b = master[:, :, 2].astype(np.float32)
    sat = master.max(axis=2).astype(np.float32) - master.min(axis=2).astype(np.float32)

    left_eye = ellipse_mask((height, width), LEFT_EYE[0], LEFT_EYE[1], 50, 36)
    right_eye = ellipse_mask((height, width), RIGHT_EYE[0], RIGHT_EYE[1], 54, 38)
    eyes = left_eye | right_eye
    inner_left = ellipse_mask((height, width), LEFT_EYE[0], LEFT_EYE[1], 34, 22)
    inner_right = ellipse_mask((height, width), RIGHT_EYE[0], RIGHT_EYE[1], 38, 24)
    inner = inner_left | inner_right

    sclera = eyes & (lum > 165) & (sat < 52)
    iris = eyes & (r + 6 > g) & (r > 62) & (lum > 16) & (lum < 175) & (sat > 14)
    highlight = eyes & (lum > 205) & (sat < 55)
    pupil = inner & (lum < 48)
    eyeball = dilate(sclera | iris | highlight | pupil, 2) & eyes

    hair_color = hair_like(master)
    # Do not let scalp flood through the eyeball, or lashes get eaten as hair.
    hair_allowed = hair_color & ~eyeball
    seeds = np.zeros((height, width), dtype=bool)
    seeds[:205, :] = True
    seeds[:, :430] = True
    seeds[:, 990:] = True
    scalp = connected_from(seeds & hair_allowed, hair_allowed)

    bang_band = np.zeros((height, width), dtype=bool)
    bang_band[168:348, 530:920] = True
    bangs_core = scalp & bang_band
    bangs_mask = dilate_down(bangs_core, 5) & bang_band
    bangs_mask &= hair_color | bangs_core

    lash = eyes & (lum < 52) & (sat < 40) & ~bangs_mask
    eye_paint = (eyeball | lash) & ~bangs_mask

    print(
        "scalp",
        int(scalp.sum()),
        "bangs",
        int(bangs_mask.sum()),
        "eye_paint",
        int(eye_paint.sum()),
        "eyeball",
        int(eyeball.sum()),
        "sclera",
        int(sclera.sum()),
        "iris",
        int(iris.sum()),
        "lash",
        int(lash.sum()),
    )

    skin_source = (
        (r > 172)
        & (g > 142)
        & (b > 118)
        & (r + 6 >= g)
        & (lum > 148)
        & ~hair_color
        & ~eye_paint
        & ellipse_mask((height, width), 742, 340, 200, 220)
    )
    print("skin source", int(skin_source.sum()))

    base_rgb = master.astype(np.float32)
    base_rgb = inpaint_from(base_rgb, eye_paint, skin_source, radius=10, passes=8, fallback=SKIN)
    leftover = inner & ~bangs_mask & (luma(base_rgb) < 125)
    if leftover.any():
        print("leftover socket dirt", int(leftover.sum()))
        base_rgb = inpaint_from(base_rgb, leftover, skin_source, radius=8, passes=6, fallback=SKIN)
        still = leftover & (luma(base_rgb) < 130)
        if still.any():
            print("force skin fill", int(still.sum()))
            base_rgb[still] = SKIN

    hair_lock_mask = current_hair[:, :, 3] > 40
    tassel_mask = current_tassel[:, :, 3] > 40
    # Keep the face-adjacent cut of the lock, but rebuild color from master.
    base_rgb = inpaint_rgb(base_rgb, hair_lock_mask, radius=8, passes=8)
    base_rgb = inpaint_rgb(base_rgb, tassel_mask, radius=6, passes=6)

    face = ellipse_mask((height, width), 742, 330, 210, 230)
    skin = (
        face
        & (base_rgb[:, :, 0] > 160)
        & (base_rgb[:, :, 1] > 130)
        & (base_rgb[:, :, 2] > 110)
        & ~scalp
        & ~hair_lock_mask
    )
    base_rgb = remove_speckles(base_rgb, skin)

    # Second speckle pass on sockets specifically
    sockets = dilate(left_eye | right_eye, 6) & ~scalp
    socket_skin = sockets & (luma(base_rgb) > 130)
    base_rgb = remove_speckles(base_rgb, socket_skin)

    base = np.zeros((height, width, 4), dtype=np.uint8)
    base[:, :, :3] = np.clip(base_rgb, 0, 255).astype(np.uint8)
    base[:, :, 3] = 255

    # Eyes: iris, sclera, lashes only. Extra skin around them becomes a goggle ring.
    eye_keep = (eyeball | lash) & ~bangs_mask
    left_layer = rgba_from(master, eye_keep & left_eye, soft=1)
    right_layer = rgba_from(master, eye_keep & right_eye, soft=1)

    bangs = rgba_from(master, bangs_mask, soft=1)

    hair_lock = rgba_from(master, hair_lock_mask, soft=1)
    hair_lock = defringe(hair_lock)
    tassel = rgba_from(master, tassel_mask, soft=1)
    tassel = defringe(tassel)

    # Debug crops
    def crop_save(arr: np.ndarray, box: tuple[int, int, int, int], name: str) -> None:
        x0, y0, x1, y1 = box
        Image.fromarray(arr[y0:y1, x0:x1]).save(DEBUG / name)

    crop_save(base, (560, 140, 980, 520), "new_base_face.png")
    crop_save(base, (620, 270, 700, 345), "new_left_socket.png")
    crop_save(base, (755, 250, 850, 330), "new_right_socket.png")
    crop_save(left_layer, (600, 250, 720, 360), "new_eye_left.png")
    crop_save(right_layer, (740, 230, 870, 340), "new_eye_right.png")
    crop_save(bangs, (560, 170, 900, 360), "new_bangs.png")

    mag = np.zeros_like(left_layer)
    mag[:, :, 0] = 255
    mag[:, :, 2] = 255
    mag[:, :, 3] = 255

    def on_magenta(src: np.ndarray, box: tuple[int, int, int, int], name: str) -> None:
        x0, y0, x1, y1 = box
        crop = src[y0:y1, x0:x1].astype(np.float32)
        bg = mag[y0:y1, x0:x1].astype(np.float32)
        a = crop[:, :, 3:4] / 255.0
        out = crop * a + bg * (1 - a)
        out[:, :, 3] = 255
        Image.fromarray(out.astype(np.uint8)).resize(
            ((x1 - x0) * 3, (y1 - y0) * 3),
            Image.NEAREST,
        ).save(DEBUG / name)

    on_magenta(left_layer, (600, 250, 720, 360), "new_eye_left_mag.png")
    on_magenta(right_layer, (740, 230, 870, 340), "new_eye_right_mag.png")
    on_magenta(bangs, (560, 170, 900, 360), "new_bangs_mag.png")
    on_magenta(hair_lock, (470, 260, 580, 580), "new_hair_mag.png")

    left_sock = luma(base[270:345, 620:700])
    right_sock = luma(base[250:330, 755:850])
    left_bangs = bangs_mask[270:345, 620:700]
    right_bangs = bangs_mask[250:330, 755:850]
    left_skin = left_sock[~left_bangs]
    right_skin = right_sock[~right_bangs]
    print(
        "new left socket (no bangs) lum min/p5/mean",
        float(left_skin.min()) if left_skin.size else None,
        float(np.percentile(left_skin, 5)) if left_skin.size else None,
        float(left_skin.mean()) if left_skin.size else None,
        "pixels<80",
        int((left_skin < 80).sum()) if left_skin.size else 0,
    )
    print(
        "new right socket (no bangs) lum min/p5/mean",
        float(right_skin.min()) if right_skin.size else None,
        float(np.percentile(right_skin, 5)) if right_skin.size else None,
        float(right_skin.mean()) if right_skin.size else None,
        "pixels<80",
        int((right_skin < 80).sum()) if right_skin.size else 0,
    )
    print("bangs opaque", int((bangs[:, :, 3] > 10).sum()), "bbox", Image.fromarray(bangs).getbbox())
    print("eye L opaque", int((left_layer[:, :, 3] > 10).sum()), "bbox", Image.fromarray(left_layer).getbbox())
    print("eye R opaque", int((right_layer[:, :, 3] > 10).sum()), "bbox", Image.fromarray(right_layer).getbbox())

    preview = base.copy()
    for layer in (hair_lock, tassel, left_layer, right_layer):
        a = layer[:, :, 3:4].astype(np.float32) / 255.0
        preview = (layer.astype(np.float32) * a + preview.astype(np.float32) * (1 - a)).astype(np.uint8)
        preview[:, :, 3] = 255
    # punch bangs from a features-only overlay to mimic runtime
    features = np.zeros_like(base)
    for layer in (left_layer, right_layer):
        a = layer[:, :, 3:4].astype(np.float32) / 255.0
        features = (layer.astype(np.float32) * a + features.astype(np.float32) * (1 - a)).astype(np.uint8)
    punch = bangs[:, :, 3:4].astype(np.float32) / 255.0
    features = features.astype(np.float32)
    features[:, :, 3:4] *= 1 - punch
    a = features[:, :, 3:4] / 255.0
    composed = (features * a + base.astype(np.float32) * (1 - a)).astype(np.uint8)
    composed[:, :, 3] = 255
    crop_save(composed, (560, 140, 980, 520), "preview_face.png")
    Image.fromarray(composed).save(DEBUG / "preview_full.png")

    for dest in DESTS:
        save_png(dest / "base.png", base)
        save_png(dest / "eye_left.png", left_layer)
        save_png(dest / "eye_right.png", right_layer)
        save_png(dest / "bangs.png", bangs)
        save_png(dest / "hair_lock.png", hair_lock)
        save_png(dest / "tassel.png", tassel)


if __name__ == "__main__":
    main()
