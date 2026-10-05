"""Reusable cast-body templates for later stills. Not a story workflow.

Pass 1 changes only clothes, hair, and makeup, and must clear every content
score. Resolution stays on the low grid. The face stays locked to the clothed
plate. A framing sentence, a face-lock sentence, and a clothes sentence stay
apart. Identity, anatomy, or wardrobe under 9 spends that seed. Pass 1 then
takes the next unspent seed until the gate clears or the user drops a stop
file. Pass 2 is a same-seed light upscale and is forbidden until pass 1
clears. A pass-2 miss only changes denoise and steps. The still agent proxies
once. After shared login, this pipeline runs itself and does not hand work back.
This module does not import or edit the explicit-still runner.
"""
from __future__ import annotations

import json

KEEP_MEAN = 9.0
FIXED_SCALE = 0.85
# Seed 33 at this scale is the rejected Lin front pass 1. Never a pass.
VOID_LIN_FRONT = ("lin_wantang", "front", 0.85, 33)
# Lin front seeds already spent at scale 0.85. Do not render them again.
# 33 is void. 34-46 missed identity or wardrobe. 47-49 cropped to a head and
# hit FEET. 50 was full body, mean 9.0, empty gates and look, but a content
# score stayed under 9 (the old log did not keep the eight items). 51 wardrobe
# was 2. 52 mean was 8.75 with empty gates and look. Next seed is 53.
LIN_FRONT_SEED = 53
LIN_FRONT_SPENT = frozenset(range(33, 53))
OTHER_SEED = 41
# Local and remote files. Either one stops the pass-1 seed walk.
STOP_LOCAL = "/tmp/cast-asset-stop"
# The one still-agent proxy is already spent. This pipeline does not grant another.
FILM_PROXY_REMAINING = 0

# Asset turnaround schedule. It is not the still runner's 40-step contact edit.
ASSET_SCHEDULE = {
    "pass1": {
        "width": 448,
        "height": 592,
        "steps": 8,
        "true_cfg_scale": 4.0,
        "denoise": None,
    },
    "pass2": {
        "width": 896,
        "height": 1200,
        "steps": 12,
        "true_cfg_scale": 4.0,
        "denoise": 0.20,
    },
}
PASS1_SIZE = (ASSET_SCHEDULE["pass1"]["width"], ASSET_SCHEDULE["pass1"]["height"])
PASS1_STEPS = ASSET_SCHEDULE["pass1"]["steps"]
ASSET_TRUE_CFG = ASSET_SCHEDULE["pass1"]["true_cfg_scale"]
PASS2_SIZE = (ASSET_SCHEDULE["pass2"]["width"], ASSET_SCHEDULE["pass2"]["height"])
PASS2_DENOISE = ASSET_SCHEDULE["pass2"]["denoise"]
PASS2_STEPS = ASSET_SCHEDULE["pass2"]["steps"]
PASS2_SCORE_TRIES = (
    (PASS2_DENOISE, PASS2_STEPS),
    (0.15, PASS2_STEPS),
    (0.12, 8),
)
PASS2_OOM_TRIES = (
    (PASS2_DENOISE, 8),
    (0.15, 6),
    (0.12, 6),
)

F34_UUID = "xaxna66hqt-c5c9c7fc"
G09_UUID = "sa4eaxgcuq-26e36fc9"
LORA_REMOTE = "/root/autodl-tmp/loras/qwen-image-edit-plus-nsfw-lora.safetensors"

JOB_REMOTE = "/root/autodl-tmp/in/cast-asset-job.json"
DONE_REMOTE = "/root/autodl-tmp/out/cast-asset-done.json"
STOP_REMOTE = "/root/autodl-tmp/in/cast-asset-stop"
WORKER_REMOTE = "/root/autodl-tmp/cast-asset/worker.py"
WORKER_LOG = "/root/autodl-tmp/cast-asset/worker.log"

EIGHT = (
    "identity",
    "distinction",
    "interaction",
    "aesthetics",
    "anatomy",
    "wardrobe",
    "motif",
    "photoreal",
)
# Every content score. Pixel size is not a key; pass 1 stays on the low grid.
PASS1_KEYS = EIGHT

# Twelve clothed turnarounds are the base plates. Means are the makeup-ref rescore.
# A view is not undressed until its clothed mean is at least 9.
CLOTHED_MEAN = {
    ("lin_wantang", "front"): 9.125,
    ("lin_wantang", "side"): 9.125,
    ("lin_wantang", "back"): 9.0,
    ("gu_chengan", "front"): 9.25,
    ("gu_chengan", "side"): 8.75,
    ("gu_chengan", "back"): 8.875,
    ("elena_voss", "front"): 9.0,
    ("elena_voss", "side"): 8.875,
    ("elena_voss", "back"): 9.25,
    ("adrian_kane", "front"): 9.25,
    ("adrian_kane", "side"): 9.125,
    ("adrian_kane", "back"): 9.125,
}
CLOTHED_VIEWS = tuple(CLOTHED_MEAN)

