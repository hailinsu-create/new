"""Fox-couple R4: Qwen-Edit nude/torn on Lin only; lock Gu, tails, pose, bg.

Success = keep RAW before paste-back. Do not overwrite with composite.
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

PLAN = {
    "name": "fox_couple_r4_lin_wardrobe_only",
    "status": "implemented",
    "success": "adopt Qwen-Edit RAW before paste-back",
    "targets": ["lin-gu-embrace-nude", "lin-gu-embrace-torn"],
    "lock": ["gu_as_in_plate", "white_nine_fox_tails", "kiss_pose", "background"],
    "edit": ["lin_qipao_only"],
    "gu_future_unlocked": "future clothed gens: Gu look/wardrobe not locked; match Lin scene",
}


@dataclass(frozen=True)
class Shot:
    stem: str
    seed: int
    prompt: str
    negative: str


SHOTS = (
    Shot(
        stem="lin-gu-embrace-nude",
        seed=20261014,
        prompt=(
            "Edit only the woman's red embroidered decorative qipao: remove it completely so her adult body is bare "
            "natural skin with realistic pores. Keep her half-lying over him on the bed, pose and faces unchanged. "
            "Keep the man exactly as in the photo (modern short hair, dark blue robe, face, hands). "
            "Keep all nine fluffy pure white fox tails, her face and hair, bed, lanterns and background unchanged."
        ),
        negative=(
            "qipao remaining, red dress, gold embroidery, clothes on the woman, sheer fabric smear, "
            "changed man, topknot, hair ornament, extra limbs, broken pose, missing fox tails, "
            "cream tails, blurry, watermark, child"
        ),
    ),
    Shot(
        stem="lin-gu-embrace-torn",
        seed=20261015,
        prompt=(
            "Edit only the woman's red embroidered decorative qipao: rip large jagged holes through the chest, "
            "breasts, and midriff so abundant bare adult skin shows; leave only torn collar strips and "
            "hip/skirt remnants with frayed silk edges — clothing must look clearly destroyed, not intact. "
            "Keep her half-lying over him on the bed, pose and faces unchanged. "
            "Keep the man exactly as in the photo (modern short hair, dark blue robe, face, hands). "
            "Keep all nine fluffy pure white fox tails, her face and hair, bed, lanterns and background unchanged."
        ),
        negative=(
            "intact undamaged qipao, fully clothed seamless dress, only tiny tears, almost clothed, "
            "changed man, topknot, extra limbs, missing fox tails, completely nude with no fabric remnants, "
            "blurry, watermark, child"
        ),
    ),
))


def run_shot(host: str, out_dir: Path, plate: Path, shot: Shot, models: dict, use_ref: bool) -> Path:
    from PIL import Image

    work = out_dir / "work"
    work.mkdir(parents=True, exist_ok=True)
    img = Image.open(plate).convert("RGB")
    # Prefer portrait 1024x1536 for Qwen Edit consistency
    upload = work / f"plate-{shot.stem}.png"
    img.resize((1024, 1536), Image.Resampling.LANCZOS).save(upload)
    base.upload(host, upload)
    graph = r4.qwen_edit_graph(
        image_name=upload.name,
        models=models,
        prompt=shot.prompt,
        negative=shot.negative,
        seed=shot.seed,
        use_ref_method=use_ref,
    )
    print(f"COUPLE_R4_GRAPH {shot.stem} seed={shot.seed}", flush=True)
    got = base.run_graph(host, graph, {"raw": "16"}, work, f"couple-{shot.stem}")
    raw = Image.open(got["raw"]).convert("RGB")
    raw_path = out_dir / f"{shot.stem}-r4-raw.png"
    raw.save(raw_path)
    raw.save(out_dir / f"{shot.stem}.png")
    w, h = raw.size
    raw.resize((512, int(512 * h / w)), Image.Resampling.LANCZOS).save(
        out_dir / f"{shot.stem}-preview.webp", "WEBP", quality=85
    )
    raw.crop((int(w * 0.15), int(h * 0.08), int(w * 0.90), int(h * 0.62))).resize(
        (512, 512), Image.Resampling.LANCZOS
    ).save(out_dir / f"{shot.stem}-torso.webp", "WEBP", quality=85)
    meta = {
        "pipeline": "fox_couple_r4",
        "stem": shot.stem,
        "plate": str(plate),
        "official_is_raw": True,
        "paste_overwrite": False,
        "seed": shot.seed,
        "steps": r4.R4_STEPS,
        "cfg": r4.R4_CFG,
        "models": models,
        "prompt": shot.prompt,
    }
    (out_dir / f"{shot.stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"RAW_OK {shot.stem} {raw_path}", flush=True)
    print(f"VISUAL_JUDGE {shot.stem} {raw_path}", flush=True)
    return raw_path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="http://127.0.0.1:8188")
    ap.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/fox-couple-out"))
    ap.add_argument("--plate", type=Path, default=None)
    ap.add_argument("--emit-plan", action="store_true")
    ap.add_argument("--check-stack", action="store_true")
    ap.add_argument("--i-know-authorized", action="store_true")
    args = ap.parse_args()
    if args.emit_plan:
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        return
    if args.check_stack:
        r4.check_stack(args.host)
        return
    if not args.i_know_authorized:
        raise SystemExit("COUPLE_R4_REFUSE: pass --i-know-authorized")
    if args.plate is None or not args.plate.is_file():
        raise SystemExit(f"MISSING_PLATE {args.plate}")
    out = args.out
    out.mkdir(parents=True, exist_ok=True)
    models = r4.resolve_r4_models(args.host)
    use_ref = r4.has_ref_method(args.host)
    done = []
    for shot in SHOTS:
        run_shot(args.host, out, args.plate, shot, models, use_ref)
        done.append(shot.stem)
    (out / "COUPLE_SUMMARY.json").write_text(
        json.dumps({"done": done, "official_is_raw": True, "models": models, "plan": PLAN}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"COUPLE_R4_DONE {done}", flush=True)


if __name__ == "__main__":
    main()
