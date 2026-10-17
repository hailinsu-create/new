"""Community R4 batch3: Qwen-Image-Edit-2511 on Lin nude/torn + Elena torn.

Authorized 2026-10-10 13:58:
- Same stack as archived Elena nude R4 recipe (2511 FP8 + Lightning + remove + object)
- Success = keep Qwen full-image edit RAW (pre paste-back); paste must NOT overwrite official
- Do NOT re-run Elena nude / metal-armor film cleanup
- Prefer 592 (models ~31.55GB); never both boxes

    python run_fox_centaur_community_r4_batch3.py --emit-plan
    python run_fox_centaur_community_r4_batch3.py --check-stack
    python run_fox_centaur_community_r4_batch3.py --out /path --i-know-authorized
"""
from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_fox_centaur_community_r4 as r4  # noqa: E402
import run_fox_centaur_semantic as base  # noqa: E402

W, H = r4.W, r4.H

PLAN = {
    "name": "community_r4_batch3_lin_nude_torn_elena_torn",
    "status": "implemented",
    "stack": "qwen_image_edit_2511_fp8 + lightning + remove-clothes + object-remover",
    "success": "adopt Qwen-Edit RAW before paste-back; never overwrite with composite",
    "targets": ["lin-qipao-nine-tail-nude", "lin-qipao-nine-tail-torn", "elena-armor-centaur-torn"],
    "forbid": ["elena_nude_rerun", "metal_armor_film_spin", "paste_overwrite_official"],
    "steps": r4.R4_STEPS,
    "cfg": r4.R4_CFG,
}


@dataclass(frozen=True)
class Shot:
    stem: str
    plate_name: str
    seed: int
    prompt: str
    negative: str
    preview_crop: tuple[int, int, int, int]


SHOTS = (
    Shot(
        stem="lin-qipao-nine-tail-nude",
        plate_name="lin-qipao-nine-tail.png",
        seed=20261011,
        prompt=(
            "Remove the blue-and-white floral qipao / cheongsam completely from the woman. "
            "Reveal natural bare adult skin with realistic pores under soft garden light. "
            "Keep her face, hair, expression, standing pose, nine fox tails, high-heel shoes, "
            "and the garden background unchanged."
        ),
        negative=(
            "qipao, cheongsam, silk dress, embroidery, mandarin collar, skirt panels, "
            "clothes remaining, fabric smear, extra limbs, blurry, watermark, child"
        ),
        preview_crop=(int(W * 0.18), int(H * 0.05), int(W * 0.78), int(H * 0.55)),
    ),
    Shot(
        stem="lin-qipao-nine-tail-torn",
        plate_name="lin-qipao-nine-tail.png",
        seed=20261012,
        prompt=(
            "Tear the blue-and-white floral qipao open with jagged frayed silk edges across "
            "the chest and abdomen, revealing bare adult skin in the tears while leaving "
            "collar, sleeve, and hem remnants. Keep face, hair, nine fox tails, heels, "
            "pose, and garden background unchanged."
        ),
        negative=(
            "fully clothed intact dress, seamless undamaged qipao, extra limbs, "
            "blurry, watermark, child, completely nude with no fabric remnants"
        ),
        preview_crop=(int(W * 0.18), int(H * 0.05), int(W * 0.78), int(H * 0.55)),
    ),
    Shot(
        stem="elena-armor-centaur-torn",
        plate_name="elena-armor-centaur.png",
        seed=20261013,
        prompt=(
            "Shatter and tear the medieval torso armor with jagged broken metal edges, "
            "revealing bare adult skin through the gaps while leaving broken plate remnants "
            "on shoulders and edges. Keep her face, glasses, brown hair, pose, horse body "
            "below the waist, and stone terrace background unchanged."
        ),
        negative=(
            "intact breastplate, unbroken armor, chrome film, fully nude with no metal remnants, "
            "extra limbs, blurry, watermark, child, altered horse body"
        ),
        preview_crop=(int(W * 0.16), int(H * 0.05), int(W * 0.72), int(H * 0.52)),
    ),
)


