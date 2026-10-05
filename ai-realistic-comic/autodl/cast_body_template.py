"""Reusable cast-body templates for later stills. Not a story workflow.

Female identity is the 2026-10-06 frontal lock, not the retired sheet.
A female clothed plate is rebuilt from that lock until its mean is at least 9.
Only then does pass 1 change clothes on that new plate.
Pass 1 must clear every content score. Resolution stays on the low grid.
The undress face stays locked to the new clothed plate. A framing sentence,
a face-lock sentence, and a clothes sentence stay apart. Front and side pass 1
send a jaw-up face crop as the second image. The back view does not. The clothes
sentence is the nude result, written twice. Identity, anatomy, or wardrobe under 9
does not open the next seed. The next check names its seeds. Spent seeds stay
out of the walker. A named seed may be rendered again. Pass 2 is a same-seed
light upscale and is forbidden until pass 1 clears. A pass-2 miss only changes
denoise and steps. The still agent proxies once. After shared login, this
pipeline runs itself and does not hand work back. This module does not import
or edit the explicit-still runner.
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
# was 2. 52 mean was 8.75 with empty gates and look.
# 53 mean 5.0, FEET, MAKEUP, identity 6, anatomy 3, wardrobe 9 (floating head).
# 54 mean 4.4, FEET, identity 7, anatomy 2, wardrobe 5 (head only).
# 55-61 stay on the framed prompt: full body, identity about 9, wardrobe 1-4.
# Means oscillate (7.6, 7.13, 7.75, 7.0, 7.4, 7.63, 6.75). That is not a drift.
# 62-83 are the 2026-10-06 pass-1 batch. All of them scored and none passed.
# 84 and 85 failed the scheme C research batch. The walker stops at 86.
# Named seeds may still be repeated. Void 33 may not.
LIN_FRONT_SEED = 62
LIN_FRONT_SPENT = frozenset(range(33, 86))
LIN_FRONT_A_CHECK = (62, 70, 78)
# Scheme B only, after that named check. The schedule table stays at 8.
B_PASS1_STEPS = 16
# Scheme C research batch. One 1.0 probe, then these seeds at 0.85 and 16 steps.
C_PASS1_STEPS = 16
C_PROBE_SCALE = 1.0
C_PROBE_SEED = 62
LIN_FRONT_C_BATCH = (62, 70, 78, 79, 80, 81, 82, 83, 84, 85)
# Next research batch. No second face image. 86-92 are not spent yet.
LIN_FRONT_NOFACE_BATCH = (62, 70, 78, 86, 87, 88, 89, 90, 91, 92)
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

# Twelve clothed turnarounds are the base plates.
# Male means are the makeup-ref rescore and still gate undress.
# Female means in this table do not open undress by themselves.
# Archived 2026-10-06 Codex plates: both women, and Gu front/side/back.
# Adrian cells are unchanged. A female view undresses only from the fresh json.
# A female view undresses only after a fresh plate scores a mean of at least 9.
CLOTHED_MEAN = {
    ("lin_wantang", "front"): 9.4125,
    ("lin_wantang", "side"): 9.4,
    ("lin_wantang", "back"): 9.4,
    ("gu_chengan", "front"): 9.3875,
    ("gu_chengan", "side"): 9.3625,
    ("gu_chengan", "back"): 9.375,
    ("elena_voss", "front"): 9.4625,
    ("elena_voss", "side"): 9.475,
    ("elena_voss", "back"): 9.3875,
    ("adrian_kane", "front"): 9.25,
    ("adrian_kane", "side"): 9.125,
    ("adrian_kane", "back"): 9.125,
}
CLOTHED_VIEWS = tuple(CLOTHED_MEAN)
FEMALE_ACTORS = frozenset({"lin_wantang", "elena_voss"})
LOCK_ID = "2026-10-06-front"
# Clothed rebuild borrows the old plate as a body donor and turns the NSFW LoRA off.
CLOTHED_SCALE = 0.0
CLOTHED_LIN_FRONT_SEED = 1
# Clothed plates have one generator. Undress has another. Neither may switch.
CLOTHED_ENTRY = "codex"
UNDRESS_ENTRY = "f34"
CODEX_ARGV_HEAD = (
    "exec",
    "--skip-git-repo-check",
    "--ephemeral",
    "--color",
    "never",
)
CODEX_MISSING = (
    "CODEX_CLI_MISSING 穿衣底板只走 Codex CLI。"
    "本机没有 codex。禁止改走其他图像入口，禁止锁脸直出，禁止用 F34 画穿衣底板。"
)
CODEX_LOGGED_OUT = (
    "CODEX_CLI_LOGGED_OUT 穿衣底板只走 Codex CLI。"
    "codex login status 未登录。禁止改走其他图像入口，禁止锁脸直出，禁止用 F34 画穿衣底板。"
)
CODEX_SCORE_ENTRY = "docs/codex-cast-score.md"
F34_POWER_RULE = (
    "F34 干活才开机。当前批次做完或暂停就立刻关机留盘。"
    "禁止空转，禁止为等下一步挂着机。"
    "除非用户当次明确说别关或先别开。"
)


def codex_exec_argv(binary: str, cwd: str, images: list[str]) -> list[str]:
    """Codex CLI image call. Reference images are repeated `-i` paths. Prompt is stdin."""
    cmd = [binary, *CODEX_ARGV_HEAD, "-C", str(cwd), "-s", "workspace-write"]
    for image in images:
        cmd.extend(["-i", str(image)])
    cmd.append("-")
    return cmd


def require_codex_cli(binary: str | None, *, logged_in: bool = True) -> str:
    """Hard stop. A missing or logged-out Codex CLI does not open another generator."""
    if not binary:
        raise SystemExit(CODEX_MISSING)
    if not logged_in:
        raise SystemExit(CODEX_LOGGED_OUT)
    return binary

# Nude turnarounds: clothed plates whose mean is at least 9.
# Gu side and back entered after the Codex plates cleared 9.
NUDE_VIEWS = (
    ("lin_wantang", "front"),
    ("lin_wantang", "side"),
    ("lin_wantang", "back"),
    ("gu_chengan", "front"),
    ("gu_chengan", "side"),
    ("gu_chengan", "back"),
    ("elena_voss", "front"),
    ("elena_voss", "side"),
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
    ("gu_chengan", "side"): "T恤和短裤",
    ("gu_chengan", "back"): "T恤和短裤",
    ("elena_voss", "front"): "T恤和短裤",
    ("elena_voss", "side"): "T恤和短裤",
    ("elena_voss", "back"): "T恤和短裤",
    ("adrian_kane", "front"): "T恤和短裤",
    ("adrian_kane", "side"): "T恤和短裤",
    ("adrian_kane", "back"): "T恤和短裤",
}

_PERIOD_LOOK = {
    "lin_wantang": "去发髻、头饰、花钿、浓妆、红唇。黑褐色头发松松束在脑后，额前干净，淡妆，黑褐眼，自然唇。",
    "gu_chengan": "去发髻、发套、发箍、额带、浓妆、红唇。黑褐色短发，淡妆，黑褐眼。",
}

_KEEP_LOOK = {
    "elena_voss": "保持棕波浪发松松束起、蓝灰眼、人耳，不要眼镜。",
    "adrian_kane": "保持深色发、浅蓝灰眼、尖耳，无武器。",
}

STORY_BANS = ("月下", "木屋", "夜湖", "雨桥", "冥府", "王座", "白蛇", "蛇尾", "石榴", "相拥")


def film_proxy_allowed() -> bool:
    """True only while a still-agent proxy is still authorized."""
    return FILM_PROXY_REMAINING > 0


def self_run_line() -> str:
    return "资产自己跑。禁止再让出片代跑。"


def clothed_passed(actor: str, view: str, fresh_mean: float | None = None) -> bool:
    """True when this clothed plate may be undressed.

    Men use the stored table. Women ignore that table: the old mean belonged
    to a retired face. Only a fresh mean of at least 9, measured on the new
    lock, opens undress.
    """
    if actor in FEMALE_ACTORS:
        if fresh_mean is None:
            return False
        try:
            return float(fresh_mean) >= KEEP_MEAN
        except (TypeError, ValueError):
            return False
    try:
        mean = float(CLOTHED_MEAN[(actor, view)])
    except (KeyError, TypeError, ValueError):
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


def qwen_vae_frame(width: int, height: int) -> tuple[int, int]:
    """Frame that diffusers 0.40 calculate_dimensions would feed the VAE.

    448x592 rounds to 448x576. The image is resampled, not center-cropped.
    Full-body seeds were produced on this path, so the round-off is not the
    FEET cause. The worker does not override it.
    """
    import math

    ratio = float(width) / float(height)
    area = float(width) * float(height)
    out_w = math.sqrt(area * ratio)
    out_h = out_w / ratio
    return int(round(out_w / 32) * 32), int(round(out_h / 32) * 32)


def seed_for(actor: str, view: str, attempt: int) -> int:
    """Next unspent seed. The pass-1 runner must not call this to walk a batch."""
    base = LIN_FRONT_SEED if (actor, view) == ("lin_wantang", "front") else OTHER_SEED
    return advance_seed(base + int(attempt), actor, view)


def parse_specified_seeds(text: str | None) -> list[int]:
    """Named seeds only. A missing list does not walk forward from the spent set."""
    if text is None or not str(text).strip():
        raise SystemExit("下一验证必须指定籽。禁止从已花种子往后盲递增。")
    chosen: list[int] = []
    for part in str(text).split(","):
        piece = part.strip()
        if not piece:
            continue
        if not piece.lstrip("-").isdigit():
            raise SystemExit(f"籽不是整数：{piece}")
        chosen.append(int(piece))
    if not chosen:
        raise SystemExit("下一验证必须指定籽。禁止从已花种子往后盲递增。")
    return chosen


def require_specified_seed(seed: int | None, actor: str, view: str) -> int:
    """One named seed. Spent seeds may be named again. Void 33 may not. No increment."""
    if seed is None:
        raise SystemExit("下一验证必须指定籽。禁止从已花种子往后盲递增。")
    chosen = int(seed)
    if is_void(actor, view, FIXED_SCALE, chosen):
        raise SystemExit(f"seed {chosen} 作废，不重跑。")
    return chosen


def scheme_after_named_pass1(items: list[dict]) -> str:
    """After the named plates. scheme_b, stop_or_expand, or stop. Never a new seed."""
    if not items:
        raise ValueError("named pass1 scores missing")
    wards: list[float] = []
    passed = False
    for item in items:
        if item.get("passed"):
            passed = True
        raw = item.get("wardrobe")
        if raw is None and isinstance(item.get("score"), dict):
            raw = item["score"].get("wardrobe")
        try:
            wards.append(float(raw))
        except (TypeError, ValueError):
            wards.append(0.0)
    if passed or any(score >= 7 for score in wards):
        return "stop_or_expand"
    if all(score <= 4 for score in wards):
        return "scheme_b"
    return "stop"


def clothed_seed_for(actor: str, view: str, attempt: int) -> int:
    """Seeds for the clothed rebuild. They are not the undress blacklist."""
    base = CLOTHED_LIN_FRONT_SEED if (actor, view) == ("lin_wantang", "front") else OTHER_SEED
    return int(base) + int(attempt)


def look_line(actor: str) -> str:
    if actor in _PERIOD_LOOK:
        return _PERIOD_LOOK[actor]
    if actor not in _KEEP_LOOK:
        raise KeyError(actor)
    return _KEEP_LOOK[actor]


def feeds_face(view: str) -> bool:
    """Front and side use the jaw-up crop. The back has no face to lock."""
    if view not in ("front", "side", "back"):
        raise KeyError(view)
    return view != "back"


def ref_face_rel(actor: str) -> str:
    """Jaw-up crop. This file does not replace ref.png."""
    return f"library/cast/{actor}/ref-face.png"


def face_lock_line(actor: str, view: str = "front") -> str:
    """Front and side name the head-only second image. Back does not."""
    if actor not in PERIOD_RELEASE and actor not in _KEEP_LOOK:
        raise KeyError(actor)
    if view == "back":
        return "背面不喂锁脸。"
    return "锁脸：第二张只有头，只锁五官和肤色，不要从第二张带衣服。"


def wardrobe_clause(actor: str, view: str) -> str:
    """Result state, written twice. The frame sentence stays out of this clause."""
    if (actor, view) not in GARMENTS:
        raise KeyError((actor, view))
    once = "胸腹髋腿只留皮肤，不要背心短裤内衣。"
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
    """New clothed plate only. Frame, face lock, and clothes removal stay apart."""
    return frame_clause() + face_lock_line(actor, view) + wardrobe_clause(actor, view)


def clothed_prompt(actor: str, view: str) -> str:
    """Rebuild a clothed plate. Image 1 is the new lock. Image 2 is only the body donor."""
    garment = GARMENTS[(actor, view)]
    return (
        "第一张是新锁脸。第二张只借成年身体比例、站姿和衣服，不要沿用第二张的旧脸。"
        + look_line(actor)
        + f"衣服保持{garment}，不要脱掉。"
        + frame_clause()
        + (
            "头、双手和双脚都完整入画，不要把手放进口袋，不要裁掉手指或脚。"
            if actor == "gu_chengan"
            else ""
        )
        + {
            "front": "这一张是正面全身，面对镜头。",
            "side": "这一张是左侧面全身。",
            "back": "这一张是背面全身。",
        }[view]
    )


def pass2_prompt(actor: str) -> str:
    """Same-seed light upscale. Retries must keep this text and change sampling only."""
    if actor not in _PERIOD_LOOK and actor not in _KEEP_LOOK:
        raise KeyError(actor)
    return "只放大。不改脸、身体、衣着、发型、妆。头和双脚仍留在画面内。"


def negative_for(actor: str, stage: str = "pass1") -> str:
    if stage == "clothed":
        base = "磨皮,塑料皮肤,裸体,文字,水印,未成年人"
        if actor in PERIOD_RELEASE:
            return base + ",发髻,头饰,花钿,红唇,古装妆,浓妆,金黄瞳"
        if actor == "elena_voss":
            return base + ",眼镜,尖耳,绿眼,赤褐发"
        return base
    base = "磨皮,塑料皮肤,衣服,内衣,短裤,裙子,袍子,文字,水印,未成年人"
    if actor in PERIOD_RELEASE:
        return base + ",发髻,头饰,花钿,红唇,古装妆,浓妆"
    return base


def parse_score(text: str) -> dict:
    """Read the score object. Codex may emit more than one JSON value."""
    decoder = json.JSONDecoder()
    found: list[dict] = []
    idx = 0
    while idx < len(text):
        start = text.find("{", idx)
        if start < 0:
            break
        try:
            data, end = decoder.raw_decode(text, start)
        except json.JSONDecodeError:
            idx = start + 1
            continue
        if isinstance(data, dict):
            if isinstance(data.get("items"), list) and data["items"]:
                item = data["items"][0]
                if isinstance(item, dict):
                    found.append(item)
            else:
                found.append(data)
        idx = max(end, start + 1)
    scored = [item for item in found if "identity" in item or "mean" in item]
    if scored:
        return scored[-1]
    if found:
        return found[-1]
    raise ValueError("score json missing")


def mean_of(item: dict) -> float:
    try:
        return float(item["mean"])
    except (TypeError, ValueError, KeyError):
        vals = [float(item[key]) for key in EIGHT]
        return sum(vals) / len(vals)


def look_gates(actor: str, view: str, item: dict) -> list[str]:
    """Period hair, makeup, iris color, and eye geometry. Missing flags do not pass."""
    gates: list[str] = []
    if view != "back" and item.get("eyes_geometry") is not True:
        gates.append("EYES_GEOMETRY")
    if actor not in PERIOD_RELEASE:
        return gates
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


EYE_DETAIL_MIN_SIDE = 200
GROK_SCORER = "grok-4.7-xhigh"
CODEX_SCORER = "codex"
LOCAL_SCORER = "local"
GROK_FALLBACK_MODEL = "opencode-go/grok-4.7"
GROK_FALLBACK_VARIANT = "xhigh"


def cap_identity_for_eyes(item: dict) -> dict:
    """A geometry miss caps identity at 7. Iris color does not offset it."""
    if item.get("eyes_geometry") is not False:
        return item
    try:
        identity = float(item.get("identity"))
    except (TypeError, ValueError):
        return item
    if identity > 7:
        item["identity"] = 7
    try:
        values = [float(item[key]) for key in EIGHT]
    except (TypeError, ValueError, KeyError):
        return item
    item["mean"] = round(sum(values) / len(values), 4)
    return item


def resolve_eyes(item: dict, short_side: int) -> dict:
    """Catchlights and eyelids count only when the eye crop's short side is at least 200."""
    structure_bad = item.get("eyes_structure") is False
    if int(short_side) < EYE_DETAIL_MIN_SIDE:
        item["eyes_geometry"] = not structure_bad
    else:
        detail_bad = item.get("eyes_detail") is False
        legacy_bad = (
            item.get("eyes_structure") is None
            and item.get("eyes_detail") is None
            and item.get("eyes_geometry") is False
        )
        item["eyes_geometry"] = not (structure_bad or detail_bad or legacy_bad)
    if item["eyes_geometry"] is False:
        return cap_identity_for_eyes(item)
    return item