# Nine nude turnarounds: only the clothed plates already at mean >= 9.
NUDE_VIEWS = (
    ("lin_wantang", "front"),
    ("lin_wantang", "side"),
    ("lin_wantang", "back"),
    ("gu_chengan", "front"),
    ("elena_voss", "front"),
    ("elena_voss", "back"),
    ("adrian_kane", "front"),
    ("adrian_kane", "side"),
    ("adrian_kane", "back"),
)

PERIOD_RELEASE = frozenset({"lin_wantang", "gu_chengan"})

GARMENTS = {
    ("lin_wantang", "front"): "背心和短裤",
    ("lin_wantang", "side"): "T恤和短裤",
    ("lin_wantang", "back"): "T恤和短裤",
    ("gu_chengan", "front"): "T恤和短裤",
    ("elena_voss", "front"): "T恤和短裤",
    ("elena_voss", "back"): "T恤和短裤",
    ("adrian_kane", "front"): "T恤和短裤",
    ("adrian_kane", "side"): "T恤和短裤",
    ("adrian_kane", "back"): "T恤和短裤",
}

_PERIOD_LOOK = {
    "lin_wantang": "去发髻、头饰、花钿、浓妆、红唇。黑褐色披发，淡妆，黑褐眼。",
    "gu_chengan": "去发髻、额带、浓妆、红唇。黑褐色短发，淡妆，黑褐眼。",
}

_KEEP_LOOK = {
    "elena_voss": "保持赤褐发、暖琥珀棕眼、人耳。",
    "adrian_kane": "保持深色发、浅蓝灰眼、尖耳，无武器。",
}

STORY_BANS = ("月下", "木屋", "夜湖", "雨桥", "冥府", "王座", "白蛇", "蛇尾", "石榴", "相拥")


def film_proxy_allowed() -> bool:
    """True only while a still-agent proxy is still authorized."""
    return FILM_PROXY_REMAINING > 0


def self_run_line() -> str:
    return "资产自己跑。禁止再让出片代跑。"


def clothed_passed(actor: str, view: str) -> bool:
    """True when this clothed plate already scored a mean of at least 9."""
    try:
        mean = float(CLOTHED_MEAN[(actor, view)])
    except KeyError:
        return False
    return mean >= KEEP_MEAN


def is_void(actor: str, view: str, scale: float, seed: int) -> bool:
    return (actor, view, float(scale), int(seed)) == VOID_LIN_FRONT


def spent_seeds(actor: str, view: str) -> frozenset[int]:
    """Seeds already rendered for this view. The walker must not repeat them."""
    if (actor, view) == ("lin_wantang", "front"):
        return LIN_FRONT_SPENT
    return frozenset()


def advance_seed(seed: int, actor: str, view: str) -> int:
    """Step past the void pair and any seed already spent on this view."""
    seed = int(seed)
    blocked = spent_seeds(actor, view)
    while is_void(actor, view, FIXED_SCALE, seed) or seed in blocked:
        seed += 1
    return seed


def seed_for(actor: str, view: str, attempt: int) -> int:
    """Fixed scale lives outside. Seeds step by one from the next unspent seed."""
    base = LIN_FRONT_SEED if (actor, view) == ("lin_wantang", "front") else OTHER_SEED
    return advance_seed(base + int(attempt), actor, view)


def look_line(actor: str) -> str:
    if actor in _PERIOD_LOOK:
        return _PERIOD_LOOK[actor]
    if actor not in _KEEP_LOOK:
        raise KeyError(actor)
    return _KEEP_LOOK[actor]


def face_lock_line(actor: str) -> str:
    """Face clause only. It does not mention garments."""
    line = "锁脸：脸型不重画，五官尽量少改，身体不动。"
    if actor in PERIOD_RELEASE:
        line += "可改发型、妆、眼睛。"
    return line + look_line(actor)


def wardrobe_clause(actor: str, view: str) -> str:
    """Clothes clause only, written twice so it is not traded for the face lock."""
    once = f"去掉{GARMENTS[(actor, view)]}。"
    return f"去衣：{once}{once}"


FRAME_HARD = "full body, head and both feet in frame, no bust/head crop"


def frame_clause() -> str:
    """Framing clause only. It does not redo the face lock or the clothes sentence."""
    return (
        "构图：保持这张图的全身取景。头和双脚都留在画面内，不要裁成头肩。"
        + FRAME_HARD
        + "。"
    )


