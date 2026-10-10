"""Offline R4 recomposite: paste r4-raw onto R1-fix with a wider metal-film mask.

No GPU. Fixes R4 pilot failure where mask_region under-covered film/edges.

    python offline_r4_recomposite.py
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
PLATE = ROOT / "library/stills/fox-centaur-embrace/elena-armor-centaur.png"
R1FIX = Path("/opt/cursor/artifacts/fox-centaur-semantic/r1-fix/elena-armor-centaur-nude.png")
RAW = Path("/opt/cursor/artifacts/fox-centaur-semantic/r4/elena-armor-centaur-nude-r4-raw.png")
OUT = Path("/opt/cursor/artifacts/fox-centaur-semantic/r4-offline")
STORE = Path("/cursor/stores/self/artifacts/fox-centaur-semantic/r4-offline")
W, H = 1024, 1536
Y_CUT = 690
FEATHER = 10


def _blur01(mask: np.ndarray, radius: float) -> np.ndarray:
    img = Image.fromarray((np.clip(mask, 0, 1) * 255).astype(np.uint8), mode="L")
    if radius > 0:
        img = img.filter(ImageFilter.GaussianBlur(radius=radius))
    return np.asarray(img).astype(np.float32) / 255.0


def _dilate(mask: np.ndarray, size: int = 15) -> np.ndarray:
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    img = img.filter(ImageFilter.MaxFilter(size if size % 2 else size + 1))
    return np.asarray(img) > 127


def _close(mask: np.ndarray, size: int = 9) -> np.ndarray:
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    img = img.filter(ImageFilter.MaxFilter(size if size % 2 else size + 1))
    img = img.filter(ImageFilter.MinFilter(size if size % 2 else size + 1))
    return np.asarray(img) > 127


def torso_band() -> np.ndarray:
    yy, xx = np.mgrid[0:H, 0:W]
    return (yy < Y_CUT) & (yy > int(H * 0.04)) & (xx > int(W * 0.12)) & (xx < int(W * 0.72))


def metalish(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mean = rgb.mean(axis=2)
    chroma = np.abs(r - g) + np.abs(g - b)
    low_chroma_metal = (chroma < 48) & ((mean > 130) | ((mean < 100) & (mean > 20)))
    specular = (chroma < 38) & (mean > 145) & (mean < 220)
    gold = (r > g) & (g > b) & ((r - b) > 28) & (chroma > 35) & (mean > 70) & (mean < 210)
    return low_chroma_metal | specular | gold


def dark_edge(rgb: np.ndarray) -> np.ndarray:
    mean = rgb.mean(axis=2)
    chroma = np.abs(rgb[:, :, 0] - rgb[:, :, 1]) + np.abs(rgb[:, :, 1] - rgb[:, :, 2])
    return (mean < 60) & (chroma < 45) & (mean > 6)


def skinish(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mean = rgb.mean(axis=2)
    chroma = np.abs(r - g) + np.abs(g - b)
    return (r > g) & (g > b * 0.85) & (mean > 70) & (mean < 215) & ((r - b) > 12) & (chroma > 18)


def build_mask(r1: np.ndarray, plate: np.ndarray, raw: np.ndarray) -> np.ndarray:
    """Wider than R4 pilot: plate chrome ∪ r1 metal/edges ∪ where raw is skinnier than r1."""
    band = torso_band()
    plate_m = metalish(plate)
    r1_m = metalish(r1) | dark_edge(r1)
    # residual film: plate chrome still metalish on r1, or r1 metal while raw looks skin
    film = (plate_m | r1_m) & band
    raw_helps = band & (~skinish(r1)) & skinish(raw)
    # also paste where raw differs a lot and r1 is still metallic/edge-y
    diff = np.abs(raw.astype(np.float32) - r1.astype(np.float32)).mean(axis=2)
    diff_hot = band & (diff > 18) & (r1_m | plate_m | dark_edge(r1) | (~skinish(r1) & skinish(raw)))
    mask = film | raw_helps | diff_hot
    # include neck collar / arm bands / midriff more aggressively inside human x-band
    yy, xx = np.mgrid[0:H, 0:W]
    core = (
        (yy > int(H * 0.08))
        & (yy < int(H * 0.48))
        & (xx > int(W * 0.22))
        & (xx < int(W * 0.62))
        & (r1_m | plate_m | dark_edge(r1) | (diff > 22))
    )
    mask |= core
    mask &= band
    mask = _dilate(mask, 17)
    mask = _close(mask, 11)
    mask[Y_CUT:, :] = False
    # keep face mostly from baseline unless metal there (collar only)
    face = (yy < int(H * 0.14)) & (xx > int(W * 0.30)) & (xx < int(W * 0.55))
    mask &= ~(face & ~dark_edge(r1) & ~metalish(r1))
    return mask


def metalish_share(rgb: np.ndarray) -> float:
    x0, x1 = int(W * 0.22), int(W * 0.62)
    y0, y1 = int(H * 0.12), int(H * 0.48)
    t = rgb[y0:y1, x0:x1]
    return float(metalish(t).mean())


def recomposite() -> Path:
    for p, name in ((R1FIX, "R1FIX"), (RAW, "RAW"), (PLATE, "PLATE")):
        if not p.is_file():
            raise SystemExit(f"MISSING_{name} {p}")
    OUT.mkdir(parents=True, exist_ok=True)
    dbg = OUT / "debug"
    dbg.mkdir(exist_ok=True)

    r1_img = Image.open(R1FIX).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    raw_img = Image.open(RAW).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    plate_img = Image.open(PLATE).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    r1 = np.asarray(r1_img, dtype=np.float32)
    raw = np.asarray(raw_img, dtype=np.float32)
    plate = np.asarray(plate_img, dtype=np.float32)

    mask = build_mask(r1, plate, raw)
    Image.fromarray((mask.astype(np.uint8) * 255), mode="L").save(dbg / "mask-binary.png")

    alpha = _blur01(mask.astype(np.float32), FEATHER)
    alpha[Y_CUT:] = 0.0
    Image.fromarray((alpha * 255).astype(np.uint8), mode="L").save(dbg / "alpha.png")

    canvas = r1 * (1.0 - alpha[:, :, None]) + raw * alpha[:, :, None]
    canvas[Y_CUT:] = r1[Y_CUT:]
    out = Image.fromarray(np.clip(canvas, 0, 255).astype(np.uint8))

    stem = "elena-armor-centaur-nude"
    dest = OUT / f"{stem}.png"
    out.save(dest)
    out.resize((512, int(512 * H / W)), Image.Resampling.LANCZOS).save(
        OUT / f"{stem}-preview.webp", "WEBP", quality=85
    )
    out.crop((int(W * 0.20), int(H * 0.06), int(W * 0.72), int(H * 0.52))).save(
        OUT / f"{stem}-torso.webp", "WEBP", quality=85
    )

    # overlays / compare
    ov = np.asarray(out).astype(np.float32)
    ov[:, :, 0] = np.clip(ov[:, :, 0] * (1 - alpha * 0.45) + 230 * alpha * 0.45, 0, 255)
    Image.fromarray(ov.astype(np.uint8)).save(dbg / "mask-overlay.jpg", quality=85)

    box = (200, 80, 720, 700)
    cols = [r1_img.crop(box), out.crop(box), raw_img.crop(box)]
    row = Image.new("RGB", (cols[0].width * 3, cols[0].height))
    for i, im in enumerate(cols):
        row.paste(im, (i * cols[0].width, 0))
    row.save(OUT / "compare-r1-offline-raw.jpg", quality=85)

    below = float(np.abs(canvas[Y_CUT:] - r1[Y_CUT:]).mean())
    inmask = float(np.abs(canvas - r1)[mask].mean()) if mask.any() else 0.0
    m_r1 = metalish_share(r1)
    m_out = metalish_share(canvas)
    m_raw = metalish_share(raw)

    # Does raw cover film zones? If raw still metalish where r1 was film, need Qwen rerun
    film_on_r1 = metalish(r1) & torso_band()
    raw_still_metal_on_film = float((metalish(raw) & film_on_r1).sum() / max(1, film_on_r1.sum()))
    needs_qwen = (m_raw > 0.12) or (raw_still_metal_on_film > 0.35)

    meta = {
        "pipeline": "r4_offline_recomposite",
        "source_r1fix": str(R1FIX),
        "source_raw": str(RAW),
        "source_plate": str(PLATE),
        "y_cut": Y_CUT,
        "feather": FEATHER,
        "mask_share": round(float(mask.mean()), 6),
        "below_cut_mae_vs_r1fix": round(below, 4),
        "inmask_mae_vs_r1fix": round(inmask, 4),
        "metalish": {"r1fix": round(m_r1, 4), "offline": round(m_out, 4), "raw": round(m_raw, 4)},
        "raw_still_metal_on_r1_film": round(raw_still_metal_on_film, 4),
        "needs_qwen_rerun": needs_qwen,
        "gpu": False,
        "method": [
            "canvas=R1-fix",
            "paste r4-raw where wider metal-film/edge/diff mask",
            "lock y>=horse_guard from R1-fix",
            f"feather={FEATHER}",
        ],
    }
    (OUT / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    for src_name, dst_name in (
        (f"{stem}-preview.webp", "r4-offline-preview.webp"),
        (f"{stem}-torso.webp", "r4-offline-torso.webp"),
    ):
        try:
            shutil.copyfile(OUT / src_name, Path("/opt/cursor/artifacts") / dst_name)
        except OSError:
            pass

    STORE.mkdir(parents=True, exist_ok=True)
    for src in OUT.rglob("*"):
        if src.is_file():
            dst = STORE / src.relative_to(OUT)
            dst.parent.mkdir(parents=True, exist_ok=True)
            try:
                if dst.resolve() == src.resolve():
                    continue
            except OSError:
                pass
            shutil.copyfile(src, dst)

    print(f"R4_OFFLINE {dest} {dest.stat().st_size}", flush=True)
    print(f"MASK_SHARE {mask.mean():.4f}", flush=True)
    print(f"BELOW_CUT_MAE {below:.2f}", flush=True)
    print(f"METALISH r1={m_r1:.3f} offline={m_out:.3f} raw={m_raw:.3f}", flush=True)
    print(f"RAW_STILL_METAL_ON_FILM {raw_still_metal_on_film:.3f}", flush=True)
    print(f"NEEDS_QWEN_RERUN {needs_qwen}", flush=True)
    print(f"PREVIEW {OUT / (stem + '-preview.webp')}", flush=True)
    print(f"TORSO {OUT / (stem + '-torso.webp')}", flush=True)
    print(f"STORE {STORE}", flush=True)
    return dest


if __name__ == "__main__":
    recomposite()
