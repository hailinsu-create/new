"""One-command semantic undress / tear for the fox and centaur stills.

    python run_fox_centaur_semantic.py --only lin elena --mode both

Run it on the Beijing B machine (ComfyUI on 127.0.0.1:8188). Per actor and mode:
semantic garment mask -> neutral MaskedFill -> Fooocus inpaint patch -> 1024
crop-and-stitch bands -> residual re-segmentation -> edge blend -> Codex score
sidecar. Scoring is Codex only; a missing CLI writes SCORE_FAILED and the images
still ship. F34 and G09 are never touched.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import codex_still_score as scorer  # noqa: E402
import scheme_still_fox_centaur_undress as legacy  # noqa: E402
import semantic_undress as sem  # noqa: E402
from comfy_util import get_json, post_json, resolve_base_models  # noqa: E402
from inpaint_crop import inpaint_crop_graph, stitch  # noqa: E402

STILL_DIR = legacy.STILL_DIR
DEFAULT_OUT = STILL_DIR / "semantic"
PLATE = {"lin": legacy.LIN_PLATE, "elena": legacy.ELENA_PLATE}
STEM = legacy.OUT_STEM
HEAD_BOX = {"lin": legacy.LIN_HEAD, "elena": legacy.ELENA_HEAD}

NUDE_DENOISE = 1.0
TORN_DENOISE = 0.96
EDGE_DENOISE = 0.42
BAND_HEIGHT = 420
BAND_GROW = 0  # the garment mask is already grown and protection-clipped
MAX_NUDE_PASSES = 3
RESIDUAL_OK = 0.05
SEED = 20261008
BANNED_HOST_PARTS = ("weste.seetacloud", "xaxna66hqt", "sa4eaxgcuq")


def nude_text(actor: str) -> tuple[str, str]:
    if actor == "lin":
        return legacy.LIN_NUDE_POS, legacy.LIN_NUDE_NEG
    return legacy.ELENA_NUDE_POS, legacy.ELENA_NUDE_NEG


def torn_text(actor: str) -> tuple[str, str]:
    if actor == "lin":
        return legacy.LIN_TORN_POS, legacy.LIN_TORN_NEG
    return legacy.ELENA_TORN_POS, legacy.ELENA_TORN_NEG


def check_host(host: str) -> None:
    if any(part in host for part in BANNED_HOST_PARTS):
        raise SystemExit(f"FORBIDDEN_HOST {host}")


def verify_stack(host: str) -> list[str]:
    info = get_json(f"{host}/object_info", timeout=120)
    return [name for name in sem.REQUIRED_NODES if name not in info]


def resolve_sam_model(host: str) -> str:
    """The SAM loader only accepts its own option labels, e.g. 'sam_vit_b (375MB)'. Pick the vit_b one."""
    info = get_json(f"{host}/object_info/{sem.SAM_LOADER_NODE}", timeout=60)[sem.SAM_LOADER_NODE]
    options = info["input"]["required"]["model_name"][0]
    for option in options:
        if "sam_vit_b" in option:
            return option
    raise SystemExit(f"NO_SAM_VIT_B options={options}")


def mask_source(host: str, class_type: str) -> tuple[str, int]:
    """(kind, slot) of the output that carries the mask. MASK first, then IMAGE."""
    info = get_json(f"{host}/object_info/{class_type}")[class_type]
    outputs = info.get("output") or []
    for kind in ("MASK", "IMAGE"):
        for i, name in enumerate(outputs):
            if name == kind:
                return kind, i
    raise SystemExit(f"NO_MASK_OUTPUT {class_type} {outputs}")


def upload(host: str, path: Path) -> None:
    legacy._upload(host, path)


def _fetch(host: str, image: dict, dest: Path) -> Path:
    query = urllib.parse.urlencode(
        {"filename": image["filename"], "subfolder": image.get("subfolder") or "", "type": image.get("type") or "output"}
    )
    dest.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(f"{host}/view?{query}", timeout=120) as response:
        dest.write_bytes(response.read())
    return dest


def run_graph(host: str, graph: dict, outputs: dict[str, str], work: Path, tag: str) -> dict[str, Path]:
    queued = post_json(f"{host}/prompt", {"prompt": graph, "client_id": f"fox-sem-{tag}"})
    prompt_id = queued.get("prompt_id")
    if not prompt_id:
        raise SystemExit(f"PROMPT_REJECTED {tag} {queued}")
    deadline = time.time() + 1500
    while time.time() < deadline:
        item = get_json(f"{host}/history/{prompt_id}").get(prompt_id)
        if item:
            status = item.get("status") or {}
            if status.get("status_str") == "error":
                raise SystemExit(f"RUN_FAILED {tag} {json.dumps(status)[:2000]}")
            if status.get("completed"):
                got: dict[str, Path] = {}
                for key, node in outputs.items():
                    images = ((item.get("outputs") or {}).get(node) or {}).get("images") or []
                    if not images:
                        raise SystemExit(f"NO_OUTPUT {tag} {key} node={node}")
                    got[key] = _fetch(host, images[0], work / f"{tag}-{key}.png")
                return got
        time.sleep(3)
    raise SystemExit(f"RUN_TIMEOUT {tag}")


def dino_by_prompt(
    host: str, name: str, prompts: tuple[str, ...], slot: int, work: Path, tag: str, size: tuple[int, int]
) -> dict[str, np.ndarray]:
    """All prompts in one graph. If a prompt with no hit fails the run, retry one by one and treat it as empty."""
    empty = np.zeros((size[1], size[0]), dtype=bool)

    def load(path: Path) -> np.ndarray:
        return sem.to_bool(Image.open(path).resize(size))

    graph = sem.dino_masks_graph(name, prompts, prefix=f"{tag}-dino", slot=slot)
    ids = sem.dino_save_ids(prompts)
    try:
        got = run_graph(host, graph, {f"p{i:02d}": ids[p] for i, p in enumerate(prompts)}, work, f"{tag}-dino")
        return {p: load(got[f"p{i:02d}"]) for i, p in enumerate(prompts)}
    except SystemExit as exc:
        print(f"DINO_BATCH_FAILED {tag} {str(exc)[:160]}; retry per prompt", flush=True)
    out: dict[str, np.ndarray] = {}
    for i, prompt in enumerate(prompts):
        single = sem.dino_masks_graph(name, (prompt,), prefix=f"{tag}-dino{i}", slot=slot)
        try:
            got = run_graph(host, single, {"p": sem.dino_save_ids((prompt,))[prompt]}, work, f"{tag}-dino{i}")
            out[prompt] = load(got["p"])
        except SystemExit as exc:
            print(f"DINO_EMPTY {tag} prompt={prompt!r} {str(exc)[:120]}", flush=True)
            out[prompt] = empty
    return out


def segment(host: str, image_path: Path, plan: sem.ActorPlan, work: Path, tag: str, input_dir: Path) -> sem.MaskEvidence:
    name = f"{tag}-seg-input.png"
    input_dir.mkdir(parents=True, exist_ok=True)
    Image.open(image_path).convert("RGB").save(input_dir / name)
    upload(host, input_dir / name)
    size = Image.open(image_path).size

    sem.SAM_MODEL = resolve_sam_model(host)
    seg_arr = None
    if plan.use_segformer:
        graph = sem.segformer_graph(name, prefix=f"{tag}-segformer")
        got = run_graph(
            host,
            graph,
            {"garment": sem.SEGFORMER_GARMENT_SAVE, "background": sem.SEGFORMER_BACKGROUND_SAVE},
            work,
            f"{tag}-segformer",
        )
        seg_arr = sem.segformer_garment(
            sem.to_bool(Image.open(got["garment"]).resize(size)),
            sem.to_bool(Image.open(got["background"]).resize(size)),
        )

    prompts = sem.all_dino_prompts(plan)
    _, dino_slot = mask_source(host, sem.DINO_SAM_NODE)
    by_prompt = dino_by_prompt(host, name, prompts, dino_slot, work, tag, size)
    return sem.split_evidence(plan, seg_arr, by_prompt)


def garment_from(plan: sem.ActorPlan, evidence: sem.MaskEvidence, shape: tuple[int, int]) -> np.ndarray:
    return sem.build_garment_mask(
        plan,
        shape,
        segformer=evidence.segformer,
        dino_garment=evidence.garment,
        dino_protect=evidence.protect,
        dino_horse=evidence.horse,
    )


def split_bands(mask: np.ndarray, band_height: int = BAND_HEIGHT) -> list[np.ndarray]:
    if not mask.any():
        return []
    ys = np.nonzero(mask.any(axis=1))[0]
    top, bottom = int(ys.min()), int(ys.max()) + 1
    count = max(1, -(-(bottom - top) // band_height))
    step = -(-(bottom - top) // count)
    bands = []
    for i in range(count):
        part = np.zeros_like(mask)
        lo, hi = top + i * step, min(bottom, top + (i + 1) * step)
        part[lo:hi, :] = mask[lo:hi, :]
        if part.sum() > 200:
            bands.append(part)
    return bands


def inpaint_band(
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
) -> Image.Image:
    mask = sem.feather(sem.dilate(band, BAND_GROW if not edge else 0), radius=legacy.MASK_BLUR)
    prepared = legacy.prepare_job(stem, plate, mask, input_dir)
    for filename in (prepared["crop_name"], prepared["crop_mask"]):
        upload(host, input_dir / filename)
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
        differential=edge,
        masked_fill=not edge,
        fill_mode="neutral",
    )
    (out_dir / f"{stem}.api.json").write_text(
        json.dumps(legacy.envelope(graph, stem, "edge" if edge else "inpaint"), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    got = run_graph(host, graph, {"crop": "22"}, out_dir, stem)
    stitched = stitch(prepared["plate"], Image.open(got["crop"]), prepared["job"])
    print(f"PASS {stem} denoise={denoise} opaque={prepared['opaque_ratio']:.3f} edge={edge}", flush=True)
    return stitched


def run_bands(
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
) -> Image.Image:
    current = plate
    for i, band in enumerate(split_bands(mask)):
        current = inpaint_band(
            host,
            models,
            current,
            band,
            positive=positive,
            negative=negative,
            seed=seed + i,
            stem=f"{stem}-b{i}",
            denoise=denoise,
            edge=edge,
            input_dir=input_dir,
            out_dir=out_dir,
        )
    return current


def undress_one(
    host: str,
    models: dict,
    actor: str,
    mode: str,
    out_dir: Path,
    input_dir: Path,
    *,
    attempt: int,
) -> Path:
    plan = sem.PLANS[actor]
    stem = STEM[(actor, mode)]
    debug = out_dir / "debug"
    debug.mkdir(parents=True, exist_ok=True)
    work = out_dir / "work"
    work.mkdir(parents=True, exist_ok=True)
    plate_path = PLATE[actor]
    plate = Image.open(plate_path).convert("RGB")
    shape = (plate.height, plate.width)
    seed = SEED + {"lin": 0, "elena": 200}[actor] + {"nude": 0, "torn": 400}[mode] + attempt * 1000

    evidence = segment(host, plate_path, plan, work, f"{stem}-a{attempt}-src", input_dir)
    garment = garment_from(plan, evidence, shape)
    share = float(garment.sum()) / float(shape[0] * shape[1])
    print(f"MASK {stem} garment_share={share:.4f}", flush=True)
    if share < 0.005:
        raise SystemExit(f"MASK_EMPTY {stem} garment_share={share:.5f}")
    if share > 0.35:
        raise SystemExit(f"MASK_SUSPECT {stem} garment_share={share:.5f}; check the SegFormer output slot")
    sem.overlay(plate, garment).save(debug / f"{stem}-garment-overlay.png")
    sem.to_image(garment).save(debug / f"{stem}-garment-mask.png")

    meta: dict = {
        "actor": actor,
        "mode": mode,
        "attempt": attempt,
        "seed": seed,
        "garment_share": share,
        "passes": [],
    }
    if mode == "torn":
        positive, negative = torn_text(actor)
        target = sem.tear_mask(
            garment,
            seed=seed,
            fraction=plan.tear_fraction,
            keep_top_frac=plan.keep_top_frac,
            keep_bottom_frac=plan.keep_bottom_frac,
        )
        sem.overlay(plate, target, (40, 120, 220)).save(debug / f"{stem}-tear-overlay.png")
        current = run_bands(
            host, models, plate, target,
            positive=positive, negative=negative, seed=seed, stem=f"{stem}-torn",
            denoise=TORN_DENOISE, edge=False, input_dir=input_dir, out_dir=work,
        )
        meta["passes"].append({"kind": "torn", "denoise": TORN_DENOISE, "tear_fraction": plan.tear_fraction})
        edge_target = target
    else:
        positive, negative = nude_text(actor)
        current = plate
        target = garment
        for n in range(MAX_NUDE_PASSES):
            current = run_bands(
                host, models, current, target,
                positive=positive, negative=negative, seed=seed + n * 50, stem=f"{stem}-p{n}",
                denoise=NUDE_DENOISE, edge=False, input_dir=input_dir, out_dir=work,
            )
            tmp = work / f"{stem}-p{n}-result.png"
            current.save(tmp)
            again = segment(host, tmp, plan, work, f"{stem}-a{attempt}-chk{n}", input_dir)
            left = garment_from(plan, again, shape)
            ratio = sem.residual_ratio(garment, left)
            meta["passes"].append({"kind": "nude", "n": n, "denoise": NUDE_DENOISE, "residual_ratio": round(ratio, 4)})
            print(f"RESIDUAL {stem} pass={n} ratio={ratio:.4f}", flush=True)
            if ratio < RESIDUAL_OK:
                break
            target = left
        edge_target = garment

    edge_zone = sem.edge_band(edge_target, 14) & sem.box_array(shape, plan.roi)
    face = sem.box_array(shape, plan.face_clear)
    edge_zone &= ~face
    current = run_bands(
        host, models, current, edge_zone,
        positive=legacy.EDGE_POS, negative=legacy.EDGE_NEG, seed=seed + 900, stem=f"{stem}-edge",
        denoise=EDGE_DENOISE, edge=True, input_dir=input_dir, out_dir=work,
    )
    meta["passes"].append({"kind": "edge", "denoise": EDGE_DENOISE})

    dest = out_dir / f"{stem}.png"
    current.save(dest)
    (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"STITCH {dest} {dest.stat().st_size}", flush=True)
    return dest


def already_passed(out_dir: Path, stem: str) -> bool:
    sidecar = out_dir / f"{stem}.json"
    if not sidecar.exists():
        return False
    try:
        return bool(json.loads(sidecar.read_text(encoding="utf-8")).get("passed"))
    except json.JSONDecodeError:
        return False


def emit_examples(directory: Path) -> None:
    """Static API graphs for the ComfyUI UI. Node output slots follow /object_info at run time."""
    directory.mkdir(parents=True, exist_ok=True)
    ckpt = "RealVisXL_V5.0_fp16.safetensors"
    why = "Semantic undress. Output slot for MASK is resolved from /object_info by the runner; slot 1 shown here."

    def dump(name: str, prompt: dict, **extra: object) -> None:
        body = {"source": {"why": why, "doc": "docs/fox-centaur-semantic-undress.md", **extra}, "prompt": prompt}
        (directory / name).write_text(json.dumps(body, ensure_ascii=False, indent=2), encoding="utf-8")

    dump("scheme-semantic-segformer.api.json", sem.segformer_graph("plate.png"), stage="garment mask 1")
    for actor, plan in sem.PLANS.items():
        prompts = sem.all_dino_prompts(plan)
        dump(
            f"scheme-semantic-dino-{actor}.api.json",
            sem.dino_masks_graph("plate.png", prompts),
            stage="garment mask 2 + protect",
            prompts=list(prompts),
            save_ids=sem.dino_save_ids(prompts),
        )
        for mode, (pos, neg), denoise in (
            ("nude", nude_text(actor), NUDE_DENOISE),
            ("torn", torn_text(actor), TORN_DENOISE),
        ):
            graph = inpaint_crop_graph(
                ckpt=ckpt, crop_name="band-crop.png", mask_name="band-crop-mask.png",
                positive=pos, negative=neg, seed=SEED, prefix=f"{actor}-{mode}",
                denoise=denoise, fooocus=True, differential=False, masked_fill=True, fill_mode="neutral",
            )
            dump(f"scheme-semantic-inpaint-{actor}-{mode}.api.json", graph, stage="neutral fill + Fooocus", denoise=denoise)
    edge = inpaint_crop_graph(
        ckpt=ckpt, crop_name="edge-crop.png", mask_name="edge-crop-mask.png",
        positive=legacy.EDGE_POS, negative=legacy.EDGE_NEG, seed=SEED, prefix="edge",
        denoise=EDGE_DENOISE, fooocus=True, differential=True, masked_fill=False,
    )
    dump("scheme-semantic-edge.api.json", edge, stage="edge blend", denoise=EDGE_DENOISE)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--input", type=Path, default=Path("/tmp/fox-centaur-semantic-input"))
    parser.add_argument("--only", choices=("lin", "elena"), nargs="*")
    parser.add_argument("--mode", choices=("nude", "torn", "both"), default="both")
    parser.add_argument("--attempt", type=int, default=0, help="Bumps every seed. Use for a single-image retry.")
    parser.add_argument("--resume", action="store_true", help="Skip stills whose sidecar already passed.")
    parser.add_argument("--check-stack", action="store_true", help="Only list missing ComfyUI nodes, then exit.")
    parser.add_argument("--no-score", action="store_true", help="Generate only.")
    parser.add_argument("--score-only", action="store_true", help="Score existing PNGs in --out. No ComfyUI needed.")
    parser.add_argument("--emit-examples", type=Path, help="Write the API graphs to this directory and exit.")
    args = parser.parse_args()
    check_host(args.host)
    if args.emit_examples:
        emit_examples(args.emit_examples)
        return

    actors = args.only or ["lin", "elena"]
    modes = ["nude", "torn"] if args.mode == "both" else [args.mode]
    # Nude first for both actors, then torn, as agreed for this pipeline.
    order = [(a, m) for m in modes for a in actors]
    args.out.mkdir(parents=True, exist_ok=True)

    if args.score_only:
        for actor, mode in order:
            image = args.out / f"{STEM[(actor, mode)]}.png"
            if image.exists():
                scorer.score_image(actor, mode, image)
        return

    missing = verify_stack(args.host)
    if args.check_stack:
        print("STACK_MISSING" if missing else "STACK_OK", missing)
        raise SystemExit(1 if missing else 0)
    if missing:
        raise SystemExit(f"STACK_MISSING {missing}")

    models = resolve_base_models(args.host)
    print("MODELS", json.dumps(models, ensure_ascii=False), flush=True)
    for actor, mode in order:
        stem = STEM[(actor, mode)]
        if args.resume and already_passed(args.out, stem):
            print(f"SKIP {stem} already passed", flush=True)
            continue
        try:
            image = undress_one(args.host, models, actor, mode, args.out, args.input, attempt=args.attempt)
        except SystemExit as exc:
            print(f"FAILED {stem} {exc}", flush=True)
            continue
        if not args.no_score:
            scorer.score_image(actor, mode, image)


if __name__ == "__main__":
    main()
