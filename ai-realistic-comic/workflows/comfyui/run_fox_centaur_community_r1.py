"""Community-aligned R1 undress (2026-10-09).

SegFormer/DINO mask + CropAndStitch bands + Fooocus denoise 0.78–0.85 +
optional OpenPose ControlNet. No LaMa residual loop, no pixelfill, no 0.35 touch.

    python run_fox_centaur_community_r1.py --emit-plan
    python run_fox_centaur_community_r1.py --only elena --mode nude --out /path

Scheme A (whole-garment denoise≈1.0) stays paused. F34/G09 never touched.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_fox_centaur_semantic as base  # noqa: E402
import scheme_still_fox_centaur_undress as legacy  # noqa: E402
import semantic_undress as sem  # noqa: E402
from comfy_util import get_json, post_json, resolve_base_models  # noqa: E402
from inpaint_crop import inpaint_crop_graph, stitch  # noqa: E402

R1_DENOISE = 0.82  # default (lin / clothing-swap range)
R1_ELENA_DENOISE = 1.0  # glossy armor needs full latent replace (run6 lesson; R1 pilot 0.82 left chrome shell)
R1_ELENA_NUDE_PASSES = 3  # run6-style redo on same mask; still NO LaMa residual / pixelfill
R1_CFG = 5.5
R1_EDGE_DENOISE = 0.32
R1_ELENA_EDGE_DENOISE = 0.42  # match run6 edge
R1_OPENPOSE_STRENGTH = 0.75
R1_ELENA_OPENPOSE_STRENGTH = 0.40  # weaker so specular plate is not re-locked as "chest shell"
R1_SEED = 20261009
TORN_RIM_DENOISE = 0.55
ELENA_METAL_NEG_EXTRA = (
    "chrome, glossy metal, specular highlight, latex catsuit, vacuum-formed armor, "
    "gunmetal breastplate, shiny black plate, metallic skin, mirror finish"
)

PLAN = {
    "name": "community_r1_sdxl_crop_fooocus_openpose",
    "status": "implemented",
    "supersedes": "wholebody_garment_A_paused",
    "denoise": R1_DENOISE,
    "elena_denoise": R1_ELENA_DENOISE,
    "elena_nude_passes": R1_ELENA_NUDE_PASSES,
    "elena_openpose_strength": R1_ELENA_OPENPOSE_STRENGTH,
    "cfg": R1_CFG,
    "crop_max": 1024,
    "use_openpose": True,
    "note_2026_10_09": "R1 pilot left chrome shell at 0.82×1; Elena fix = 1.0×3 + weaker OpenPose, no LaMa loop",
    "forbid": [
        "lama_residual_loop",
        "hip_pixelfill",
        "touch_0.35_only",
        "whole_body_single_hole_1.0",
    ],
    "cost_cny": {"pilot": "0.5-0.8", "four": "1.5-2.5", "cap": "4"},
}


def has_openpose_nodes(host: str) -> bool:
    info = get_json(f"{host}/object_info", timeout=120)
    return "DWPreprocessor" in info and "DiffControlNetLoader" in info and "ControlNetApplyAdvanced" in info


def build_openpose_map(host: str, plate_name: str, work: Path, tag: str) -> Path | None:
    """Full-plate OpenPose stick figure; None if preprocessor missing."""
    if not has_openpose_nodes(host):
        print("OPENPOSE_SKIP nodes missing", flush=True)
        return None
    graph = {
        "1": {"class_type": "LoadImage", "inputs": {"image": plate_name}},
        "12": {
            "class_type": "DWPreprocessor",
            "inputs": {
                "image": ["1", 0],
                "detect_hand": "enable",
                "detect_body": "enable",
                "detect_face": "disable",
                "resolution": 1024,
                "bbox_detector": "yolox_l.onnx",
                "pose_estimator": "dw-ll_ucoco_384.onnx",
                "scale_stick_for_xinsr_cn": "enable",
            },
        },
        "22": {"class_type": "SaveImage", "inputs": {"images": ["12", 0], "filename_prefix": f"{tag}-pose"}},
    }
    try:
        got = base.run_graph(host, graph, {"pose": "22"}, work, f"{tag}-pose")
        print(f"OPENPOSE_MAP {got['pose']}", flush=True)
        return got["pose"]
    except SystemExit as exc:
        print(f"OPENPOSE_FAIL {str(exc)[:200]}", flush=True)
        return None


def inpaint_crop_graph_openpose(
    *,
    ckpt: str,
    crop_name: str,
    mask_name: str,
    pose_crop_name: str,
    pose_cn: str,
    positive: str,
    negative: str,
    seed: int,
    prefix: str,
    denoise: float,
    cfg: float,
    strength: float = R1_OPENPOSE_STRENGTH,
) -> dict:
    """Fooocus inpaint on crop with OpenPose ControlNet from a pose crop of the same box."""
    graph = inpaint_crop_graph(
        ckpt=ckpt,
        crop_name=crop_name,
        mask_name=mask_name,
        positive=positive,
        negative=negative,
        seed=seed,
        prefix=prefix,
        denoise=denoise,
        fooocus=True,
        differential=False,
        masked_fill=True,
        fill_mode="neutral",
        lama_prefill=False,
        cfg=cfg,
    )
    # Wire ControlNet onto the conditioned positives before KSampler.
    graph["80"] = {"class_type": "LoadImage", "inputs": {"image": pose_crop_name}}
    graph["81"] = {
        "class_type": "DiffControlNetLoader",
        "inputs": {"model": ["3", 0], "control_net_name": pose_cn},
    }
    graph["82"] = {
        "class_type": "ControlNetApplyAdvanced",
        "inputs": {
            "positive": ["40", 0],
            "negative": ["40", 1],
            "control_net": ["81", 0],
            "image": ["80", 0],
            "strength": strength,
            "start_percent": 0.0,
            "end_percent": 0.85,
        },
    }
    graph["15"]["inputs"]["positive"] = ["82", 0]
    graph["15"]["inputs"]["negative"] = ["82", 1]
    return graph


def inpaint_band_r1(
    host: str,
    models: dict,
    plate: Image.Image,
    band: np.ndarray,
    *,
    positive: str,
    negative: str,
    seed: int,
    stem: str,
    denoise: float,
    edge: bool,
    input_dir: Path,
    out_dir: Path,
    pose_full: Image.Image | None,
    pose_cn: str | None,
    openpose_strength: float = R1_OPENPOSE_STRENGTH,
) -> Image.Image:
    mask = sem.feather(sem.dilate(band, base.BAND_GROW if not edge else 0), radius=legacy.MASK_BLUR)
    prepared = legacy.prepare_job(stem, plate, mask, input_dir)
    for filename in (prepared["crop_name"], prepared["crop_mask"]):
        base.upload(host, input_dir / filename)
    use_pose = bool(pose_full is not None and pose_cn and not edge)
    if use_pose:
        box = prepared["job"].orig_box
        pose_crop = pose_full.crop(box).resize(
            (prepared["job"].canvas.size[0], prepared["job"].canvas.size[1]),
            Image.Resampling.NEAREST,
        )
        pose_name = f"{stem}-pose-crop.png"
        pose_crop.save(input_dir / pose_name)
        base.upload(host, input_dir / pose_name)
        graph = inpaint_crop_graph_openpose(
            ckpt=models["ckpt"],
            crop_name=prepared["crop_name"],
            mask_name=prepared["crop_mask"],
            pose_crop_name=pose_name,
            pose_cn=pose_cn,
            positive=positive,
            negative=negative,
            seed=seed,
            prefix=stem,
            denoise=denoise,
            cfg=R1_CFG,
            strength=openpose_strength,
        )
        stage = "inpaint_openpose"
    elif edge:
        graph = inpaint_crop_graph(
            ckpt=models["ckpt"],
            crop_name=prepared["crop_name"],
            mask_name=prepared["crop_mask"],
            positive=positive,
            negative=negative,
            seed=seed,
            prefix=stem,
            denoise=denoise,
            fooocus=True,
            differential=True,
            masked_fill=False,
            lama_prefill=False,
            cfg=R1_CFG,
        )
        stage = "edge"
    else:
        graph = inpaint_crop_graph(
            ckpt=models["ckpt"],
            crop_name=prepared["crop_name"],
            mask_name=prepared["crop_mask"],
            positive=positive,
            negative=negative,
            seed=seed,
            prefix=stem,
            denoise=denoise,
            fooocus=True,
            differential=False,
            masked_fill=True,
            fill_mode="neutral",
            lama_prefill=False,
            cfg=R1_CFG,
        )
        stage = "inpaint"
    (out_dir / f"{stem}.api.json").write_text(
        json.dumps(legacy.envelope(graph, stem, stage), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    got = base.run_graph(host, graph, {"crop": "22"}, out_dir, stem)
    stitched = stitch(prepared["plate"], Image.open(got["crop"]), prepared["job"])
    print(
        f"PASS_R1 {stem} denoise={denoise} opaque={prepared['opaque_ratio']:.3f} "
        f"edge={edge} openpose={use_pose}",
        flush=True,
    )
    return stitched


def run_bands_r1(
    host: str,
    models: dict,
    plate: Image.Image,
    mask: np.ndarray,
    *,
    positive: str,
    negative: str,
    seed: int,
    stem: str,
    denoise: float,
    edge: bool,
    input_dir: Path,
    out_dir: Path,
    pose_full: Image.Image | None,
    pose_cn: str | None,
    lower: tuple[int, str, str] | None = None,
    openpose_strength: float = R1_OPENPOSE_STRENGTH,
) -> Image.Image:
    current = plate
    for i, band in enumerate(base.split_bands(mask)):
        band_pos, band_neg = positive, negative
        ys = np.nonzero(band.any(axis=1))[0]
        if ys.size and lower is not None and int(ys.min()) >= lower[0]:
            band_pos, band_neg = lower[1], lower[2]
        current = inpaint_band_r1(
            host,
            models,
            current,
            band,
            positive=band_pos,
            negative=band_neg,
            seed=seed + i,
            stem=f"{stem}-b{i}",
            denoise=denoise,
            edge=edge,
            input_dir=input_dir,
            out_dir=out_dir,
            pose_full=pose_full,
            pose_cn=pose_cn,
            openpose_strength=openpose_strength,
        )
    return current


def undress_one_r1(
    host: str,
    models: dict,
    actor: str,
    mode: str,
    out_dir: Path,
    input_dir: Path,
    *,
    attempt: int = 0,
) -> Path:
    base.check_host(host)
    plan = sem.PLANS[actor]
    stem = base.STEM[(actor, mode)]
    debug = out_dir / "debug"
    work = out_dir / "work"
    debug.mkdir(parents=True, exist_ok=True)
    work.mkdir(parents=True, exist_ok=True)
    plate_path = base.PLATE[actor]
    plate = Image.open(plate_path).convert("RGB")
    shape = (plate.height, plate.width)
    seed = R1_SEED + {"lin": 0, "elena": 200}[actor] + {"nude": 0, "torn": 400}[mode] + attempt * 1000

    evidence = base.segment(host, plate_path, plan, work, f"{stem}-r1-src", input_dir)
    garment = base.garment_from(plan, evidence, shape)
    share = float(garment.sum()) / float(shape[0] * shape[1])
    print(f"MASK_R1 {stem} garment_share={share:.4f}", flush=True)
    if share < 0.005:
        raise SystemExit(f"MASK_EMPTY {stem} garment_share={share:.5f}")
    if share > 0.48:
        raise SystemExit(f"MASK_SUSPECT {stem} garment_share={share:.5f}")
    sem.overlay(plate, garment).save(debug / f"{stem}-garment-overlay.png")
    sem.to_image(garment).save(debug / f"{stem}-garment-mask.png")

    meta: dict = {
        "pipeline": "community_r1",
        "actor": actor,
        "mode": mode,
        "attempt": attempt,
        "seed": seed,
        "denoise": R1_DENOISE,
        "garment_share": share,
        "passes": [],
        "forbid": PLAN["forbid"],
    }

    pose_cn = models.get("pose_cn")
    pose_full: Image.Image | None = None
    if mode == "nude":
        plate_name = f"{stem}-r1-plate.png"
        input_dir.mkdir(parents=True, exist_ok=True)
        plate.save(input_dir / plate_name)
        base.upload(host, input_dir / plate_name)
        pose_path = build_openpose_map(host, plate_name, work, stem)
        if pose_path and pose_path.exists():
            pose_full = Image.open(pose_path).convert("RGB").resize(plate.size, Image.Resampling.NEAREST)
            meta["openpose"] = True
        else:
            meta["openpose"] = False

    if mode == "torn":
        positive, negative = base.torn_text(actor)
        nude_stem = base.STEM[(actor, "nude")]
        base_path = out_dir / f"{nude_stem}.png"
        if not base_path.exists():
            base_path = undress_one_r1(host, models, actor, "nude", out_dir, input_dir, attempt=attempt)
        nude_img = Image.open(base_path).convert("RGB")
        target = sem.tear_mask(
            garment,
            seed=seed,
            fraction=plan.tear_fraction,
            keep_top_frac=plan.keep_top_frac,
            keep_bottom_frac=plan.keep_bottom_frac,
            anchors=plan.tear_anchors,
        )
        sem.overlay(plate, target, (40, 120, 220)).save(debug / f"{stem}-tear-overlay.png")
        current = Image.composite(nude_img, plate, sem.feather(target, radius=1))
        meta["base"] = base_path.name
        meta["passes"].append({"kind": "composite", "tear_fraction": plan.tear_fraction})
        rim = sem.edge_band(target, 16) & sem.dilate(garment, 6) & sem.box_array(shape, plan.roi)
        rim &= ~sem.box_array(shape, plan.face_clear)
        if plan.horse_guard_y:
            y_cut = int(plan.horse_guard_y / sem.BASE[1] * shape[0])
            rim[y_cut:, :] = False
        if rim.any():
            current = run_bands_r1(
                host,
                models,
                current,
                rim,
                positive=positive,
                negative=negative,
                seed=seed + 7,
                stem=f"{stem}-rim",
                denoise=TORN_RIM_DENOISE,
                edge=True,
                input_dir=input_dir,
                out_dir=work,
                pose_full=None,
                pose_cn=None,
            )
            meta["passes"].append({"kind": "rim", "denoise": TORN_RIM_DENOISE})
    else:
        positive, negative = base.nude_text(actor)
        denoise = R1_DENOISE
        edge_denoise = R1_EDGE_DENOISE
        pose_strength = R1_OPENPOSE_STRENGTH
        nude_passes = 1
        if actor == "elena":
            # Offline diagnosis 2026-10-09: mask covered torso (share≈0.21) but 0.82×1 kept
            # high-gloss metal. Match run6 full-replace intensity without LaMa residual.
            denoise = R1_ELENA_DENOISE
            edge_denoise = R1_ELENA_EDGE_DENOISE
            pose_strength = R1_ELENA_OPENPOSE_STRENGTH
            nude_passes = R1_ELENA_NUDE_PASSES
            negative = f"{negative}, {ELENA_METAL_NEG_EXTRA}"
        lower = (base.LOWER_FROM_Y[actor], base.LOWER_POS, base.LOWER_NEG) if actor in base.LOWER_FROM_Y else None
        target = garment.copy()
        if actor == "elena" and plan.horse_guard_y:
            y_cut = int(plan.horse_guard_y / sem.BASE[1] * shape[0])
            target[y_cut:, :] = False
            print(f"ELENA_CLIP_JUNCTION y>={y_cut}", flush=True)
        # Fooocus only — no LaMa residual / pixelfill. Elena: multiple denoise-1.0 passes.
        current = plate
        for n in range(nude_passes):
            current = run_bands_r1(
                host,
                models,
                current,
                target,
                positive=positive,
                negative=negative,
                seed=seed + n * 17,
                stem=f"{stem}-r1-p{n}",
                denoise=denoise,
                edge=False,
                input_dir=input_dir,
                out_dir=work,
                pose_full=pose_full if n == 0 else None,  # pose only first pass
                pose_cn=pose_cn if n == 0 else None,
                lower=lower,
                openpose_strength=pose_strength,
            )
            meta["passes"].append(
                {
                    "kind": "nude_r1",
                    "n": n,
                    "denoise": denoise,
                    "openpose": bool(pose_full) and n == 0,
                    "openpose_strength": pose_strength if (pose_full and n == 0) else 0.0,
                }
            )
        edge_zone = sem.edge_band(target, 14) & sem.box_array(shape, plan.roi)
        edge_zone &= ~sem.box_array(shape, plan.face_clear)
        if actor == "elena" and plan.horse_guard_y:
            y_cut = int(plan.horse_guard_y / sem.BASE[1] * shape[0])
            edge_zone[y_cut:, :] = False
        if edge_zone.any():
            current = run_bands_r1(
                host,
                models,
                current,
                edge_zone,
                positive=base.NUDE_EDGE_POS,
                negative=base.NUDE_EDGE_NEG,
                seed=seed + 900,
                stem=f"{stem}-edge",
                denoise=edge_denoise,
                edge=True,
                input_dir=input_dir,
                out_dir=work,
                pose_full=None,
                pose_cn=None,
            )
            meta["passes"].append({"kind": "edge", "denoise": edge_denoise})

    dest = out_dir / f"{stem}.png"
    current.save(dest)
    (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"STITCH_R1 {dest} {dest.stat().st_size}", flush=True)
    print(f"VISUAL_JUDGE {actor} {mode} {dest}", flush=True)
    return dest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emit-plan", action="store_true")
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=base.DEFAULT_OUT)
    parser.add_argument("--input", type=Path, default=Path("/tmp/fox-centaur-r1-input"))
    parser.add_argument("--only", choices=("lin", "elena"), nargs="*")
    parser.add_argument("--mode", choices=("nude", "torn", "both"), default="both")
    parser.add_argument("--attempt", type=int, default=0)
    parser.add_argument("--check-stack", action="store_true")
    parser.add_argument(
        "--i-know-authorized",
        action="store_true",
        help="Required for remote generate (local Comfy only; no AutoDL power_on here).",
    )
    args = parser.parse_args()
    if args.emit_plan:
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        return
    if args.check_stack:
        base.check_host(args.host)
        missing = base.verify_stack(args.host)
        print(f"STACK_OK {missing}" if not missing else f"STACK_MISS {missing}", flush=True)
        if missing:
            raise SystemExit(1)
        return
    if not args.i_know_authorized:
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        print("R1_REFUSE: pass --i-know-authorized to generate on --host.", flush=True)
        raise SystemExit(0)

    base.check_host(args.host)
    missing = base.verify_stack(args.host)
    if missing:
        raise SystemExit(f"STACK_MISS {missing}")
    models = resolve_base_models(args.host)
    # pose_cn may raise if missing — soft-fail for openpose-only.
    try:
        if "pose_cn" not in models:
            models["pose_cn"] = resolve_base_models(args.host)["pose_cn"]
    except SystemExit:
        models.pop("pose_cn", None)
        print("POSE_CN_MISSING continuing without OpenPose", flush=True)

    actors = args.only or ["lin", "elena"]
    modes = ["nude", "torn"] if args.mode == "both" else [args.mode]
    args.out.mkdir(parents=True, exist_ok=True)
    args.input.mkdir(parents=True, exist_ok=True)
    for mode in modes:
        for actor in actors:
            undress_one_r1(
                args.host, models, actor, mode, args.out, args.input, attempt=args.attempt
            )


if __name__ == "__main__":
    main()
