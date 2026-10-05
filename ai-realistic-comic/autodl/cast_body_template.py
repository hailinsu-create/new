"""Reusable cast-body templates for later stills. Not a story workflow.

Prompts only change hair, makeup, clothes, and the body detail a nude
turnaround needs. Face shape, features, and skin tone stay locked.
This module does not import or edit the explicit-still runner.
"""
from __future__ import annotations

import json

KEEP_MEAN = 9.0
FIXED_SCALE = 0.85
# Seed 33 at this scale is the rejected Lin front pass 1. Never a pass.
VOID_LIN_FRONT = ("lin_wantang", "front", 0.85, 33)
LIN_FRONT_SEED = 34
OTHER_SEED = 41
PASS1_SEED_TRIES = 3

PASS1_SIZE = (448, 592)  # verified ~448x600 bucket, 16 steps
PASS1_STEPS = 16
PASS2_SIZE = (896, 1200)
PASS2_SCORE_TRIES = ((0.35, 40), (0.30, 40), (0.25, 40))
PASS2_OOM_TRIES = ((0.35, 28), (0.35, 20), (0.30, 20))

F34_UUID = "xaxna66hqt-c5c9c7fc"
G09_UUID = "sa4eaxgcuq-26e36fc9"
LORA_REMOTE = "/root/autodl-tmp/loras/qwen-image-edit-plus-nsfw-lora.safetensors"

JOB_REMOTE = "/root/autodl-tmp/in/cast-asset-job.json"
DONE_REMOTE = "/root/autodl-tmp/out/cast-asset-done.json"
STOP_REMOTE = "/root/autodl-tmp/in/cast-asset-stop"
WORKER_REMOTE = "/root/autodl-tmp/cast-asset/worker.py"
WORKER_LOG = "/root/autodl-tmp/cast-asset/worker.log"

PASS1_KEYS = ("identity", "interaction", "anatomy", "wardrobe")
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

# Nine nude turnarounds. Gu is front only; Elena is front and back.
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
    "lin_wantang": (
        "去掉古装发髻、头饰、花钿、浓妆和红唇。"
        "头发改为自然披下的黑褐色长发，不要发髻。"
        "妆面改为淡妆或素颜。眼睛改为正常的黑褐色。"
        "只保持五官、脸型和肤色。"
    ),
    "gu_chengan": (
        "去掉发髻、额前头巾或发带、浓妆和红唇。"
        "头发改为自然的黑褐色短发，不要发髻。"
        "妆面改为淡妆或素颜。眼睛改为正常的黑褐色。"
        "只保持五官、脸型和肤色。"
    ),
}

_KEEP_LOOK = {
    "elena_voss": "发型和妆容保持这张图。眼睛保持暖琥珀棕。人耳，不要尖耳。",
    "adrian_kane": "发型和妆容保持这张图。眼睛保持浅蓝灰。尖耳保留。不要武器。",
}

STORY_BANS = ("月下", "木屋", "夜湖", "雨桥", "冥府", "王座", "白蛇", "蛇尾", "石榴", "相拥")


def is_void(actor: str, view: str, scale: float, seed: int) -> bool:
    return (actor, view, float(scale), int(seed)) == VOID_LIN_FRONT


def seed_for(actor: str, view: str, attempt: int) -> int:
    """Fixed scale lives outside. Seeds step by one and skip the void pair."""
    base = LIN_FRONT_SEED if (actor, view) == ("lin_wantang", "front") else OTHER_SEED
    seed = base + int(attempt)
    while is_void(actor, view, FIXED_SCALE, seed):
        seed += 1
    return seed


def look_line(actor: str) -> str:
    if actor in _PERIOD_LOOK:
        return _PERIOD_LOOK[actor]
    if actor not in _KEEP_LOOK:
        raise KeyError(actor)
    return _KEEP_LOOK[actor]


def pass1_prompt(actor: str, view: str) -> str:
    clothes = GARMENTS[(actor, view)]
    return (
        f"去掉{clothes}，露出皮肤。"
        f"{look_line(actor)}"
        "补上乳头和下体结构，皮肤保留毛孔和细纹。"
        "头部和双脚留在画面内。"
        "姿势和体型保持这张图。"
        "背景保持朴素。"
        "nsfw nipples"
    )


def pass2_prompt(actor: str) -> str:
    return (
        "保持这张图的五官、脸型、肤色、姿势和体型。"
        f"{look_line(actor)}"
        "补上清晰毛孔、细纹、乳头和下体结构。不要磨皮，不要塑料皮肤。"
        "头部和双脚留在画面内。"
        "nsfw nipples"
    )


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


def accept_pass1(item: dict, actor: str, view: str, scale: float, seed: int) -> bool:
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
            " Pass 1 is low resolution. Anatomy is limb count, proportions, and joints. "
            "Do not lower identity, anatomy, aesthetics, photoreal, or motif because the frame is small, "
            "skin is smooth, or nipple and genital detail is soft. Texture is pass 2."
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