def codex_should_fallback(returncode: int | None, detail: str) -> bool:
    """Quota, logout, a missing binary, or a Codex CLI error opens the grok fallback."""
    if returncode not in (0, None):
        return True
    lowered = (detail or "").lower()
    needles = (
        "usage limit",
        "logged out",
        "not logged",
        "codex_cli_missing",
        "codex_cli_logged_out",
        "codex_cli_failed",
        "quota",
        "insufficient",
    )
    return any(needle in lowered for needle in needles)


def grok_score_argv(binary: str, images: list[str]) -> list[str]:
    """Same rubric, grok 4.7 xhigh. This is the only fallback model."""
    cmd = [
        binary,
        "run",
        "--model",
        GROK_FALLBACK_MODEL,
        "--variant",
        GROK_FALLBACK_VARIANT,
        "--pure",
        "--format",
        "json",
        "--auto",
        "--dir",
        "/tmp/cast-score",
    ]
    for image in images:
        cmd.extend(["-f", str(image)])
    joined = " ".join(cmd).lower()
    for banned in ("deepseek", "agy", "gpt-"):
        if banned in joined:
            raise SystemExit(f"GROK_SCORE_FORBIDDEN {banned}")
    if GROK_FALLBACK_MODEL not in cmd or GROK_FALLBACK_VARIANT not in cmd:
        raise SystemExit("GROK_SCORE_MODEL_DRIFT")
    return cmd


