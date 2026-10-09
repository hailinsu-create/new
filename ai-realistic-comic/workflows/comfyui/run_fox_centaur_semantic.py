"""One-command semantic undress / tear for the fox and centaur stills.

    python run_fox_centaur_semantic.py --only lin elena --mode both

Run it on the Beijing B machine (ComfyUI on 127.0.0.1:8188). Per actor and mode:
semantic garment mask -> neutral MaskedFill -> Fooocus inpaint patch -> 1024
crop-and-stitch bands -> residual re-segmentation (LaMa + weak touch only) ->
edge blend -> optional tiny collar/hip pixelfill.

No numeric scoring gate. Usability is decided by Cursor looking at the PNGs
(visual judgment). ``--score`` is retained only as a legacy no-op opt-in.
F34 and G09 are never touched.
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
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import scheme_still_fox_centaur_undress as legacy  # noqa: E402
import semantic_undress as sem  # noqa: E402
from comfy_util import get_json, post_json, resolve_base_models  # noqa: E402
from inpaint_crop import inpaint_crop_graph, lama_only_graph, stitch  # noqa: E402


def pixel_skin_fill(
    image: Image.Image,
    mask: np.ndarray,
    sample_box: tuple[int, int, int, int],
    *,
    blur: int = 5,
    noise_std: float = 3.0,
    seed: int = 0,
) -> Image.Image:
    """Replace mask pixels with skin sampled from sample_box (Fooocus redraws collars/armor)."""
    if not mask.any():
        return image
    arr = np.asarray(image.convert("RGB")).astype(np.float32)
    x0, y0, x1, y1 = sample_box
    patch = arr[y0:y1, x0:x1].reshape(-1, 3)
    if patch.size == 0:
        return image
    mean = patch.mean(axis=0)
    rng = np.random.default_rng(seed)
    noise = rng.normal(0.0, noise_std, arr.shape).astype(np.float32)
    filled = arr.copy()
    filled[mask] = mean + noise[mask]
    filled = np.clip(filled, 0, 255)
    alpha = np.asarray(
        Image.fromarray((mask.astype(np.uint8) * 255)).filter(ImageFilter.GaussianBlur(radius=blur))
    ).astype(np.float32) / 255.0
    out = filled * alpha[..., None] + arr * (1.0 - alpha[..., None])
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


STILL_DIR = legacy.STILL_DIR
DEFAULT_OUT = STILL_DIR / "semantic"
PLATE = {"lin": legacy.LIN_PLATE, "elena": legacy.ELENA_PLATE}
STEM = legacy.OUT_STEM
HEAD_BOX = {"lin": legacy.LIN_HEAD, "elena": legacy.ELENA_HEAD}

NUDE_DENOISE = 1.0
NUDE_CFG = 5.5
# Residual: LaMa hard-erase first. Tiny leftovers → weak touch 0.35; large leftovers →
# Fooocus 0.72 (partial rollback from P0/P1: pure 0.35 left clothes/armor; full 0.88 smeared).
RESIDUAL_FOOOCUS_DENOISE = 0.72
RESIDUAL_TOUCH_DENOISE = 0.35
RESIDUAL_TOUCH_CFG = 4.0
LAMA_RESIDUAL_MAX_RATIO = 0.20
LAMA_RESIDUAL_MAX_PIXELS = 25000
LEG_SOFT_DENOISE = 0.32
LEG_SOFT_CFG = 4.0
LEG_SOFT_MAX_PX = 40000
# Hip pixelfill: allow run13-scale leftover∩hip islands (old best ~89k).
HIP_PIXELFILL_MAX_PX = 100000
# Buffer above Elena horse_guard_y (was 48 in P0/P1; 16 historically). 24 balances seam vs cleanup.
ELENA_JUNCTION_BUFFER = 24
TORN_RIM_DENOISE = 0.30
EDGE_DENOISE = 0.32
BAND_HEIGHT = 420
BAND_GROW = 0  # the garment mask is already grown and protection-clipped
MAX_NUDE_PASSES = 4
RESIDUAL_OK = 0.05
RESIDUAL_MIN_PIXELS = 3500
RESIDUAL_REDO_GROW = {"lin": 8, "elena": 6}
MAX_RESIDUAL_PASSES = {"lin": 2, "elena": 2}
SEED = 20261008
BANNED_HOST_PARTS = ("weste.seetacloud", "xaxna66hqt", "sa4eaxgcuq")


def nude_text(actor: str) -> tuple[str, str]:
    if actor == "lin":
        return legacy.LIN_NUDE_POS, legacy.LIN_NUDE_NEG
    return legacy.ELENA_NUDE_POS, legacy.ELENA_NUDE_NEG


# Below the hips the first-pass prompt (breasts, nipples, navel) is wrong and the model re-draws the skirt
# panels hanging beside the legs, so lower bands get their own text. Lin's hips sit near y=640 on the plate.
LOWER_FROM_Y = {"lin": 640}
LOWER_POS = (
    "bare legs, smooth bare thighs, knees and calves, skin tone matches the neck, same adult woman, "
    "one person only"
)
LOWER_NEG = (
    "skirt, long skirt, dress, hem, slit, hanging fabric, cloth panel, floral print, blue and white porcelain "
    "pattern, embroidery, silk, qipao, cheongsam, stockings, leggings, panties, child, teen, extra legs, "
    "handbag, bag, box, luggage, sash, apron, extra person, smear, plastic, text, watermark"
)
NUDE_EDGE_POS = "matching bare skin, seamless blend to surrounding skin and background"
NUDE_EDGE_NEG = "seam, hard edge, cloth, fabric, hem, smear, blur, plastic, text, watermark, extra limbs"

# Lin collar band (below face_clear, above the bosom). First pass uses this instead of breast wording.
COLLAR_TO_Y = {"lin": 395}
COLLAR_POS = (
    "bare neck and upper chest skin only, skin tone matches the face and neck, smooth collarbone, "
    "same adult woman, one person only"
)
COLLAR_NEG = (
    "collar, mandarin collar, qipao neckline, embroidery, silk ribbon, buttons, frog closure, "
    "dress fabric, child, teen, extra person, smear, plastic, text, watermark"
)
RESIDUAL_SKIN_POS = (
    "smooth fair bare skin only, skin pores, skin tone matches the neck, natural breasts, "
    "no fabric print on skin, same adult woman, one person only"
)
RESIDUAL_SKIN_NEG = (
    "clothes, dress, qipao, cheongsam, armor, plate, glove, bracer, sleeve, strap, fabric, "
    "embroidery, lace, sheer fabric, blue and white porcelain pattern, floral print on skin, "
    "watercolor print on skin, fabric pattern, leather texture, "
    "marbled meat, roasted meat texture, fur texture on torso, metal, mail, translucent skin, "
    "child, teen, extra person, smear, plastic, text, watermark"
)

# The rim pass only repaints a narrow band along each hole, so it needs edge wording, not "heavily torn dress".
LIN_RIM_POS = (
    "ragged torn qipao silk edge, frayed threads, jagged tear along the hole, fabric curling away from bare skin, "
    "same adult woman, one person only"
)
LIN_RIM_NEG = "intact dress, smooth hem, seam, child, teen, extra person, smear, plastic, text, watermark"
ELENA_RIM_POS = (
    "broken jagged golden armor plate edge around the hole, bent cracked metal rim, bare skin showing through, "
    "same adult woman, one person only"
)
ELENA_RIM_NEG = "intact armor, smooth plate, seam, child, teen, extra person, smear, plastic, text, watermark"


def torn_text(actor: str) -> tuple[str, str]:
    if actor == "lin":
        return LIN_RIM_POS, LIN_RIM_NEG
    return ELENA_RIM_POS, ELENA_RIM_NEG


def check_host(host: str) -> None:
    if any(part in host for part in BANNED_HOST_PARTS):
        raise SystemExit(f"FORBIDDEN_HOST {host}")


def verify_stack(host: str) -> list[str]:
    info = get_json(f"{host}/object_info", timeout=120)
    return [name for name in sem.REQUIRED_NODES if name not in info]


def resolve_sam_model(host: str) -> str:
    """The SAM loader only accepts its own option labels, e.g. 'sam_vit_b (375MB)'. Pick the vit_b one."""
    info = get_json(f"{host}/object_info/{urllib.parse.quote(sem.SAM_LOADER_NODE)}", timeout=60)[sem.SAM_LOADER_NODE]
    options = info["input"]["required"]["model_name"][0]
    for option in options:
        if "sam_vit_b" in option:
            return option
    raise SystemExit(f"NO_SAM_VIT_B options={options}")


def mask_source(host: str, class_type: str) -> tuple[str, int]:
    """(kind, slot) of the output that carries the mask. MASK first, then IMAGE."""
    info = get_json(f"{host}/object_info/{urllib.parse.quote(class_type)}")[class_type]
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
    failed = 0
    for i, prompt in enumerate(prompts):
        single = sem.dino_masks_graph(name, (prompt,), prefix=f"{tag}-dino{i}", slot=slot)
        try:
            got = run_graph(host, single, {"p": sem.dino_save_ids((prompt,))[prompt]}, work, f"{tag}-dino{i}")
            out[prompt] = load(got["p"])
        except SystemExit as exc:
            print(f"DINO_EMPTY {tag} prompt={prompt!r} {str(exc)[:120]}", flush=True)
            out[prompt] = empty
            failed += 1
    if failed == len(prompts):
        raise SystemExit(f"DINO_ALL_FAILED {tag}: every prompt errored, this is a broken node and not an empty detection")
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
        grow=plan.mask_grow,
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
    cfg: float | None = None,
    lama_prefill: bool = False,
    lama_only: bool = False,
) -> Image.Image:
    mask = sem.feather(sem.dilate(band, BAND_GROW if not edge else 0), radius=legacy.MASK_BLUR)
    prepared = legacy.prepare_job(stem, plate, mask, input_dir)
    for filename in (prepared["crop_name"], prepared["crop_mask"]):
        upload(host, input_dir / filename)
    if lama_only:
        graph = lama_only_graph(prepared["crop_name"], prepared["crop_mask"], seed, stem)
        stage = "lama"
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
            differential=edge,
            masked_fill=not (edge or lama_prefill),
            fill_mode="neutral",
            lama_prefill=lama_prefill,
            **({"cfg": cfg} if cfg is not None else {}),
        )
        stage = "edge" if edge else "inpaint"
    (out_dir / f"{stem}.api.json").write_text(
        json.dumps(legacy.envelope(graph, stem, stage), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    got = run_graph(host, graph, {"crop": "22"}, out_dir, stem)
    stitched = stitch(prepared["plate"], Image.open(got["crop"]), prepared["job"])
    print(
        f"PASS {stem} denoise={denoise} opaque={prepared['opaque_ratio']:.3f} edge={edge} "
        f"lama_only={lama_only} lama_prefill={lama_prefill}",
        flush=True,
    )
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
    lower: tuple[int, str, str] | None = None,
    collar: tuple[int, str, str] | None = None,
    cfg: float | None = None,
    lama_prefill: bool = False,
    lama_only: bool = False,
) -> Image.Image:
    current = plate
    for i, band in enumerate(split_bands(mask)):
        band_positive, band_negative = positive, negative
        ys = np.nonzero(band.any(axis=1))[0]
        if ys.size:
            y0 = int(ys.min())
            y1 = int(ys.max())
            if collar is not None and y1 <= collar[0]:
                band_positive, band_negative = collar[1], collar[2]
            elif lower is not None and y0 >= lower[0]:
                band_positive, band_negative = lower[1], lower[2]
        current = inpaint_band(
            host,
            models,
            current,
            band,
            positive=band_positive,
            negative=band_negative,
            seed=seed + i,
            stem=f"{stem}-b{i}",
            denoise=denoise,
            edge=edge,
            input_dir=input_dir,
            out_dir=out_dir,
            cfg=cfg,
            lama_prefill=lama_prefill,
            lama_only=lama_only,
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
    if share > 0.48:
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
        nude_stem = STEM[(actor, "nude")]
        base_path = out_dir / f"{nude_stem}.png"
        # Scoring cancelled: torn always builds from the nude PNG. Cursor judges usability visually.
        if not base_path.exists():
            base_path = undress_one(host, models, actor, "nude", out_dir, input_dir, attempt=attempt)
        base = Image.open(base_path).convert("RGB")
        target = sem.tear_mask(
            garment,
            seed=seed,
            fraction=plan.tear_fraction,
            keep_top_frac=plan.keep_top_frac,
            keep_bottom_frac=plan.keep_bottom_frac,
            anchors=plan.tear_anchors,
        )
        sem.overlay(plate, target, (40, 120, 220)).save(debug / f"{stem}-tear-overlay.png")
        # Holes show the nude render; hole centres are never re-Fooocus'd. Rim only.
        current = Image.composite(base, plate, sem.feather(target, radius=1))
        meta["base"] = base_path.name
        meta["passes"].append({"kind": "composite", "tear_fraction": plan.tear_fraction})
        rim = sem.edge_band(target, 16) & sem.dilate(garment, 6) & sem.box_array(shape, plan.roi)
        rim &= ~sem.box_array(shape, plan.face_clear)
        junction = np.zeros(shape, dtype=bool)
        if plan.horse_guard_y:
            y_cut = int(plan.horse_guard_y / sem.BASE[1] * shape[0])
            rim[y_cut:, :] = False
            # Band around the human/horse seam: LaMa only, no Fooocus (avoids fleshy lumps).
            junction[max(0, y_cut - 40) : y_cut, :] = True
            junction &= sem.edge_band(target, 16) & sem.dilate(garment, 6) & sem.box_array(shape, plan.roi)
            junction &= ~sem.box_array(shape, plan.face_clear)
        rim_fooocus = rim & ~junction
        if junction.any():
            current = run_bands(
                host, models, current, junction,
                positive=positive, negative=negative, seed=seed, stem=f"{stem}-rim-lama",
                denoise=0.0, edge=False, input_dir=input_dir, out_dir=work, lama_only=True,
            )
            meta["passes"].append({"kind": "rim_lama_junction"})
        if rim_fooocus.any():
            current = run_bands(
                host, models, current, rim_fooocus,
                positive=positive, negative=negative, seed=seed + 7, stem=f"{stem}-rim",
                denoise=TORN_RIM_DENOISE, edge=True, input_dir=input_dir, out_dir=work,
            )
            meta["passes"].append({"kind": "rim", "denoise": TORN_RIM_DENOISE})
        edge_target = None
    else:
        positive, negative = nude_text(actor)
        lower = (LOWER_FROM_Y[actor], LOWER_POS, LOWER_NEG) if actor in LOWER_FROM_Y else None
        collar = (COLLAR_TO_Y[actor], COLLAR_POS, COLLAR_NEG) if actor in COLLAR_TO_Y else None
        base = plate
        target = garment.copy()
        # Keep mare below horse_guard_y out of the hole. Do NOT raise the cut (old -48 left
        # fauld/waist armor unmasked → floating junction plates).
        if actor == "elena" and plan.horse_guard_y:
            y_cut = int(plan.horse_guard_y / sem.BASE[1] * shape[0])
            target[y_cut:, :] = False
            print(f"ELENA_CLIP_JUNCTION y>={y_cut}", flush=True)
        best_ratio = float("inf")
        best_image, best_left = plate, garment
        max_res = MAX_RESIDUAL_PASSES.get(actor, 2)
        for n in range(MAX_NUDE_PASSES):
            if n == 0:
                # 420px bands rarely sit entirely above COLLAR_TO_Y, so split the collar mask explicitly.
                current = base
                if collar is not None:
                    collar_cut = collar[0]
                    collar_mask = target.copy()
                    collar_mask[collar_cut:, :] = False
                    body_mask = target.copy()
                    body_mask[:collar_cut, :] = False
                    if collar_mask.any():
                        current = run_bands(
                            host, models, current, collar_mask,
                            positive=collar[1], negative=collar[2], seed=seed, stem=f"{stem}-p0c",
                            denoise=NUDE_DENOISE, edge=False, input_dir=input_dir, out_dir=work,
                            cfg=NUDE_CFG, lama_prefill=True,
                        )
                    if body_mask.any():
                        current = run_bands(
                            host, models, current, body_mask,
                            positive=positive, negative=negative, seed=seed + 11, stem=f"{stem}-p0",
                            denoise=NUDE_DENOISE, edge=False, input_dir=input_dir, out_dir=work,
                            lower=lower, cfg=NUDE_CFG, lama_prefill=True,
                        )
                else:
                    current = run_bands(
                        host, models, current, target,
                        positive=positive, negative=negative, seed=seed, stem=f"{stem}-p0",
                        denoise=NUDE_DENOISE, edge=False, input_dir=input_dir, out_dir=work,
                        lower=lower, cfg=NUDE_CFG, lama_prefill=True,
                    )
                meta["passes"].append({"kind": "nude", "n": 0, "denoise": NUDE_DENOISE, "lama_prefill": True})
            else:
                grow_px = RESIDUAL_REDO_GROW.get(actor, 12)
                redo_mask = sem.dilate(target, grow_px) & sem.box_array(shape, plan.roi)
                redo_mask &= ~sem.box_array(shape, plan.face_clear)
                if plan.horse_guard_y:
                    y_cut = int(plan.horse_guard_y / sem.BASE[1] * shape[0])
                    # Freeze junction: residual must stay well above the human/horse seam.
                    buf = int(ELENA_JUNCTION_BUFFER / sem.BASE[1] * shape[0])
                    redo_mask[max(0, y_cut - buf) :, :] = False
                # Lin: torso residual above hips only. Skirt Fooocus abandoned (extra_limb);
                # tiny hip leftovers use pixelfill later; legs get a soft polish pass.
                if actor == "lin":
                    hip_cut = int(720 / sem.BASE[1] * shape[0])
                    redo_mask[hip_cut:, :] = False
                if not redo_mask.any():
                    print(f"RESIDUAL_SKIP_EMPTY {stem} pass={n} (protected zones)", flush=True)
                    break

                def _lama_then_residual(img, mask, pos, neg, tag: str):
                    """LaMa erase, then touch (tiny) or Fooocus 0.72 (large leftover) — P0/P1 partial rollback."""
                    if not mask.any():
                        return img
                    img = run_bands(
                        host, models, img, mask,
                        positive=pos, negative=neg, seed=seed + n * 50 + 1,
                        stem=f"{stem}-p{n}{tag}lama", denoise=0.0, edge=False,
                        input_dir=input_dir, out_dir=work, lama_only=True,
                    )
                    meta["passes"].append({"kind": f"lama_{tag}", "n": n, "pixels": int(mask.sum())})
                    leftover_px = int(mask.sum())
                    tiny = best_ratio <= LAMA_RESIDUAL_MAX_RATIO and leftover_px <= LAMA_RESIDUAL_MAX_PIXELS
                    if tiny:
                        img = run_bands(
                            host, models, img, mask,
                            positive=pos, negative=neg, seed=seed + n * 50 + 3,
                            stem=f"{stem}-p{n}{tag}touch", denoise=RESIDUAL_TOUCH_DENOISE, edge=True,
                            input_dir=input_dir, out_dir=work, cfg=RESIDUAL_TOUCH_CFG,
                        )
                        meta["passes"].append(
                            {"kind": f"touch_{tag}", "n": n, "denoise": RESIDUAL_TOUCH_DENOISE, "pixels": leftover_px}
                        )
                    else:
                        print(
                            f"RESIDUAL_FOOOCUS {stem} pass={n} tag={tag} ratio={best_ratio:.4f} "
                            f"grown={leftover_px} denoise={RESIDUAL_FOOOCUS_DENOISE}",
                            flush=True,
                        )
                        img = run_bands(
                            host, models, img, mask,
                            positive=pos, negative=neg, seed=seed + n * 50 + 7,
                            stem=f"{stem}-p{n}{tag}redo", denoise=RESIDUAL_FOOOCUS_DENOISE, edge=False,
                            input_dir=input_dir, out_dir=work, cfg=NUDE_CFG, lama_prefill=True,
                        )
                        meta["passes"].append(
                            {
                                "kind": f"fooocus_{tag}",
                                "n": n,
                                "denoise": RESIDUAL_FOOOCUS_DENOISE,
                                "pixels": leftover_px,
                            }
                        )
                    return img

                current = base
                current = _lama_then_residual(current, redo_mask, RESIDUAL_SKIN_POS, RESIDUAL_SKIN_NEG, "torso")
            tmp = work / f"{stem}-p{n}-result.png"
            current.save(tmp)
            check_plan = sem.residual_plan(plan)
            again = segment(host, tmp, check_plan, work, f"{stem}-a{attempt}-chk{n}", input_dir)
            left = sem.drop_specks(
                garment_from(check_plan, again, shape) & sem.dilate(garment, 24), RESIDUAL_MIN_PIXELS
            )
            sem.overlay(current, left).save(debug / f"{stem}-residual-p{n}.png")
            ratio = sem.residual_ratio(garment, left)
            meta["passes"][-1]["residual_ratio"] = round(ratio, 4)
            print(f"RESIDUAL {stem} pass={n} ratio={ratio:.4f}", flush=True)
            if ratio < best_ratio:
                best_ratio, best_image, best_left = ratio, current, left
            # Next pass repaints whatever is still flagged, starting from the best image so far.
            base, target = best_image, best_left if best_left.any() else left
            if best_ratio < RESIDUAL_OK:
                break
            if n >= max_res:
                print(
                    f"STOP_RESIDUAL {stem} n={n} max={max_res} ratio={best_ratio:.4f}",
                    flush=True,
                )
                break
        current = best_image
        leftover = best_left if isinstance(best_left, np.ndarray) else np.zeros(shape, dtype=bool)
        meta["best_residual_ratio"] = round(best_ratio, 4)
        meta["_leftover_pixels"] = int(leftover.sum())
        edge_target = garment

    if edge_target is None:
        dest = out_dir / f"{stem}.png"
        current.save(dest)
        (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"STITCH {dest} {dest.stat().st_size}", flush=True)
        return dest

    edge_zone = sem.edge_band(edge_target, 14) & sem.box_array(shape, plan.roi)
    face = sem.box_array(shape, plan.face_clear)
    edge_zone &= ~face
    # Keep Fooocus edge off the standing collar — it redraws the mandarin collar from context.
    # face_clear bottoms at y=300 and would swallow the collar; protect only above the chin (~265).
    chin_y = 265
    if actor == "lin":
        edge_zone &= ~sem.dilate(sem.box_array(shape, (380, 255, 600, 395)), 8)
    if actor == "elena" and plan.horse_guard_y:
        y_cut = int(plan.horse_guard_y / sem.BASE[1] * shape[0])
        buf = int(ELENA_JUNCTION_BUFFER / sem.BASE[1] * shape[0])
        edge_zone[max(0, y_cut - buf) :, :] = False
    current = run_bands(
        host, models, current, edge_zone,
        positive=NUDE_EDGE_POS,
        negative=NUDE_EDGE_NEG,
        seed=seed + 900, stem=f"{stem}-edge",
        denoise=EDGE_DENOISE, edge=True, input_dir=input_dir, out_dir=work,
    )
    meta["passes"].append({"kind": "edge", "denoise": EDGE_DENOISE})

    leftover = locals().get("leftover")
    if not isinstance(leftover, np.ndarray):
        leftover = np.zeros(shape, dtype=bool)

    # Lin legs: soft polish on leftover below hips only (LaMa + weak touch). No high denoise.
    if mode == "nude" and actor == "lin":
        leg_y = int(LOWER_FROM_Y["lin"] / sem.BASE[1] * shape[0])
        leg_mask = sem.dilate(leftover, 6) & sem.box_array(shape, plan.roi)
        leg_mask[:leg_y, :] = False
        leg_px = int(leg_mask.sum())
        if leg_mask.any() and leg_px <= LEG_SOFT_MAX_PX:
            current = run_bands(
                host, models, current, leg_mask,
                positive=LOWER_POS, negative=LOWER_NEG, seed=seed + 910,
                stem=f"{stem}-legsoft-lama", denoise=0.0, edge=False,
                input_dir=input_dir, out_dir=work, lama_only=True,
            )
            current = run_bands(
                host, models, current, leg_mask,
                positive=LOWER_POS, negative=LOWER_NEG, seed=seed + 911,
                stem=f"{stem}-legsoft", denoise=LEG_SOFT_DENOISE, edge=True,
                input_dir=input_dir, out_dir=work, cfg=LEG_SOFT_CFG,
            )
            meta["passes"].append(
                {"kind": "leg_soft", "denoise": LEG_SOFT_DENOISE, "pixels": leg_px}
            )
            print(f"LEG_SOFT {stem} px={leg_px} denoise={LEG_SOFT_DENOISE}", flush=True)
        elif leg_px:
            print(f"LEG_SOFT_SKIP {stem} px={leg_px} (cap={LEG_SOFT_MAX_PX})", flush=True)

    # Tiny pixelfill AFTER soft passes so Fooocus cannot paint collar cloth back.
    # Elena: no torso pixelfill (marble/meat patches); junction stays frozen.
    if mode == "nude" and actor == "lin":
        # Collar: only leftover ∩ collar band (not the whole standing-collar box).
        collar_box = sem.dilate(sem.box_array(shape, (400, 270, 580, 360)), 4)
        collar_box[:chin_y, :] = False
        collar_mask = sem.dilate(leftover, 10) & collar_box
        if not collar_mask.any():
            # Fallback: small fixed band if residual missed the mandarin collar.
            collar_mask = collar_box
        if collar_mask.any() and int(collar_mask.sum()) <= 12000:
            current = pixel_skin_fill(
                current, collar_mask, sample_box=(430, 430, 560, 510), blur=5, noise_std=3.0, seed=seed + 77
            )
            meta["passes"].append({"kind": "collar_pixelfill", "pixels": int(collar_mask.sum())})
            print(f"COLLAR_PIXELFILL {stem} px={int(collar_mask.sum())}", flush=True)
        # Skirt/hip leftovers: only tiny islands. Large flat fills look like meat patches.
        skirt_boxes = ((300, 720, 580, 1200), (280, 680, 420, 1250))
        hip_mask = np.zeros(shape, dtype=bool)
        for box in skirt_boxes:
            hip_mask |= sem.box_array(shape, box)
        hip_mask = sem.dilate(leftover, 4) & hip_mask
        hip_px = int(hip_mask.sum())
        if hip_mask.any() and hip_px <= HIP_PIXELFILL_MAX_PX:
            current = pixel_skin_fill(
                current, hip_mask, sample_box=(300, 900, 400, 1150), blur=6, noise_std=3.0, seed=seed + 88
            )
            meta["passes"].append({"kind": "hip_pixelfill", "pixels": hip_px})
            print(f"HIP_PIXELFILL {stem} px={hip_px}", flush=True)
        elif hip_px:
            print(
                f"HIP_PIXELFILL_SKIP {stem} px={hip_px} (cap={HIP_PIXELFILL_MAX_PX}; leave for visual judge)",
                flush=True,
            )
    elif mode == "nude" and actor == "elena" and leftover.any():
        # Partial rollback: fill leftover on human torso only, stop above junction freeze.
        torso = sem.dilate(leftover, 6) & sem.box_array(shape, plan.roi)
        if plan.horse_guard_y:
            y_cut = int(plan.horse_guard_y / sem.BASE[1] * shape[0])
            buf = int(16 / sem.BASE[1] * shape[0])  # keep fill clear of mare
            torso[max(0, y_cut - buf) :, :] = False
        torso_px = int(torso.sum())
        if torso.any() and torso_px <= 80000:
            current = pixel_skin_fill(
                current, torso, sample_box=(430, 360, 560, 480), blur=5, noise_std=3.0, seed=seed + 99
            )
            meta["passes"].append({"kind": "elena_torso_pixelfill", "pixels": torso_px})
            print(f"ELENA_TORSO_PIXELFILL {stem} px={torso_px}", flush=True)
        else:
            print(
                f"ELENA_TORSO_PIXELFILL_SKIP {stem} leftover={int(leftover.sum())} torso_px={torso_px}",
                flush=True,
            )

    dest = out_dir / f"{stem}.png"
    current.save(dest)
    (out_dir / f"{stem}.run.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"STITCH {dest} {dest.stat().st_size}", flush=True)
    return dest


def already_done(out_dir: Path, stem: str) -> bool:
    """Resume skips existing PNGs. Scoring cancelled — no passed=True gate."""
    return (out_dir / f"{stem}.png").exists()


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
        graph = inpaint_crop_graph(
            ckpt=ckpt, crop_name="band-crop.png", mask_name="band-crop-mask.png",
            positive=nude_text(actor)[0], negative=nude_text(actor)[1], seed=SEED, prefix=f"{actor}-nude",
            denoise=NUDE_DENOISE, fooocus=True, differential=False, masked_fill=True, fill_mode="neutral",
            cfg=NUDE_CFG,
        )
        dump(f"scheme-semantic-inpaint-{actor}-nude.api.json", graph, stage="neutral fill + Fooocus", denoise=NUDE_DENOISE)
        rim = inpaint_crop_graph(
            ckpt=ckpt, crop_name="rim-crop.png", mask_name="rim-crop-mask.png",
            positive=torn_text(actor)[0], negative=torn_text(actor)[1], seed=SEED, prefix=f"{actor}-torn-rim",
            denoise=TORN_RIM_DENOISE, fooocus=True, differential=True, masked_fill=False,
        )
        dump(
            f"scheme-semantic-inpaint-{actor}-torn.api.json", rim,
            stage="torn = nude composite through jagged holes, then this rim pass", denoise=TORN_RIM_DENOISE,
        )
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
    parser.add_argument("--resume", action="store_true", help="Skip stills that already have a PNG in --out.")
    parser.add_argument("--check-stack", action="store_true", help="Only list missing ComfyUI nodes, then exit.")
    parser.add_argument(
        "--score",
        action="store_true",
        help="Deprecated. Scoring cancelled; prints VISUAL_JUDGE and does nothing else.",
    )
    parser.add_argument(
        "--no-score",
        action="store_true",
        help="Deprecated no-op (scoring is off by default).",
    )
    parser.add_argument(
        "--score-only",
        action="store_true",
        help="Deprecated. Scoring cancelled; list PNGs for Cursor visual judgment.",
    )
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

    if args.score_only or args.score:
        print("SCORING_CANCELLED usability is Cursor visual judgment of the PNGs", flush=True)
        for actor, mode in order:
            image = args.out / f"{STEM[(actor, mode)]}.png"
            if image.exists():
                print(f"VISUAL_JUDGE {actor} {mode} {image}", flush=True)
        if args.score_only:
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
        if args.resume and already_done(args.out, stem):
            print(f"SKIP {stem} png exists", flush=True)
            continue
        try:
            image = undress_one(args.host, models, actor, mode, args.out, args.input, attempt=args.attempt)
        except SystemExit as exc:
            print(f"FAILED {stem} {exc}", flush=True)
            continue
        print(f"VISUAL_JUDGE {actor} {mode} {image}", flush=True)


if __name__ == "__main__":
    main()
