"""Elena-couple R4: Qwen-Edit nude/torn on Elena upper armor/clothes only.

Lock pose, horse body, male-as-in-plate, background. Official = RAW before paste.
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
    "name": "elena_couple_r4_upper_wardrobe_only",
    "status": "implemented",
    "success": "adopt Qwen-Edit RAW before paste-back",
    "targets": ["elena-couple-nude", "elena-couple-torn"],
    "lock": ["male_as_in_plate", "horse_body", "kiss_pose", "background"],
    "edit": ["elena_upper_armor_clothes_only"],
    "male_future_unlocked": True,
}


@dataclass(frozen=True)
class Shot:
    stem: str
    seed: int
    prompt: str
    negative: str


SHOTS = (
    Shot(
        stem="elena-couple-nude",
        seed=20261016,
        prompt=(
            "Edit only the centaur woman's upper-body armor and clothing: remove breastplate, bodice, "
            "straps and fabric completely so her adult human torso is bare natural skin. "
            "Keep the standing courtyard kiss pose unchanged. Keep the man exactly as in the photo. "
            "Keep her entire horse lower body, fur, hooves, face, hair, and stone-courtyard background unchanged."
        ),
        negative=(
            "armor remaining, metal plate, bodice, clothes on her torso, sheer smear, "
            "changed man, changed horse body, extra limbs, broken pose, blurry, watermark, child"
        ),
    ),
    Shot(
        stem="elena-couple-torn",
        seed=20261017,
        prompt=(
            "Edit only the centaur woman's upper-body armor and clothing: violently tear and shatter it "
            "with huge jagged gaps over both breasts and midriff so abundant bare adult skin shows; "
            "leave only broken metal rim scraps and shredded fabric strips — must look destroyed, not intact armor. "
            "Keep the standing courtyard kiss pose unchanged. Keep the man exactly as in the photo. "
            "Keep her entire horse lower body, fur, hooves, face, hair, and stone-courtyard background unchanged."
        ),
        negative=(
            "intact armor, undamaged breastplate, fully clothed torso, tiny scratches only, "
            "changed man, changed horse body, completely nude with no scraps, blurry, watermark, child"
        ),
    ),
)


def fit_resize(img):
    w, h = img.size
    scale = min(1536 / max(w, h), 1.0) if max(w, h) > 1536 else 1.0
    tw, th = max(64, int(w * scale) // 8 * 8), max(64, int(h * scale) // 8 * 8)
    return img.resize((tw, th), __import__("PIL").Image.Resampling.LANCZOS)


def run_shot(host: str, out_dir: Path, plate: Path, shot: Shot, models: dict, use_ref: bool) -> Path:
    from PIL import Image

    work = out_dir / "work"
    work.mkdir(parents=True, exist_ok=True)
    img = fit_resize(Image.open(plate).convert("RGB"))
    upload = work / f"plate-{shot.stem}.png"
    img.save(upload)
    base.upload(host, upload)
    graph = r4.qwen_edit_graph(
        image_name=upload.name,
        models=models,
        prompt=shot.prompt,
        negative=shot.negative,
        seed=shot.seed,
        use_ref_method=use_ref,
    )
    print(f"ELENA_R4_GRAPH {shot.stem} seed={shot.seed}", flush=True)
    got = base.run_graph(host, graph, {"raw": "16"}, work, f"elena-{shot.stem}")
    raw = Image.open(got["raw"]).convert("RGB")
    raw_path = out_dir / f"{shot.stem}-r4-raw.png"
    raw.save(raw_path)
    raw.save(out_dir / f"{shot.stem}.png")
    w, h = raw.size
    raw.resize((512, int(512 * h / w)), Image.Resampling.LANCZOS).save(
        out_dir / f"{shot.stem}-preview.webp", "WEBP", quality=85
    )
    (out_dir / f"{shot.stem}.run.json").write_text(
        json.dumps(
            {
                "pipeline": "elena_couple_r4",
                "stem": shot.stem,
                "plate": str(plate),
                "official_is_raw": True,
                "seed": shot.seed,
                "prompt": shot.prompt,
                "models": models,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )
    print(f"RAW_OK {shot.stem} {raw_path}", flush=True)
    print(f"VISUAL_JUDGE {shot.stem} {raw_path}", flush=True)
    return raw_path


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="http://127.0.0.1:8188")
    ap.add_argument("--out", type=Path, default=Path("/root/autodl-tmp/elena-couple-out"))
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
        raise SystemExit("ELENA_COUPLE_R4_REFUSE: pass --i-know-authorized")
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
    (out / "ELENA_COUPLE_SUMMARY.json").write_text(
        json.dumps({"done": done, "official_is_raw": True, "models": models, "plan": PLAN}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"ELENA_COUPLE_R4_DONE {done}", flush=True)


if __name__ == "__main__":
    main()