def pass1_prompt(actor: str, view: str) -> str:
    """Clothed plate only. Frame, face lock, and clothes removal stay apart."""
    return frame_clause() + face_lock_line(actor) + wardrobe_clause(actor, view)


def pass2_prompt(actor: str) -> str:
    """Same-seed light upscale. Retries must keep this text and change sampling only."""
    if actor not in _PERIOD_LOOK and actor not in _KEEP_LOOK:
        raise KeyError(actor)
    return "只放大。不改脸、身体、衣着、发型、妆。头和双脚仍留在画面内。"


def negative_for(actor: str) -> str:
    base = "磨皮,塑料皮肤,衣服,内衣,短裤,裙子,袍子,文字,水印,未成年人"
    if actor in PERIOD_RELEASE:
        return base + ",发髻,头饰,花钿,红唇,古装妆,浓妆"
    return base


def parse_score(text: str) -> dict:
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("score json missing")
    data = json.loads(text[start : end + 1])
    if isinstance(data.get("items"), list) and data["items"]:
        data = data["items"][0]
    if not isinstance(data, dict):
        raise ValueError("score json was not an object")
    return data


def mean_of(item: dict) -> float:
    try:
        return float(item["mean"])
    except (TypeError, ValueError, KeyError):
        vals = [float(item[key]) for key in EIGHT]
        return sum(vals) / len(vals)


def look_gates(actor: str, view: str, item: dict) -> list[str]:
    """Period hair, makeup, and eye color. Missing flags do not pass."""
    if actor not in PERIOD_RELEASE:
        return []
    gates: list[str] = []
    if item.get("period_hair") is not False:
        gates.append("HAIR")
    if view == "back":
        if item.get("period_makeup") is True:
            gates.append("MAKEUP")
        return gates
    if item.get("period_makeup") is not False:
        gates.append("MAKEUP")
    if item.get("eyes_black_brown") is not True:
        gates.append("EYES")
    return gates


def _score_ok(item: dict, keys: tuple[str, ...]) -> bool:
    if item.get("gates"):
        return False
    for key in keys:
        try:
            value = float(item.get(key))
        except (TypeError, ValueError):
            return False
        if value < KEEP_MEAN:
            return False
    return True


RESEED_KEYS = ("identity", "anatomy", "wardrobe")


def keys_below(item: dict, keys: tuple[str, ...]) -> list[str]:
    """Keys that are missing or under 9. Order follows `keys`."""
    low: list[str] = []
    for key in keys:
        try:
            value = float(item.get(key))
        except (TypeError, ValueError):
            low.append(key)
            continue
        if value < KEEP_MEAN:
            low.append(key)
    return low


def below_nine(item: dict) -> list[str]:
    """Every content score under 9. A mean of 9 can still list one of these."""
    return keys_below(item, EIGHT)


def format_eight(item: dict) -> str:
    """One readable list of the eight content scores."""
    return " ".join(f"{key}={item.get(key)}" for key in EIGHT)


def score_log_line(
    stage: str,
    actor: str,
    view: str,
    item: dict,
    look: list[str],
    passed: bool,
    extra: str = "",
) -> str:
    """Pass or fail, the eight scores and the look flags stay on one line."""
    prefix = f"{extra} " if extra else ""
    return (
        f"{stage} {actor} {view} {prefix}"
        f"mean={item.get('mean')} gates={item.get('gates')} look={look} "
        f"period_hair={item.get('period_hair')} period_makeup={item.get('period_makeup')} "
        f"eyes_black_brown={item.get('eyes_black_brown')} passed={passed} "
        f"eight={format_eight(item)} below={below_nine(item)}"
    )


def attempt_record(
    actor: str,
    view: str,
    stage: str,
    scale: float,
    seed: int,
    item: dict,
    look: list[str],
    passed: bool,
    **extra,
) -> dict:
    """Sidecar written next to every attempt image, pass or fail."""
    record = {
        "actor": actor,
        "view": view,
        "stage": stage,
        "scale": scale,
        "seed": seed,
        "passed": passed,
        "mean": item.get("mean"),
        "gates": item.get("gates") or [],
        "look": look,
        "period_hair": item.get("period_hair"),
        "period_makeup": item.get("period_makeup"),
        "eyes_black_brown": item.get("eyes_black_brown"),
        "eight": {key: item.get(key) for key in EIGHT},
        "below": below_nine(item),
        "score": item,
    }
    record.update(extra)
    return record


def identity_or_wardrobe_below(item: dict) -> bool:
    """True when identity or wardrobe is missing or under 9. Switch seed now."""
    return bool(keys_below(item, ("identity", "wardrobe")))


