"""Community R4b: Qwen-Edit on R1-fix with offline wider mask + waist/gauntlet prompt.

Authorized 2026-10-10 08:22:
- Prefer 592 (models already ~31.55GB); never both boxes
- Mask = offline_r4_recomposite wider logic (plate∪r1 metal/edge/core)
- Prompt explicitly removes waist girdle armor + gauntlet
- Horse/bg lock y>=horse_guard; feather≈10
- Cap ¥4; no Flux Fill; no grok.com

    python run_fox_centaur_community_r4b.py --emit-plan
    python run_fox_centaur_community_r4b.py --check-stack
    python run_fox_centaur_community_r4b.py --out /path --i-know-authorized
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_fox_centaur_community_r4 as r4  # noqa: E402
import run_fox_centaur_semantic as base  # noqa: E402
import semantic_undress as sem  # noqa: E402

W, H = r4.W, r4.H
Y_CUT = int(sem.ELENA.horse_guard_y / sem.BASE[1] * H)
R4B_SEED = 202610102
R4B_STEPS = r4.R4_STEPS
R4B_CFG = r4.R4_CFG
FEATHER = 10

POS = (
    "Remove the translucent chrome metal film, glossy armor remnants, black strap lines, "
    "metallic residue, the metal waist belt / hip armor plates / girdle at the human-horse "
    "junction, and the segmented metal gauntlet on the arm. "
    "Reveal continuous natural bare skin with realistic pores and soft golden-hour light "
    "from chest through the waist transition. "
    "Keep her face, glasses, hair, pose, horse body fur below the waist, and stone terrace "
    "background unchanged."
)
NEG = (
    "chrome armor, glossy metal film, specular breastplate, black straps, "
    "metal waist belt, hip armor plates, girdle, gauntlet, metallic skin, mirror finish, "
    "extra limbs, blurry, watermark"
)

PLAN = {
    "name": "community_r4b_qwen_wider_mask_waist",
    "status": "implemented",
    "baseline": "r1-fix",
    "supersedes": ["community_r4_under_mask"],
    "forbid": ["flux_fill", "r3_regen", "r3b_paste", "fooocus_armor_inpaint"],
    "steps": R4B_STEPS,
    "cfg": R4B_CFG,
    "y_cut": Y_CUT,
    "feather": FEATHER,
    "mask": "offline wider (plate∪r1 metal/edge/core; dilate17; close11)",
    "cost_cny": {"pilot": "1.0-2.5", "cap": "4"},
    "auth": "2026-10-10 08:22 R4b",
}


def _dilate(mask: np.ndarray, size: int = 17) -> np.ndarray:
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    img = img.filter(ImageFilter.MaxFilter(size if size % 2 else size + 1))
    return np.asarray(img) > 127


def _close(mask: np.ndarray, size: int = 11) -> np.ndarray:
    img = Image.fromarray((mask.astype(np.uint8) * 255), mode="L")
    img = img.filter(ImageFilter.MaxFilter(size if size % 2 else size + 1))
    img = img.filter(ImageFilter.MinFilter(size if size % 2 else size + 1))
    return np.asarray(img) > 127


def _metalish(rgb: np.ndarray) -> np.ndarray:
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    mean = rgb.mean(axis=2)
    chroma = np.abs(r - g) + np.abs(g - b)
    low_chroma_metal = (chroma < 48) & ((mean > 130) | ((mean < 100) & (mean > 20)))
    specular = (chroma < 38) & (mean > 145) & (mean < 220)
    gold = (r > g) & (g > b) & ((r - b) > 28) & (chroma > 35) & (mean > 70) & (mean < 210)
    return low_chroma_metal | specular | gold


def _dark_edge(rgb: np.ndarray) -> np.ndarray:
    mean = rgb.mean(axis=2)
    chroma = np.abs(rgb[:, :, 0] - rgb[:, :, 1]) + np.abs(rgb[:, :, 1] - rgb[:, :, 2])
    return (mean < 60) & (chroma < 45) & (mean > 6)


def wider_metal_mask(r1fix: np.ndarray, plate: np.ndarray) -> np.ndarray:
    """Same coverage as offline_r4_recomposite.build_mask without raw-dependent terms."""
    yy, xx = np.mgrid[0:H, 0:W]
    band = (yy < Y_CUT) & (yy > int(H * 0.04)) & (xx > int(W * 0.12)) & (xx < int(W * 0.72))
    plate_m = _metalish(plate)
    r1_m = _metalish(r1fix) | _dark_edge(r1fix)
    film = (plate_m | r1_m) & band
    core = (
        (yy > int(H * 0.08))
        & (yy < int(H * 0.48))
        & (xx > int(W * 0.22))
        & (xx < int(W * 0.62))
        & (r1_m | plate_m | _dark_edge(r1fix))
    )
    # waist girdle band: force-include metalish near horse guard
    waist = (
        (yy > int(H * 0.38))
        & (yy < Y_CUT)
        & (xx > int(W * 0.18))
        & (xx < int(W * 0.68))
        & (r1_m | plate_m | _dark_edge(r1fix))
    )
    # gauntlet / forearm metal (right side of frame often)
    arm = (
        (yy > int(H * 0.22))
        & (yy < int(H * 0.48))
        & (xx > int(W * 0.12))
        & (xx < int(W * 0.35))
        & (r1_m | plate_m)
    )
    mask = film | core | waist | arm
    mask &= band
    mask = _dilate(mask, 17)
    mask = _close(mask, 11)
    mask[Y_CUT:, :] = False
    face = (yy < int(H * 0.14)) & (xx > int(W * 0.30)) & (xx < int(W * 0.55))
    mask &= ~(face & ~_dark_edge(r1fix) & ~_metalish(r1fix))
    return mask


def run_elena(
    host: str,
    out_dir: Path,
    *,
    r1fix_path: Path,
    plate_path: Path,
) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    work = out_dir / "work"
    work.mkdir(exist_ok=True)
    dbg = out_dir / "debug"
    dbg.mkdir(exist_ok=True)

    r1 = Image.open(r1fix_path).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    plate = Image.open(plate_path).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    mask = wider_metal_mask(np.asarray(r1, dtype=np.float32), np.asarray(plate, dtype=np.float32))
    Image.fromarray((mask.astype(np.uint8) * 255), mode="L").save(dbg / "wider-metal-mask.png")
    print(f"MASK_SHARE {float(mask.mean()):.4f} y_cut={Y_CUT} feather={FEATHER}", flush=True)

    upload_path = work / "r1fix-elena.png"
    r1.save(upload_path)
    base.upload(host, upload_path)

    models = r4.resolve_r4_models(host)
    use_ref = r4.has_ref_method(host)
    graph = r4.qwen_edit_graph(
        image_name=upload_path.name,
        models=models,
        prompt=POS,
        negative=NEG,
        seed=R4B_SEED,
        use_ref_method=use_ref,
    )
    # retarget save prefix + steps (graph uses r4 module constants for steps)
    graph["14"]["inputs"]["steps"] = R4B_STEPS
    graph["14"]["inputs"]["cfg"] = R4B_CFG
    graph["14"]["inputs"]["seed"] = R4B_SEED
    graph["16"]["inputs"]["filename_prefix"] = "r4b-qwen-raw"
    print(f"R4B_GRAPH qwen_edit lightning={R4B_STEPS} ref_method={use_ref}", flush=True)
    got = base.run_graph(host, graph, {"raw": "16"}, work, "r4b-elena")
    raw = Image.open(got["raw"]).convert("RGB")
    raw.save(out_dir / "elena-armor-centaur-nude-r4b-raw.png")

    final = r4.composite_mask_region(r1, raw, mask, feather=FEATHER)
    stem = "elena-armor-centaur-nude"
    dest = out_dir / f"{stem}.png"
    final.save(dest)
    r4.save_previews(out_dir, final, stem)

    below = np.abs(
        np.asarray(final, dtype=np.float32)[Y_CUT:] - np.asarray(r1, dtype=np.float32)[Y_CUT:]
    ).mean()
    meta = {
        "pipeline": "community_r4b",
        "baseline": str(r1fix_path),
        "plate": str(plate_path),
        "y_cut": Y_CUT,
        "feather": FEATHER,
        "mask_share": round(float(mask.mean()), 6),
        "below_cut_mae_vs_r1fix": round(float(below), 4),
        "steps": R4B_STEPS,
        "cfg": R4B_CFG,
        "seed": R4B_SEED,
        "models": models,
        "prompt": POS,
        "forbid": PLAN["forbid"],
    }
    (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"STITCH_R4B {dest} {dest.stat().st_size}", flush=True)
    print(f"BELOW_CUT_MAE_vs_r1fix {below:.2f}", flush=True)
    print(f"VISUAL_JUDGE elena nude {dest}", flush=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/fox-semantic-out-r4b"))
    parser.add_argument(
        "--r1fix",
        type=Path,
        default=Path("/root/autodl-tmp/fox-r4-input/elena-armor-centaur-nude-r1fix.png"),
    )
    parser.add_argument(
        "--plate",
        type=Path,
        default=Path(
            "/root/autodl-tmp/arc/ai-realistic-comic/library/stills/fox-centaur-embrace/elena-armor-centaur.png"
        ),
    )
    parser.add_argument("--emit-plan", action="store_true")
    parser.add_argument("--check-stack", action="store_true")
    parser.add_argument("--i-know-authorized", action="store_true")
    args = parser.parse_args()

    if args.emit_plan:
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        return
    if args.check_stack:
        r4.check_stack(args.host)
        return
    if not args.i_know_authorized:
        print("R4B_REFUSE: pass --i-know-authorized to generate on --host.", flush=True)
        raise SystemExit(2)
    if not args.r1fix.is_file():
        raise SystemExit(f"MISSING_R1FIX {args.r1fix}")
    if not args.plate.is_file():
        raise SystemExit(f"MISSING_PLATE {args.plate}")
    run_elena(args.host, args.out, r1fix_path=args.r1fix, plate_path=args.plate)


if __name__ == "__main__":
    main()