def local_background_score() -> dict:
    """Head and chest matched the backdrop. Do not spend a scorer call."""
    item = {key: 2 for key in EIGHT}
    item.update(
        {
            "gates": [],
            "period_hair": False,
            "period_makeup": False,
            "eyes_black_brown": False,
            "eyes_structure": False,
            "eyes_detail": False,
            "eyes_geometry": False,
            "mean": 2.0,
            "note": "头胸被背景吃掉",
            "scorer": LOCAL_SCORER,
        }
    )
    return item


def torso_eaten_by_background(path: str) -> bool:
    """True when the head box and the chest box are the same flat gray as the corners."""
    from PIL import Image

    image = Image.open(path).convert("RGB")
    width, height = image.size

    def mean_box(box: tuple[int, int, int, int]) -> tuple[float, float, float]:
        crop = image.crop(box).resize((1, 1), Image.Resampling.BOX)
        pixels = [crop.getpixel((0, 0))]
        count = 1
        red = sum(pixel[0] for pixel in pixels) / count
        green = sum(pixel[1] for pixel in pixels) / count
        blue = sum(pixel[2] for pixel in pixels) / count
        return red, green, blue

    corners = (
        (0, 0, min(16, width), min(16, height)),
        (max(0, width - 16), 0, width, min(16, height)),
        (0, max(0, height - 16), min(16, width), height),
        (max(0, width - 16), max(0, height - 16), width, height),
    )
    background = [mean_box(box) for box in corners]
    base = tuple(sum(channel) / len(background) for channel in zip(*background))

    def eaten(box: tuple[int, int, int, int]) -> bool:
        red, green, blue = mean_box(box)
        chroma = max(red, green, blue) - min(red, green, blue)
        distance = sum(abs(channel - origin) for channel, origin in zip((red, green, blue), base)) / 3
        return distance < 14 and chroma < 18

    head = (int(width * 0.32), int(height * 0.02), int(width * 0.68), max(2, int(height * 0.20)))
    chest = (int(width * 0.35), int(height * 0.28), int(width * 0.65), max(3, int(height * 0.48)))
    return eaten(head) and eaten(chest)


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
        f"eyes_black_brown={item.get('eyes_black_brown')} "
        f"eyes_geometry={item.get('eyes_geometry')} scorer={item.get('scorer')} passed={passed} "
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
        "eyes_geometry": item.get("eyes_geometry"),
        "scorer": item.get("scorer"),
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