def identity_or_anatomy_below(item: dict) -> bool:
    """True when identity or anatomy is missing or under 9. That seed is spent."""
    return bool(keys_below(item, ("identity", "anatomy")))


def identity_anatomy_or_wardrobe_below(item: dict) -> bool:
    """True when identity, anatomy, or wardrobe is missing or under 9."""
    return bool(keys_below(item, RESEED_KEYS))


def pass2_allowed(pass1_accepted: bool) -> bool:
    """Pass 2 runs only after pass 1 has cleared the gate."""
    return bool(pass1_accepted)


def accept_pass1(item: dict, actor: str, view: str, scale: float, seed: int) -> bool:
    """All content scores, hard gates, and look checks. Resolution is exempt."""
    if is_void(actor, view, scale, seed):
        return False
    if look_gates(actor, view, item):
        return False
    return _score_ok(item, PASS1_KEYS)


def accept_pass2(item: dict, actor: str, view: str, scale: float, seed: int) -> bool:
    if is_void(actor, view, scale, seed):
        return False
    if look_gates(actor, view, item):
        return False
    if item.get("gates"):
        return False
    try:
        mean = mean_of(item)
    except (TypeError, ValueError, KeyError):
        return False
    return mean >= KEEP_MEAN


def score_prompt(actor: str, view: str, stage: str) -> str:
    if actor in PERIOD_RELEASE:
        look = (
            "Nude template for Lin or Gu. Identity is facial features, face shape, skin tone, and body type. "
            "Costume hair and makeup must be gone: no hair bun, no hairpins, no forehead ornament, "
            "no heavy eye makeup, no crimson lips. Hair is natural black-brown. Makeup is light or bare. "
            "Eyes are normal black-brown. Do not deduct identity for that change. "
            "Do deduct, and set period_hair or period_makeup true, if the bun, ornaments, heavy makeup, or red lips remain. "
            "Set eyes_black_brown true only when the irises read black-brown."
        )
    elif actor == "elena_voss":
        look = (
            "Keep Elena's auburn hair, warm amber-brown eyes, and human ears. "
            "Do not give her pointed ears or green eyes. period_hair and period_makeup stay false. "
            "eyes_black_brown stays false because her eyes are amber-brown."
        )
    else:
        look = (
            "Keep Adrian's dark hair, pale blue-grey eyes, and pointed ears. No weapon. "
            "period_hair and period_makeup stay false. eyes_black_brown stays false."
        )
    if view == "back" and actor in PERIOD_RELEASE:
        look += " Back view: do not fail identity because the face is hidden. Eyes may be unseen."
    detail = ""
    if stage == "pass1":
        detail = (
            " Pass 1 may change only clothes, hair, and makeup on the clothed plate. "
            "Identity below 9 means the face was redrawn: face shape, features, or skin tone moved. "
            "Do not mark identity below 9 because the instructed hair or makeup changed. "
            "Wardrobe below 9 means cloth remains on the chest, abdomen, hips, or legs. "
            "Do not trade a locked face for leftover clothes. "
            "Pass 1 must clear every content score. Resolution is the only exemption: "
            "do not add a penalty, and do not waive a content score, only because the frame is small. "
            "Pixel count is pass 2. Wrong face, pose, anatomy, wardrobe, likeness, or motif still scores below 9."
        )
    elif stage == "pass2":
        detail = (
            " Pass 2 is a same-seed light upscale. Content must stay the pass-1 plate. "
            "Lower a score when the upscale changes the face, hair, makeup, pose, body, or anatomy."
        )
    return (
        "Do not generate an image. Do not edit any file. Score only the second image. "
        "The first image is this adult actor's makeup reference. "
        "This is one adult body template, not a scene and not two people. "
        f"Actor id: {actor}. View: {view}. {look}{detail} "
        "Nude pass requires every garment gone. If cloth remains on the chest, abdomen, hips, or legs, wardrobe is below 8. "
        "Full body, head and both feet in frame, plain background, adult only. "
        "Eight equal scores from 0 to 10: identity, distinction, interaction, aesthetics, anatomy, wardrobe, motif, photoreal. "
        "interaction means the pose is a stable turnaround, not a story pose. "
        "mean is their equal average. gates is [] or H6 for a minor look, H4 for Elena's ears or green eyes or Adrian missing ears or holding a weapon, "
        "H7 for malformed limbs, FEET if a foot is cut off. "
        "Output one JSON object only: "
        '{"gates":[],"period_hair":false,"period_makeup":false,"eyes_black_brown":false,'
        '"identity":0,"distinction":0,"interaction":0,"aesthetics":0,"anatomy":0,"wardrobe":0,'
        '"motif":0,"photoreal":0,"mean":0,"note":"一句"}'
    )