def save_previews(out_dir: Path, img, stem: str, crop: tuple[int, int, int, int]) -> None:
    from PIL import Image  # noqa: WPS433
    img.resize((512, int(512 * H / W)), Image.Resampling.LANCZOS).save(
        out_dir / f"{stem}-preview.webp", "WEBP", quality=85
    )
    img.crop(crop).resize((512, 512), Image.Resampling.LANCZOS).save(
        out_dir / f"{stem}-torso.webp", "WEBP", quality=85
    )


def run_shot(
    host: str,
    out_dir: Path,
    shot: Shot,
    *,
    plate_dir: Path,
    models: dict[str, str],
    use_ref: bool,
) -> Path:
    plate_path = plate_dir / shot.plate_name
    if not plate_path.is_file():
        raise SystemExit(f"MISSING_PLATE {plate_path}")

    from PIL import Image  # noqa: WPS433

    work = out_dir / "work"
    work.mkdir(parents=True, exist_ok=True)
    plate = Image.open(plate_path).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)
    upload = work / f"plate-{shot.stem}.png"
    plate.save(upload)
    base.upload(host, upload)

    graph = r4.qwen_edit_graph(
        image_name=upload.name,
        models=models,
        prompt=shot.prompt,
        negative=shot.negative,
        seed=shot.seed,
        use_ref_method=use_ref,
    )
    print(
        f"R4_BATCH3_GRAPH {shot.stem} seed={shot.seed} lightning={r4.R4_STEPS} ref={use_ref}",
        flush=True,
    )
    got = base.run_graph(host, graph, {"raw": "16"}, work, f"r4b3-{shot.stem}")
    raw = Image.open(got["raw"]).convert("RGB").resize((W, H), Image.Resampling.LANCZOS)

    # Official = RAW only (archived R4 success rule). No paste-back overwrite.
    raw_path = out_dir / f"{shot.stem}-r4-raw.png"
    raw.save(raw_path)
    official = out_dir / f"{shot.stem}.png"
    raw.save(official)
    save_previews(out_dir, raw, shot.stem, shot.preview_crop)

    meta = {
        "pipeline": "community_r4_batch3",
        "stem": shot.stem,
        "plate": str(plate_path),
        "official_is_raw": True,
        "raw_path": str(raw_path),
        "paste_overwrite": False,
        "steps": r4.R4_STEPS,
        "cfg": r4.R4_CFG,
        "seed": shot.seed,
        "models": models,
        "prompt": shot.prompt,
        "negative": shot.negative,
        "forbid": PLAN["forbid"],
    }
    (out_dir / f"{shot.stem}.run.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"RAW_OK {shot.stem} {raw_path} bytes={raw_path.stat().st_size}", flush=True)
    print(f"VISUAL_JUDGE {shot.stem} {raw_path}", flush=True)
    return raw_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/fox-semantic-out-r4-batch3"))
    parser.add_argument(
        "--plate-dir",
        type=Path,
        default=Path("/root/autodl-tmp/fox-r4-batch3-input"),
    )
    parser.add_argument(
        "--only",
        choices=[s.stem for s in SHOTS],
        action="append",
        default=None,
        help="Optional subset; default = all three.",
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
        print("R4_BATCH3_REFUSE: pass --i-know-authorized", flush=True)
        raise SystemExit(2)

    out_dir = args.out
    out_dir.mkdir(parents=True, exist_ok=True)
    models = r4.resolve_r4_models(args.host)
    use_ref = r4.has_ref_method(args.host)
    wanted = set(args.only) if args.only else {s.stem for s in SHOTS}
    if "elena-armor-centaur-nude" in wanted:
        raise SystemExit("FORBID_ELENA_NUDE_RERUN")

    done: list[str] = []
    for shot in SHOTS:
        if shot.stem not in wanted:
            continue
        run_shot(
            args.host,
            out_dir,
            shot,
            plate_dir=args.plate_dir,
            models=models,
            use_ref=use_ref,
        )
        done.append(shot.stem)

    summary = {
        "pipeline": "community_r4_batch3",
        "done": done,
        "official_is_raw": True,
        "models": models,
        "plan": PLAN,
    }
    (out_dir / "BATCH3_SUMMARY.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"BATCH3_DONE {done}", flush=True)


if __name__ == "__main__":
    main()