def accept_clothed(item: dict, actor: str, view: str, scale: float, seed: int) -> bool:
    """Clothed gate: every content score, including clothes still on the body."""
    return accept_pass1(item, actor, view, scale, seed)


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


# Byte-stable scoring prefix. Do not format this per image.
SCORE_PREFIX = (
    "不要生成图像。不要改文件。不要改写本标准。"
    "第一张图是定妆锁脸。第二张是结果的头肩裁切，只用来比眼睛。最后一张是全身，用来判衣着、姿势和脚。"
    "这是一张成年身体模板，不是情节，也不是两个人。全身，头和双脚都在画面内，纯色背景，仅限成年人。\n"
    "Eight equal scores from 0 to 10: identity, distinction, interaction, aesthetics, anatomy, wardrobe, motif, photoreal. "
    "interaction means the pose is a stable turnaround, not a story pose. "
    "mean is their equal average. gates is [] or H6 for a minor look, H4 for Elena's ears or green eyes or glasses or Adrian missing ears or holding a weapon, "
    "H7 for malformed limbs, FEET if a foot is cut off.\n"
    "只输出一个 JSON 对象：\n"
    '{"gates":[],"period_hair":false,"period_makeup":false,"eyes_black_brown":false,'
    '"eyes_structure":false,"eyes_detail":false,"eyes_geometry":false,'
    '"identity":0,"distinction":0,"interaction":0,"aesthetics":0,"anatomy":0,"wardrobe":0,'
    '"motif":0,"photoreal":0,"mean":0,"note":"一句"}\n'
    "eyes_black_brown is iris color only. "
    "eyes_structure is false only when the eyes differ in size, the outer corners are uneven, or the gaze splits. "
    "eyes_detail is false only when a catchlight is missing or an eyelid is smeared. "
    "The tail gives eye_crop_short_side. "
    "When that short side is below 200, eyes_geometry follows eyes_structure only. "
    "Do not fail, and do not lower identity, for a missing catchlight or a soft eyelid on that small crop. "
    "When the short side is 200 or more, eyes_geometry is false if eyes_structure or eyes_detail is false, "
    "and identity is then at most 7. Iris color does not cancel a structural failure.\n"
    "林晚棠、顾承安：Nude template for Lin or Gu. Identity is facial features, face shape, skin tone, and body type. "
    "Costume hair and makeup must be gone: no hair bun, no hairpins, no forehead ornament, "
    "no heavy eye makeup, no crimson lips. Hair is natural black-brown. Makeup is light or bare. "
    "Eyes are normal black-brown. Do not deduct identity for that change. "
    "Do deduct, and set period_hair or period_makeup true, if the bun, ornaments, heavy makeup, or red lips remain. "
    "Set eyes_black_brown true only when the irises read black-brown. That flag is color only. "
    "Set eyes_structure false only for unequal size, uneven corners, or a split gaze. "
    "Set eyes_detail false only for a missing catchlight or a smeared eyelid. "
    "On a crop whose short side is below 200, eyes_geometry equals eyes_structure, and identity stays uncapped "
    "when the structure holds. On a larger crop, either detail miss also sets eyes_geometry false and identity "
    "is at most 7. A true eyes_black_brown does not cancel that. Compare eyes on the head crop against the lock. "
    "Do not judge eye shape from the tiny face in the full-body frame. "
    "Back view: do not fail identity because the face is hidden. Eyes may be unseen.\n"
    "伊莲·沃斯：Keep Elena's soft brown wavy hair loosely pulled back, clear blue-grey eyes, and human ears. "
    "No glasses. Do not give her pointed ears, green eyes, auburn hair, or amber eyes. "
    "period_hair and period_makeup stay false. eyes_black_brown stays false because her eyes are blue-grey.\n"
    "阿德里安·凯恩：Keep Adrian's dark hair, pale blue-grey eyes, and pointed ears. No weapon. "
    "period_hair and period_makeup stay false. eyes_black_brown stays false.\n"
    "阶段 clothed：This is a clothed full-body plate, not a nude. "
    "The first image is the new frontal lock. Identity below 9 means the result face does not match that lock. "
    "Do not accept the retired gold eyes, crimson lips, period bun, auburn hair, or amber eyes. "
    "Wardrobe below 9 means the named everyday clothes are missing, or a period costume replaced them. "
    "Nudity is a wardrobe failure on this stage. "
    "The plate must clear every content score. Resolution is the only exemption.\n"
    "阶段 pass1：Pass 1 may change only clothes, hair, and makeup on the clothed plate. "
    "The makeup reference is the current lock face. "
    "Identity below 9 means the face was redrawn: face shape, features, or skin tone moved. "
    "Do not mark identity below 9 because the instructed hair or makeup changed. "
    "Wardrobe below 9 means cloth remains on the chest, abdomen, hips, or legs. "
    "Do not trade a locked face for leftover clothes. "
    "Pass 1 must clear every content score. Resolution is the only exemption: "
    "do not add a penalty, and do not waive a content score, only because the frame is small. "
    "Pixel count is pass 2. Wrong face, pose, anatomy, wardrobe, likeness, or motif still scores below 9. "
    "Nude pass requires every garment gone. If cloth remains on the chest, abdomen, hips, or legs, wardrobe is below 8. "
    "正面没有乳点、没有肚脐、并且髋部有衣缝，是肉色连体，wardrobe 最高 6。不要因为看不见背心短裤就给到 9。 "
    "pass1 的 motif：无情节的成年全身站姿模板，纯色背景，与锁脸同一人；没有剧情互动不扣分；胸腹髋腿还有布则 motif<9。\n"
    "阶段 pass2：Pass 2 is a same-seed light upscale. Content must stay the pass-1 plate. "
    "Lower a score when the upscale changes the face, hair, makeup, pose, body, or anatomy. "
    "Nude pass requires every garment gone. If cloth remains on the chest, abdomen, hips, or legs, wardrobe is below 8.\n"
)


