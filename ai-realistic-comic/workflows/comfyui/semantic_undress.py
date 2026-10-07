"""Semantic garment masks for the fox/centaur undress pipeline.

Pipeline (see docs/fox-centaur-semantic-undress.md):
  SegFormer B2 clothes + GroundingDINO/SAM garment parts
    -> subtract protected regions (face, hair, glasses, fox tails, horse body)
    -> optional torn-hole carving
    -> neutral pre-fill + Fooocus inpaint patch + Crop-and-Stitch (inpaint_crop.py)
    -> residual check: segment the result again and only repaint what is left.

This module is pure mask math plus ComfyUI graph builders. It does not talk to a
machine. Never point it at F34 or G09.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass, field

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SEGFORMER_NODE = "segformer_b2_clothes"
DINO_SAM_NODE = "GroundingDinoSAMSegment (segment anything)"
SAM_LOADER_NODE = "SAMModelLoader (segment anything)"
DINO_LOADER_NODE = "GroundingDinoModelLoader (segment anything)"
SAM_MODEL = "sam_vit_b_01ec64.pth"
DINO_MODEL = "GroundingDINO_SwinT_OGC (694MB)"

SEGFORMER_CLASSES = (
    "Face",
    "Hair",
    "Hat",
    "Sunglass",
    "Left-arm",
    "Right-arm",
    "Left-leg",
    "Right-leg",
    "Upper-clothes",
    "Skirt",
    "Pants",
    "Dress",
    "Belt",
    "shoe",
    "bag",
    "Scarf",
)
GARMENT_CLASSES = ("Upper-clothes", "Skirt", "Pants", "Dress", "Belt", "Scarf")

REQUIRED_NODES = (
    "INPAINT_LoadFooocusInpaint",
    "INPAINT_ApplyFooocusInpaint",
    "INPAINT_MaskedFill",
    "InpaintModelConditioning",
    "DifferentialDiffusion",
    SEGFORMER_NODE,
    DINO_SAM_NODE,
    SAM_LOADER_NODE,
    DINO_LOADER_NODE,
)

BASE = (1024, 1536)


@dataclass(frozen=True)
class ActorPlan:
    """Per-actor semantic recipe. Boxes are in 1024x1536 plate coordinates."""

    actor: str
    garment_prompts: tuple[str, ...]
    protect_prompts: tuple[str, ...]
    roi: tuple[int, int, int, int]
    face_clear: tuple[int, int, int, int]
    use_segformer: bool = True
    # DINO prompts whose hits beat the horse-body protection (armor over the barrel).
    garment_wins_prompts: tuple[str, ...] = ()
    # Protect prompts only enforced below this y (plate coords). 0 = everywhere.
    horse_guard_y: int = 0
    horse_prompts: tuple[str, ...] = ()
    keep_top_frac: float = 0.0
    keep_bottom_frac: float = 0.0
    tear_fraction: float = 0.62
    # SegFormer only counts within this many px of a DINO garment hit. 0 = trust SegFormer alone.
    segformer_support_px: int = 0


LIN = ActorPlan(
    actor="lin",
    garment_prompts=(
        "qipao",
        "cheongsam dress",
        "silk fabric skirt",
        "mandarin collar",
        "shoulder strap",
        "dress hem",
    ),
    protect_prompts=("face", "hair", "fox tail", "high heel shoes"),
    roi=(280, 260, 680, 1400),
    face_clear=(300, 10, 620, 300),
    keep_top_frac=0.07,
    keep_bottom_frac=0.18,
    tear_fraction=0.62,
)

ELENA = ActorPlan(
    actor="elena",
    garment_prompts=(
        "breastplate",
        "pauldron",
        "vambrace",
        "gauntlet",
        "fauld",
        "gorget",
        "golden armor",
    ),
    protect_prompts=("face", "hair", "glasses"),
    roi=(60, 230, 560, 900),
    face_clear=(240, 10, 520, 230),
    use_segformer=True,
    segformer_support_px=40,
    garment_wins_prompts=("breastplate", "pauldron", "vambrace", "gauntlet", "fauld", "gorget"),
    horse_guard_y=690,
    horse_prompts=("horse body", "horse tail"),
    keep_top_frac=0.0,
    keep_bottom_frac=0.10,
    tear_fraction=0.68,
)

PLANS = {"lin": LIN, "elena": ELENA}


def scale_box(size: tuple[int, int], box: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    width, height = size
    x0, y0, x1, y1 = box
    return (
        int(x0 / BASE[0] * width),
        int(y0 / BASE[1] * height),
        int(x1 / BASE[0] * width),
        int(y1 / BASE[1] * height),
    )


def to_bool(mask: Image.Image, threshold: int = 127) -> np.ndarray:
    return np.asarray(mask.convert("L")) > threshold


def to_image(arr: np.ndarray) -> Image.Image:
    return Image.fromarray((arr.astype(np.uint8)) * 255, mode="L")


def union(*masks: np.ndarray, shape: tuple[int, int] | None = None) -> np.ndarray:
    items = [m for m in masks if m is not None]
    if not items:
        if shape is None:
            raise ValueError("union of nothing needs a shape")
        return np.zeros(shape, dtype=bool)
    out = items[0].copy()
    for item in items[1:]:
        out |= item
    return out


def dilate(arr: np.ndarray, pixels: int) -> np.ndarray:
    if pixels <= 0:
        return arr
    img = to_image(arr)
    remaining = pixels
    while remaining > 0:
        step = min(remaining, 6)
        img = img.filter(ImageFilter.MaxFilter(step * 2 + 1))
        remaining -= step
    return np.asarray(img) > 127


def erode(arr: np.ndarray, pixels: int) -> np.ndarray:
    if pixels <= 0:
        return arr
    img = to_image(arr)
    remaining = pixels
    while remaining > 0:
        step = min(remaining, 6)
        img = img.filter(ImageFilter.MinFilter(step * 2 + 1))
        remaining -= step
    return np.asarray(img) > 127


def box_array(shape: tuple[int, int], box: tuple[int, int, int, int]) -> np.ndarray:
    height, width = shape
    x0, y0, x1, y1 = scale_box((width, height), box)
    arr = np.zeros(shape, dtype=bool)
    arr[max(0, y0) : max(0, y1), max(0, x0) : max(0, x1)] = True
    return arr


def drop_specks(arr: np.ndarray, min_pixels: int) -> np.ndarray:
    """Remove tiny components so a stray DINO hit does not become a hole."""
    if min_pixels <= 0 or not arr.any():
        return arr
    h, w = arr.shape
    seen = np.zeros_like(arr, dtype=bool)
    out = arr.copy()
    ys, xs = np.nonzero(arr)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        comp: list[tuple[int, int]] = []
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and arr[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if len(comp) < min_pixels:
            for y, x in comp:
                out[y, x] = False
    return out


def build_garment_mask(
    plan: ActorPlan,
    shape: tuple[int, int],
    *,
    segformer: np.ndarray | None,
    dino_garment: dict[str, np.ndarray],
    dino_protect: dict[str, np.ndarray],
    dino_horse: dict[str, np.ndarray] | None = None,
    grow: int = 10,
) -> np.ndarray:
    """Union of garment evidence minus protection, clipped to the actor ROI."""
    roi = box_array(shape, plan.roi)
    face = box_array(shape, plan.face_clear)
    dino_union = union(*dino_garment.values(), shape=shape)
    if segformer is not None and plan.segformer_support_px:
        segformer = segformer & dilate(dino_union, plan.segformer_support_px)
    evidence = union(*(arr for arr in (segformer,) if arr is not None), dino_union, shape=shape)
    evidence &= roi

    protect_face = union(*(dilate(a, 6) for a in dino_protect.values()), shape=shape)
    horse = union(*(dilate(a, 4) for a in (dino_horse or {}).values()), shape=shape)
    if plan.horse_guard_y:
        guard = np.zeros(shape, dtype=bool)
        y_cut = int(plan.horse_guard_y / BASE[1] * shape[0])
        guard[y_cut:, :] = True
        horse &= guard
    wins = union(
        *(a for key, a in dino_garment.items() if key in plan.garment_wins_prompts),
        shape=shape,
    )
    horse &= ~wins

    final = evidence & ~protect_face & ~horse & ~face
    final = drop_specks(final, max(40, int(shape[0] * shape[1] * 0.00004)))
    final = dilate(final, grow) & roi & ~protect_face & ~horse & ~face
    return final


def residual_ratio(before: np.ndarray, after: np.ndarray) -> float:
    total = int(before.sum())
    if total == 0:
        return 0.0
    return float(after.sum()) / float(total)


def tear_mask(
    garment: np.ndarray,
    *,
    seed: int,
    fraction: float,
    keep_top_frac: float = 0.0,
    keep_bottom_frac: float = 0.0,
    max_blobs: int = 60,
) -> np.ndarray:
    """Carve jagged holes inside the garment so remnants stay on the body."""
    if not garment.any():
        return garment
    ys, xs = np.nonzero(garment)
    top, bottom = int(ys.min()), int(ys.max())
    span = max(1, bottom - top)
    allowed = garment.copy()
    if keep_top_frac > 0:
        allowed[: top + int(span * keep_top_frac), :] = False
    if keep_bottom_frac > 0:
        allowed[bottom - int(span * keep_bottom_frac) :, :] = False
    if not allowed.any():
        return garment
    rng = random.Random(seed)
    ays, axs = np.nonzero(allowed)
    holes = Image.new("L", (garment.shape[1], garment.shape[0]), 0)
    draw = ImageDraw.Draw(holes)
    target = int(garment.sum() * fraction)
    base_radius = max(24, int(math.sqrt(garment.sum()) * 0.16))
    covered = 0
    for _ in range(max_blobs):
        idx = rng.randrange(len(axs))
        cx, cy = int(axs[idx]), int(ays[idx])
        radius = base_radius * rng.uniform(0.6, 1.3)
        points = []
        spikes = rng.randint(9, 15)
        for k in range(spikes):
            angle = 2 * math.pi * k / spikes + rng.uniform(-0.15, 0.15)
            jag = radius * (rng.uniform(0.45, 1.15) if k % 2 else rng.uniform(0.8, 1.25))
            points.append((cx + math.cos(angle) * jag, cy + math.sin(angle) * jag * 1.15))
        draw.polygon(points, fill=255)
        covered = int((np.asarray(holes) > 127)[allowed].sum())
        if covered >= target:
            break
    carved = (np.asarray(holes) > 127) & allowed
    return carved


def feather(arr: np.ndarray, radius: int = 8) -> Image.Image:
    return to_image(arr).filter(ImageFilter.GaussianBlur(radius=radius))


def edge_band(arr: np.ndarray, width: int = 14) -> np.ndarray:
    return dilate(arr, width) & ~erode(arr, width)


def overlay(plate: Image.Image, arr: np.ndarray, color: tuple[int, int, int] = (220, 40, 40)) -> Image.Image:
    base = plate.convert("RGBA")
    tint = Image.new("RGBA", base.size, (*color, 120))
    return Image.composite(tint, base, to_image(arr)).convert("RGB")


def segformer_graph(
    image_name: str,
    classes: tuple[str, ...] = GARMENT_CLASSES,
    prefix: str = "seg",
    *,
    kind: str = "MASK",
    slot: int = 1,
) -> dict:
    """kind/slot say which output of the SegFormer node carries the class mask."""
    flags = {name: (name in classes) for name in SEGFORMER_CLASSES}
    graph: dict = {
        "1": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "2": {"class_type": SEGFORMER_NODE, "inputs": {"image": ["1", 0], **flags}},
    }
    if kind == "MASK":
        graph["3"] = {"class_type": "MaskToImage", "inputs": {"mask": ["2", slot]}}
        graph["4"] = {"class_type": "SaveImage", "inputs": {"images": ["3", 0], "filename_prefix": prefix}}
    else:
        graph["4"] = {"class_type": "SaveImage", "inputs": {"images": ["2", slot], "filename_prefix": prefix}}
    return graph


def dino_masks_graph(
    image_name: str,
    prompts: tuple[str, ...],
    *,
    threshold: float = 0.3,
    prefix: str = "dino",
    slot: int = 1,
) -> dict:
    """One graph, shared loaders, one SaveImage per prompt. Node ids are returned by dino_save_ids."""
    graph: dict = {
        "1": {"class_type": "LoadImage", "inputs": {"image": image_name}},
        "2": {"class_type": SAM_LOADER_NODE, "inputs": {"model_name": SAM_MODEL}},
        "3": {"class_type": DINO_LOADER_NODE, "inputs": {"model_name": DINO_MODEL}},
    }
    for i, prompt in enumerate(prompts):
        seg, to_img, save = (str(10 + i * 3 + k) for k in range(3))
        graph[seg] = {
            "class_type": DINO_SAM_NODE,
            "inputs": {
                "sam_model": ["2", 0],
                "grounding_dino_model": ["3", 0],
                "image": ["1", 0],
                "prompt": prompt,
                "threshold": threshold,
            },
        }
        graph[to_img] = {"class_type": "MaskToImage", "inputs": {"mask": [seg, slot]}}
        graph[save] = {
            "class_type": "SaveImage",
            "inputs": {"images": [to_img, 0], "filename_prefix": f"{prefix}-{i:02d}"},
        }
    return graph


def dino_save_ids(prompts: tuple[str, ...]) -> dict[str, str]:
    return {prompt: str(10 + i * 3 + 2) for i, prompt in enumerate(prompts)}


@dataclass
class MaskEvidence:
    segformer: np.ndarray | None = None
    garment: dict[str, np.ndarray] = field(default_factory=dict)
    protect: dict[str, np.ndarray] = field(default_factory=dict)
    horse: dict[str, np.ndarray] = field(default_factory=dict)


def all_dino_prompts(plan: ActorPlan) -> tuple[str, ...]:
    seen: list[str] = []
    for prompt in (*plan.garment_prompts, *plan.protect_prompts, *plan.horse_prompts):
        if prompt not in seen:
            seen.append(prompt)
    return tuple(seen)


def split_evidence(plan: ActorPlan, segformer: np.ndarray | None, by_prompt: dict[str, np.ndarray]) -> MaskEvidence:
    return MaskEvidence(
        segformer=segformer if plan.use_segformer else None,
        garment={p: by_prompt[p] for p in plan.garment_prompts if p in by_prompt},
        protect={p: by_prompt[p] for p in plan.protect_prompts if p in by_prompt},
        horse={p: by_prompt[p] for p in plan.horse_prompts if p in by_prompt},
    )