def score_call(
    actor: str,
    view: str,
    stage: str,
    images: list[str],
    short_side: int | None = None,
) -> str:
    """Fixed prefix plus a short tail. The tail is the only text that changes per plate."""
    if stage not in ("clothed", "pass1", "pass2"):
        raise KeyError(stage)
    if view not in ("front", "side", "back"):
        raise KeyError(view)
    if len(images) != 3:
        raise ValueError("score_call expects the lock, the eye crop, and the full plate")
    side_line = "" if short_side is None else f"eye_crop_short_side={int(short_side)}\n"
    tail = (
        f"Actor id: {actor}. View: {view}. Stage: {stage}.\n"
        f"{side_line}"
        f"{images[0]}\n{images[1]}\n{images[2]}\n"
        "第二张只比眼睛。最后一张判衣着、姿势和脚。\n"
    )
    return SCORE_PREFIX + tail


def score_exec_argv(binary: str | None, *, logged_in: bool, cwd: str, images: list[str]) -> list[str]:
    """Codex CLI only. A missing login raises before any other vision command exists."""
    binary = require_codex_cli(binary, logged_in=logged_in)
    argv = codex_exec_argv(binary, cwd, images)
    joined = " ".join(argv).lower()
    for banned in ("opencode", "deepseek-v4-flash-vision", "agy"):
        if banned in joined:
            raise SystemExit(f"CODEX_SCORE_FORBIDDEN {banned}")
    return argv


def f34_should_power_on(*, has_work: bool, hold_off: bool) -> bool:
    """True only when this batch has F34 work and the user did not say 先别开."""
    if hold_off or not has_work:
        return False
    return True


def f34_should_power_off(*, finished: bool, paused: bool, keep_on: bool) -> bool:
    """True when the batch finished or paused, unless the user said 别关 this time."""
    if keep_on:
        return False
    return bool(finished or paused)
