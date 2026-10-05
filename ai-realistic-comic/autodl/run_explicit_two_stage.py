"""Two-stage still runner.

Stage 1 lock images come only from Codex CLI. agy is forbidden.
A missing Codex binary fails and exits before that lock. There is no image fallback.
Scoring tries Codex, then grok-4.7 xhigh with the same prefix. Stage 2 is F34 Qwen.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPT_FILES = (
    ROOT / "library" / "stills" / "explicit-8" / "prompts.md",
    ROOT / "library" / "stills" / "myth-poses" / "prompts.md",
)
ANCHOR = ROOT / "library" / "stills" / "explicit-8" / "anchor-10.jpg"
RUBRIC = ROOT / "docs" / "still-score-two-stage.md"
KEEP_MEAN = 9.0

# F34 only. Power on to do Qwen work. Shut down and keep the disk when the
# batch is done, paused, idle, or waiting. Never release or delete.
F34_UUID = "xaxna66hqt-c5c9c7fc"
G09_UUID = "sa4eaxgcuq-26e36fc9"
F34_DISK_BYTES = 107374182400
F34_POWER_ON_URL = "https://www.autodl.com/api/v1/instance/power_on"
F34_POWER_OFF_URL = "https://www.autodl.com/api/v1/instance/power_off"
F34_LIST_URL = "https://www.autodl.com/api/v1/instance"
F34_BALANCE_URL = "https://www.autodl.com/api/v1/wallet/balance"
F34_STOP_PHASES = frozenset({"done", "paused", "idle", "wait"})

# Fixed prefix. Do not interpolate paths, the frame under test, or scorer.
# Codex and the grok-4.7 xhigh fallback both receive these exact bytes.
SCORE_PREFIX = """打分用同一份标准。Codex CLI 可用就由 Codex 看图执行。Codex 不可用时由 grok-4.7 xhigh 看图执行。禁止 OpenCode Go vision。禁止 deepseek-v4-flash-vision。禁止 agy。禁止其它识图回退。不要生成图，不要改文件。
第一张附件是满分基准 anchor-10，八项固定 10。第一段、一采、二采用同一前缀。
八项等权，各 0–10：身份、区分、互动、美感、解剖、服装、动机、摄影感。均分低于 9 不算过。
H1 鱼尾、鱼鳍、尾鳍。
H2 尾尖是蛇头、断开的珍珠球或切断的断尖。和基准一样的圆钝连体尾尖不算。
H3 白蛇自己长出人腿或人脚。许仙自己的脚不算。人身格的人腿是对的。雨桥没有蛇尾。
H4 伊莲尖耳或绿眼。阿德里安没了尖耳或拿了武器。别人长尖耳。
H5 不是正好两人，多一张脸，或拼贴。
H6 看起来像未成年人。
H7 看得见的手多指、多一只手、断肢。被挡住的手指不算。
硬门非空不算过，不能把硬门平均掉。
只输出一个 JSON 对象：
{"scene":"六个字内","gates":[],"face_drift":false,"identity":0,"distinction":0,"interaction":0,"aesthetics":0,"anatomy":0,"wardrobe":0,"motif":0,"photoreal":0,"mean":0,"note":"一句"}
gates 只填失败的门，例如 ["H2"]。没有失败就是 []。face_drift 只有脸不像定妆时才是 true。mean 是八项等权均分。
"""


def agy_block_reason(binary: str | None, *, logged_in: bool) -> str | None:
    """Stage 1 is Codex only. agy is never a substitute, logged in or not."""
    del binary, logged_in
    return "禁止 agy。第一段锁定图只许 Codex CLI。不许降级，不开机。"


def local_explicit_allowed(item: dict) -> bool:
    """Qwen may raise explicitness only after Codex has already passed the lock."""
    return accepted(item)


def stage2_action(item: dict) -> str:
    """keep, or redo pass 2 only. Face drift is a content change, not a new pass 1."""
    if item.get("face_drift"):
        return "reshoot"
    if accepted(item):
        return "keep"
    return "reshoot"


def accepted(item: dict) -> bool:
    gates = item.get("gates") or []
    try:
        mean = float(item.get("mean"))
    except (TypeError, ValueError):
        return False
    return not gates and mean >= KEEP_MEAN


def pass1_accepted(item: dict) -> bool:
    """Pass 1 locks content: face, pose, anatomy, wardrobe or contact, hard gates.

    Resolution and photoreal texture do not block pass 1.
    """
    if item.get("gates"):
        return False
    for key in ("identity", "interaction", "anatomy", "wardrobe"):
        try:
            value = float(item.get(key))
        except (TypeError, ValueError):
            return False
        if value < KEEP_MEAN:
            return False
    return True


def parse_score(text: str) -> dict:
    start = text.find("{")
    if start < 0:
        raise SystemExit("score json missing")
    try:
        data, _end = json.JSONDecoder().raw_decode(text[start:])
    except json.JSONDecodeError as exc:
        raise SystemExit(f"score json missing: {exc}") from exc
    if isinstance(data.get("items"), list) and data["items"]:
        data = data["items"][0]
    if not isinstance(data, dict):
        raise SystemExit("score json was not an object")
    return data


def _blocks(text: str) -> list[dict]:
    out = []
    for m in re.finditer(r"<!-- ([PM]\d\d)_START -->(.*?)<!-- \1_END -->", text, re.S):
        body = m.group(2)
        gen = re.search(r"<!-- GEN_START -->(.*?)<!-- GEN_END -->", body, re.S)
        neg = re.search(r"<!-- NEG_START -->(.*?)<!-- NEG_END -->", body, re.S)
        refs = []
        width = height = 0
        for line in body.splitlines():
            line = line.strip()
            if line.startswith("- library/"):
                refs.append(ROOT / line[2:].strip())
            elif line.startswith("width:"):
                width = int(line.split(":", 1)[1])
            elif line.startswith("height:"):
                height = int(line.split(":", 1)[1])
        if not gen or not neg or len(refs) < 2 or width < 256:
            raise SystemExit(f"bad block {m.group(1)}")
        out.append(
            {
                "id": m.group(1).lower(),
                "prompt": gen.group(1).strip(),
                "negative": neg.group(1).strip(),
                "refs": refs,
                "width": width,
                "height": height,
            }
        )
    return out


def require_subset(raw: str, known: set[str]) -> set[str]:
    only = {item.strip().lower() for item in raw.split(",") if item.strip()}
    if not only:
        raise SystemExit(
            "EXPLICIT_ONLY is required. Refusing to render p01-p08 and m01-m04 together."
        )
    unknown = sorted(only - known)
    if unknown:
        raise SystemExit(f"unknown EXPLICIT_ONLY: {', '.join(unknown)}")
    return only


def _load_panels() -> list[dict]:
    out = []
    for path in PROMPT_FILES:
        if not path.is_file():
            raise SystemExit(f"missing prompts {path}")
        out.extend(_blocks(path.read_text(encoding="utf-8")))
    ids = [panel["id"] for panel in out]
    expected = [f"p{n:02d}" for n in range(1, 9)] + [f"m{n:02d}" for n in range(1, 5)]
    if ids != expected:
        raise SystemExit(f"expected {expected}, got {ids}")
    return out


def score_still(image: Path) -> dict:
    """Both still stages score through Codex CLI."""
    del image
    raise SystemExit("禁止 OpenCode Go vision。出片两段打分只许 Codex CLI。缺 Codex 失败退出。")


def _render_until_kept(provider, panel: dict, dest: Path, seed: int) -> None:
    """Retired local-Qwen first frame. It skips the Codex lock."""
    del provider, panel, dest, seed
    raise SystemExit("禁止降级。锁定图必须先由 Codex CLI 生成。不许直接用本地 Qwen 出第一段。")


GROK_MODEL = "grok-4.7"
GROK_EFFORT = "xhigh"
SCORER_CODEX = "codex"
SCORER_GROK = "grok-4.7-xhigh"


class CodexUnavailable(RuntimeError):
    """Codex CLI cannot score this frame. The only fallback is grok-4.7 xhigh."""


def _grok_binary() -> str:
    found = shutil.which("grok")
    if found:
        return found
    local = Path.home() / ".grok" / "bin" / "grok"
    if local.is_file():
        return str(local)
    raise SystemExit("grok CLI is required before the local explicit pass")


def nude_body_refs(actor_id: str) -> list[Path]:
    """Human-form nude body refs. These do not replace the clothed makeup ref.png."""
    folder = ROOT / "library" / "cast" / actor_id / "body-nude"
    return [
        folder / name
        for name in ("front.png", "side.png", "back.png")
        if (folder / name).is_file()
    ]


def clothed_body_refs(actor_id: str) -> list[Path]:
    """Clothed turnaround made before the nude body refs. Not a makeup replacement."""
    folder = ROOT / "library" / "cast" / actor_id / "body-clothed"
    return [
        folder / name
        for name in ("front.png", "side.png", "back.png")
        if (folder / name).is_file()
    ]


def body_clothed_prompt(actor_id: str, view: str, dest: Path) -> str:
    """Face stays on the makeup ref. Body and pose are free. Clothes are simple and removable."""
    locks = {
        "lin_wantang": (
            "Adult East Asian woman Lin Wantang, mid-to-late twenties. "
            "Human ears, not pointed. Yellow-gold eyes. Glossy blue-black hair. "
            "Human body with two legs and two bare feet. No snake tail on this sheet."
        ),
        "gu_chengan": (
            "Adult East Asian man Gu Cheng'an, late twenties. "
            "Human ears, not pointed. Both of his own bare feet must be visible. No weapon."
        ),
        "elena_voss": (
            "Adult Western woman Elena Voss, late twenties. "
            "Amber-brown eyes, not green. Human ears, not pointed, and visible. No weapon."
        ),
        "adrian_kane": (
            "Adult Western man Adrian Kane, late thirties to early forties. "
            "Pointed ears must stay visible. Pale blue-grey eyes. Short salt-and-pepper beard. "
            "No weapon. Both bare feet visible."
        ),
    }
    views = {
        "front": "front view, facing the camera",
        "side": "exact side profile",
        "back": "back view, no second face",
    }
    return (
        "Use the image generation tool exactly once. "
        "Non-sexual clothed body reference. Not a sexual scene. "
        f"Neutral standing {views[view]}. Full body in frame, head and both feet included. "
        "Simple ordinary clothes that cover more and are still easy to remove later: "
        "a plain short-sleeve T-shirt and knee-length athletic shorts, or plain long pants. "
        "Neutral standing pose, no fashion pose. "
        "Do not copy the costume on the makeup sheet. "
        "Plain light gray background, even studio light, stable standing pose, adult proportions, clear arms and legs. "
        "No weapon. No text. No watermark. No child, no teen, no minor. "
        "Match the face, age, hair, and ears on the attached makeup reference. Do not invent a different face. "
        "The body and the standing pose are not locked to the makeup sheet.\n"
        f"{locks[actor_id]}\n"
        f"Save the image only to {dest}."
    )


# Still table only. Plot and contact intensity stay here.
# Cast assets must not read these numbers. Their table is shorter steps and lower denoise.
QWEN_LORA_FILE = "/root/autodl-tmp/loras/qwen-image-edit-plus-nsfw-lora.safetensors"
QWEN_PASS1_SIZE = (448, 600)
QWEN_PASS1_STEPS = 16
# Default pipeline VAE area is 1024**2, so a 448x600 frame was still encoded
# near 896x1184. Pass 1 sets the condition area to the pass-1 frame.
QWEN_PASS1_VAE_AREA = 448 * 600
QWEN_PASS2_SIZE = (896, 1200)
QWEN_PASS2_STEPS = (40, 32, 24)
QWEN_PASS2_DENOISE = (0.35, 0.30, 0.25)
QWEN_PASS2_LOCK = "只提高分辨率，并补轻度细节。不要改脸、姿势、衣服、接触和构图。"
# Filled when the body-undress sweep locks a scale. Do not invent one before that.
QWEN_LORA_SCALE = None
QWEN_LORA_SEED = None
QWEN_LORA_DENOISE = None


def body_undress_rules(actor_id: str) -> str:
    """Pass 1 may change only clothes, hair, and makeup.

    Face shape and facial features stay. The only input is the clothed plate.
    Identity or anatomy under 9 switches seed. Pass 2 waits for a passed pass 1.
    """
    hair = {
        "lin_wantang": "发髻放下，去掉头饰和花钿。头发改为自然披下的黑褐色长发。去掉浓妆和红唇，改为淡妆或素颜。",
        "gu_chengan": "去掉发髻和额前头巾或发带。头发改为自然的黑褐色短发。去掉浓妆和红唇，改为淡妆或素颜。",
        "elena_voss": "发型和妆保持这张图。",
        "adrian_kane": "发型和妆保持这张图。尖耳保留。",
    }.get(actor_id, "发型和妆保持这张图。")
    return (
        "只改衣着、发型和妆。脸型和五官不动。只喂这张穿衣底板，不喂定妆 ref。"
        "去掉这张图上实际穿着的衣服，露出皮肤，不要大段描述衣服。"
        f"{hair}"
        "不要换脸，不要重画五官。"
        "identity 或 anatomy 低于 9 立刻换种子，不在同一张上死磨。"
        "一采未过门禁止进入二采。"
    )


def score_body_ref(image: Path, actor_id: str, *, nude: bool = False, stage: str = "full") -> dict:
    """Codex scores one body ref against that actor's makeup ref."""
    makeup = ROOT / "library" / "cast" / actor_id / "ref.png"
    if not makeup.is_file():
        raise SystemExit(f"missing makeup ref {makeup}")
    view = image.stem
    if nude:
        back = (
            "This is a nude body ref. Identity is facial features, face shape, skin tone, and body type. "
            "The edit may only change clothes, hair, and makeup. Face shape and facial features stay. "
            "Costume hair and makeup must be gone: no hair bun, no hairpins, no forehead ornament, no heavy eye makeup, no red lipstick. "
            "Do not deduct identity for that hair and makeup change, or for keeping the original eye color. "
            "Do deduct identity if the face was redrawn, or if the costume bun, hair ornaments, heavy makeup, or red lips remain. "
            "Adrian must still keep pointed ears. "
            + (
                "A back view still must not lose points because the face is hidden; use hair color, skin tone, and body type."
                if view == "back"
                else ""
            )
        )
    elif view == "back":
        back = (
            "This is a back view. Score identity from hairstyle, hair color, skin tone, "
            "and body type against the makeup reference. Do not lower identity because the face is not visible."
        )
    else:
        back = "Where the face is visible, identity includes the face on the makeup reference."
    if stage == "pass1":
        detail = (
            "This is pass 1 at low resolution. "
            "Identity is only face shape, features, skin tone, and body type. "
            "Anatomy is only limb count, proportions, and joints. "
            "Do not lower identity, anatomy, aesthetics, photoreal, or motif because the frame is small, "
            "skin is smooth, pores are missing, or nipple and genital detail is soft. "
            "Texture and those details are scored on pass 2. "
        )
    else:
        detail = ""
    clothes_line = (
        "Nude pass requires every garment gone: no shirt, no shorts, no underwear, no cloth on the chest, abdomen, hips, or legs. "
        "If any garment remains, wardrobe must be below 8. Skin on the torso and hips must be visible. There is no weapon. "
        if nude
        else "clothes are simple and fitted, and there is no weapon. "
    )
    ask = (
        "Do not generate an image. Do not edit any file. Score only the second image. "
        "The first image is this actor's makeup reference and must be used. "
        "It is one adult actor, not a two-person still, so do not fail it for being one person. "
        f"Actor id: {actor_id}. View: {view}. {back} {detail}"
        "Pass only if identity matches that makeup reference, the person looks adult, "
        "the full body and both feet are in frame, limbs are clear, the background is plain, "
        f"{clothes_line}"
        "Elena must not have pointed ears or green eyes. Adrian must keep pointed ears and hold no weapon. "
        "Gu Cheng'an's own feet must be visible. Others have human ears. "
        "If an H4 gate fails, the note must say the exact miss: pointed ears, green eyes, or a weapon. "
        "Eight equal scores from 0 to 10: identity, distinction, interaction, aesthetics, anatomy, wardrobe, motif, photoreal. "
        "interaction here means the pose is stable and readable. "
        "mean is their equal average. gates is [] or failed ids such as H6 for a minor look, "
        "H4 for the ear or eye or weapon miss, H7 for malformed limbs, FEET if required feet are missing. "
        'Output one JSON object only: {"gates":[],"face_drift":false,"identity":0,"distinction":0,"interaction":0,'
        '"aesthetics":0,"anatomy":0,"wardrobe":0,"motif":0,"photoreal":0,"mean":0,"note":"一句"}'
    )
    result = _codex_exec(ask, [makeup, image], image.parent)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout or "body score failed").strip()
        raise SystemExit(detail[-800:])
    return parse_score(f"{result.stdout or ''}\n{result.stderr or ''}")


def _qwen_edit_refs(panel: dict, likeness: Path) -> list[Path]:
    """Qwen receives only the Codex lock. No makeup sheet and no body board."""
    del panel
    return [likeness]


_BANNED_GENERIC_EDIT = (
    "open her robe and bandeau, open his robe, and increase their chest contact"
)


def explicit_edit_instruction_ok(text: str) -> bool:
    """Accept the meaning of one edit instruction. Do not require one picture's clothes."""
    text = text.strip()
    if not text:
        return False
    lowered = text.lower()
    if _BANNED_GENERIC_EDIT in lowered:
        return False
    if "不要改姿势" in text or "do not change the pose" in lowered:
        return False
    if any(mark in text for mark in ("我先", "再写", "不套用", "开场")):
        return False
    if "Photoreal" in text or "Adult fiction only" in text:
        return False
    names_closed_clothes = any(
        mark in text for mark in ("合", "掩", "遮", "裹", "拢", "扣", "没开", "未开", "挡")
    ) and any(mark in text for mark in ("袍", "衫", "襟", "纱", "带", "领", "抹胸", "胸衣", "衣"))
    opens_to_skin = "胸部皮肤" in text and any(
        mark in text for mark in ("敞开", "拉开", "拨开", "打开")
    )
    chest_contact = "胸口" in text and any(mark in text for mark in ("相贴", "接触"))
    keeps_foot = "脚" in text or "赤足" in text
    keeps_tail = all(mark in text for mark in ("不断开", "珍珠白", "圆钝", "青绿", "腹鳞", "尾"))
    return bool(
        names_closed_clothes
        and opens_to_skin
        and chest_contact
        and "脸" in text
        and "许仙" in text
        and "顾承安" in text
        and keeps_foot
        and keeps_tail
    )


def _only_edit_instruction(raw: str) -> str | None:
    """Return the one instruction, never the preamble around it."""
    raw = raw.strip()
    suffixes = [raw]
    for index, char in enumerate(raw):
        if char == "。" and index + 1 < len(raw):
            suffixes.append(raw[index + 1 :].strip())
    accepted = [item for item in suffixes if explicit_edit_instruction_ok(item)]
    if not accepted:
        return None
    return min(accepted, key=len)


def write_explicit_edit_with_grok(lock: Path) -> str:
    """Look at the passing Codex lock and return the only prompt Qwen may receive."""
    if not lock.is_file():
        raise SystemExit(f"missing Codex lock {lock}")
    ask = (
        "看附件这张已经通过的定妆锁图，只写 Qwen 会收到的唯一一条编辑指令。"
        "自己看这张图里实际还合着、掩着或没敞开的具体衣服，点出那些衣服。"
        "不要假设每张图都是袍子、抹胸和领口还合着。"
        "写明把这张图里实际还合着的衣服敞开到胸部皮肤能看见，并且胸口相贴或胸口接触能看见。"
        "保留脸、许仙/顾承安自己露出的脚（赤足也算）、一条不断开的珍珠白圆钝蛇尾，青绿只在腹鳞。"
        "禁止写成笼统的 Open her robe and bandeau, open his robe, and increase their chest contact。"
        "禁止贴整场提示词。禁止写“不要改姿势”。"
        "可以先看图。最后单独一行只放这一条指令，不要把开场、解释或过程写进那一行。"
    )
    # ACP image blocks require base64 `data`. The PNG exceeds ARG_MAX, so the
    # same lock is sent as a JPEG of those pixels.
    import base64
    import io

    from PIL import Image

    image = Image.open(lock).convert("RGB")
    image.thumbnail((1024, 1024))
    payload = ""
    for quality in (70, 55, 40, 30):
        buffer = io.BytesIO()
        image.save(buffer, format="JPEG", quality=quality)
        payload = json.dumps(
            [
                {"type": "text", "text": ask},
                {
                    "type": "image",
                    "mimeType": "image/jpeg",
                    "data": base64.b64encode(buffer.getvalue()).decode("ascii"),
                },
            ]
        )
        if len(payload) < 90000:
            break
    result = subprocess.run(
        _grok_command(payload),
        capture_output=True,
        text=True,
        timeout=900,
    )
    raw = (result.stdout or "").strip()
    instruction = _only_edit_instruction(raw)
    if instruction:
        return instruction
    detail = (result.stderr or raw or "grok edit instruction failed").strip()
    if result.returncode != 0:
        raise SystemExit(detail[-800:])
    raise SystemExit("grok-4.7 xhigh did not point at the clothes still closed in this lock")


def codex_block_reason(binary: str | None, *, logged_in: bool) -> str | None:
    """Fail before stage 1 when Codex CLI is missing or not already logged in.

    This does not run `codex login`, does not call agy, and does not start a GPU.
    """
    if not binary:
        return "缺 Codex CLI。失败退出。禁止 agy，禁止降级，不开机。"
    if not logged_in:
        return "Codex CLI 未登录。失败退出。不执行登录，不开机，禁止改走 agy。"
    return None


def _codex_binary() -> str | None:
    found = shutil.which("codex")
    if found:
        return found
    local = Path.home() / ".local" / "bin" / "codex"
    if local.is_file():
        return str(local)
    return None


def _codex_logged_in() -> bool:
    binary = _codex_binary()
    if not binary:
        return False
    result = subprocess.run(
        [binary, "login", "status"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    text = f"{result.stdout or ''}{result.stderr or ''}"
    return result.returncode == 0 and "Logged in" in text


def _codex_prompt(panel: dict, dest: Path) -> str:
    """Non-explicit lock. The explicit panel prompt is not sent to Codex."""
    refs = "\n".join(f"- {path}" for path in panel["refs"])
    return (
        "Use the image generation tool exactly once. "
        "This stage is a non-explicit lock of pose, face, clothes, and body. "
        "Do not increase nudity or sexual contact. "
        "Do not depict exposed breasts, genitals, or intercourse.\n"
        "Do not edit any git repository. Do not create any other files. "
        "Do not call agy. Do not boot a GPU.\n"
        "The attached body board locks pose and expression. "
        "The attached makeup refs lock the adult faces, clothes, and body. "
        "Do not invent a new pose, face, costume, or body.\n"
        "Adult characters only. No child, no teen, no minor.\n"
        "Do not cover 许仙 / 顾承安's own foot. That foot is his and is not a defect.\n"
        "Keep one unbroken pearl-white scaled tail to a blunt connected tip, "
        "not a fish, not a snake head, no eye and no mouth at the tip. "
        "Bai herself has no human legs and no human feet.\n"
        f"Save the image only to {dest}.\n"
        f"Reference images:\n{refs}"
    )


def _codex_score_prompt(image: Path) -> str:
    """Stable prefix, then this frame and one short task sentence."""
    return f"{SCORE_PREFIX}待分图：{image}\n只打这一张。\n"


def _codex_exec(prompt: str, images: list[Path], cwd: Path) -> subprocess.CompletedProcess[str]:
    binary = _codex_binary()
    reason = codex_block_reason(binary, logged_in=_codex_logged_in())
    if reason:
        raise SystemExit(reason)
    cwd.mkdir(parents=True, exist_ok=True)
    cmd = [
        binary,
        "exec",
        "--skip-git-repo-check",
        "--ephemeral",
        "--color",
        "never",
        "-C",
        str(cwd),
        "-s",
        "workspace-write",
    ]
    for image in images:
        cmd.extend(["-i", str(image)])
    # `-i` takes one or more files, so a trailing prompt is eaten as another path.
    cmd.append("-")
    return subprocess.run(
        cmd,
        input=prompt,
        capture_output=True,
        text=True,
        timeout=900,
    )


def _run_codex_image(panel: dict, dest: Path) -> None:
    """One non-explicit Codex image. Does not reshoot and does not start Qwen."""
    for ref in panel["refs"]:
        if not ref.is_file():
            raise SystemExit(f"missing ref {ref}")
    result = _codex_exec(_codex_prompt(panel, dest), list(panel["refs"]), dest.parent)
    if result.returncode != 0 or not dest.is_file():
        detail = (result.stderr or result.stdout or "codex image missing").strip()
        raise SystemExit(detail[-800:])


def _grok_command(payload: str) -> list[str]:
    """grok-4.7 xhigh. Do not route this through .cursor/grok/run.sh."""
    return [
        _grok_binary(),
        "--output-format",
        "plain",
        "--always-approve",
        "--no-auto-update",
        "--disable-web-search",
        "--verbatim",
        "--max-turns",
        "6",
        "--cwd",
        "/tmp",
        "-m",
        GROK_MODEL,
        "--effort",
        GROK_EFFORT,
        "--prompt-json",
        payload,
    ]


def codex_result_unavailable(returncode: int, text: str) -> str | None:
    """Why this Codex scoring result cannot be kept. None means it can be parsed."""
    if returncode != 0:
        return "CLI 报错"
    raw = text or ""
    if "{" in raw:
        return None
    lowered = raw.lower()
    for mark in (
        "usage limit",
        "rate limit",
        "quota",
        "insufficient_quota",
        "too many requests",
        "额度",
    ):
        if mark in lowered or mark in raw:
            return "额度用完"
    return None


def _codex_score_once(image: Path, *, run=None, logged_in: bool | None = None) -> dict:
    """One Codex scoring attempt. Raises CodexUnavailable instead of falling through."""
    prompt = _codex_score_prompt(image)
    images = [ANCHOR, image]
    if run is None:
        binary = _codex_binary()
        if logged_in is None:
            logged_in = _codex_logged_in() if binary else False
        reason = codex_block_reason(binary, logged_in=bool(logged_in))
        if reason:
            raise CodexUnavailable(reason)
        try:
            result = _codex_exec(prompt, images, image.parent)
        except SystemExit as exc:
            raise CodexUnavailable(str(exc) or "CLI 报错") from exc
    else:
        if logged_in is False:
            raise CodexUnavailable("Codex CLI 未登录。失败退出。不执行登录，不开机，禁止改走 agy。")
        result = run(prompt, images)
    text = f"{result.stdout or ''}\n{result.stderr or ''}"
    why = codex_result_unavailable(result.returncode, text)
    if why:
        raise CodexUnavailable(why)
    try:
        item = parse_score(text)
    except SystemExit as exc:
        raise CodexUnavailable(str(exc) or "CLI 报错") from exc
    if "mean" not in item:
        raise CodexUnavailable("CLI 报错")
    return item


def _grok_vision_payload(prompt: str, images: list[Path]) -> str:
    """Same JPEG block shape as the edit call, for every attached still."""
    import base64
    import io

    from PIL import Image

    blocks: list[dict] = [{"type": "text", "text": prompt}]
    encoded = []
    for path in images:
        image = Image.open(path).convert("RGB")
        image.thumbnail((1024, 1024))
        encoded.append(image)
    payload = ""
    for quality in (70, 55, 40, 30):
        blocks = [{"type": "text", "text": prompt}]
        for image in encoded:
            buffer = io.BytesIO()
            image.save(buffer, format="JPEG", quality=quality)
            blocks.append(
                {
                    "type": "image",
                    "mimeType": "image/jpeg",
                    "data": base64.b64encode(buffer.getvalue()).decode("ascii"),
                }
            )
        payload = json.dumps(blocks)
        if len(payload) < 90000:
            break
    return payload


def _grok_exec_vision(prompt: str, images: list[Path]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        _grok_command(_grok_vision_payload(prompt, images)),
        capture_output=True,
        text=True,
        timeout=900,
    )


def _grok_score_once(image: Path, *, run=None) -> dict:
    """grok-4.7 xhigh scores with the Codex prefix. This does not generate an image."""
    prompt = _codex_score_prompt(image)
    images = [ANCHOR, image]
    result = run(prompt, images) if run is not None else _grok_exec_vision(prompt, images)
    text = f"{result.stdout or ''}\n{result.stderr or ''}"
    if result.returncode != 0:
        raise SystemExit("grok-4.7 xhigh 打分失败")
    item = parse_score(text)
    if "mean" not in item:
        raise SystemExit("grok-4.7 xhigh 打分失败")
    return item


def score_frame(image: Path, *, codex=None, grok=None) -> dict:
    """Score with Codex. On quota, login, or CLI failure, use grok-4.7 xhigh."""
    if not ANCHOR.is_file():
        raise SystemExit(f"missing anchor {ANCHOR}")
    if not RUBRIC.is_file():
        raise SystemExit(f"missing rubric {RUBRIC}")
    if not image.is_file():
        raise SystemExit(f"missing image {image}")
    try:
        item = (codex or _codex_score_once)(image)
    except CodexUnavailable:
        try:
            item = (grok or _grok_score_once)(image)
        except SystemExit as exc:
            raise SystemExit(
                "Codex 不可用，grok-4.7 xhigh 打分也失败。禁止 OpenCode，禁止 agy，不开机。"
            ) from exc
        item["scorer"] = SCORER_GROK
        return item
    item["scorer"] = SCORER_CODEX
    return item


def _score_with_codex(image: Path) -> dict:
    """Live scoring entry. Codex first, then the fixed grok-4.7 xhigh fallback."""
    return score_frame(image)


def report_node(node: str, panel_id: str = "-", image: Path | None = None, score: dict | None = None) -> None:
    """Short report for workflow-ready, start, pass 1, and pass 2."""
    if score is None:
        print(f"NODE {node} id={panel_id} path={image or '-'}", flush=True)
        return
    keys = (
        "identity",
        "distinction",
        "interaction",
        "aesthetics",
        "anatomy",
        "wardrobe",
        "motif",
        "photoreal",
    )
    eight = " ".join(f"{key}={score.get(key)}" for key in keys)
    print(
        f"NODE {node} id={panel_id} path={image} mean={score.get('mean')} "
        f"gates={score.get('gates')} scorer={score.get('scorer')} {eight}",
        flush=True,
    )


def _run_codex_stage(panel: dict, dest: Path) -> dict:
    """Non-explicit lock, then Codex score. Returns only a passing score."""
    attempt = 1
    while True:
        print(f"==== CODEX {panel['id']} try={attempt} likeness ====", flush=True)
        _run_codex_image(panel, dest)
        item = score_frame(dest)
        gates = " ".join(item.get("gates") or []) or "-"
        print(
            f"SCORE {panel['id']} stage=1 try={attempt} mean={item.get('mean')} gates={gates}",
            flush=True,
        )
        if local_explicit_allowed(item):
            print(f"KEEP {panel['id']} stage=1", flush=True)
            return item
        print(f"RESHOOT {panel['id']} stage=1 inside Codex", flush=True)
        attempt += 1


def _ensure_agy() -> None:
    raise SystemExit(agy_block_reason(None, logged_in=False))


def _ensure_codex() -> None:
    reason = codex_block_reason(_codex_binary(), logged_in=_codex_logged_in())
    if reason:
        raise SystemExit(reason)


def _run_agy_stage(panel: dict, dest: Path) -> None:
    """agy cannot produce the stage-1 lock."""
    del panel, dest
    raise SystemExit(agy_block_reason(None, logged_in=True))


def _run_qwen_stage(
    provider, panel: dict, likeness: Path, dest: Path, seed: int, lock_score: dict
) -> str:
    """Qwen runs only after the Codex lock passes 9.

    Pass 1 locks content at 448x600. Pass 2 keeps that seed and prompt and
    only upscales. A pass-2 miss lowers denoise and steps. It does not rewrite
    the prompt, change the seed, or reopen pass 1.
    """
    if not local_explicit_allowed(lock_score):
        raise SystemExit("local model blocked: Codex score has not passed")
    instruction = write_explicit_edit_with_grok(likeness)
    images = _qwen_edit_refs(panel, likeness)
    pass1 = dest.with_name(f"{panel['id']}.pass1.png")
    content_seed = seed
    attempt = 1
    while True:
        print(
            f"==== QWEN {panel['id']} pass1 try={attempt} seed={content_seed} ====",
            flush=True,
        )
        provider.call(
            "qwen-image-edit-2511",
            {
                "prompt": instruction,
                "negative": "",
                "images": images,
                "width": QWEN_PASS1_SIZE[0],
                "height": QWEN_PASS1_SIZE[1],
                "steps": QWEN_PASS1_STEPS,
                "seed": content_seed,
                "true_cfg_scale": 4.0,
            },
            pass1,
        )
        item = score_frame(pass1)
        print(
            f"SCORE {panel['id']} pass1 try={attempt} mean={item.get('mean')} "
            f"gates={item.get('gates')} accepted={pass1_accepted(item)}",
            flush=True,
        )
        report_node("pass1", panel["id"], pass1, item)
        if pass1_accepted(item):
            break
        attempt += 1
        content_seed += 1
    for index, (denoise, steps) in enumerate(zip(QWEN_PASS2_DENOISE, QWEN_PASS2_STEPS), start=1):
        print(
            f"==== QWEN {panel['id']} pass2 try={index} seed={content_seed} "
            f"denoise={denoise} steps={steps} ====",
            flush=True,
        )
        provider.call(
            "qwen-image-edit-2511",
            {
                "prompt": f"{instruction}{QWEN_PASS2_LOCK}",
                "negative": "",
                "images": [pass1],
                "width": QWEN_PASS2_SIZE[0],
                "height": QWEN_PASS2_SIZE[1],
                "steps": steps,
                "seed": content_seed,
                "denoise": denoise,
                "true_cfg_scale": 4.0,
            },
            dest,
        )
        item = score_frame(dest)
        action = stage2_action(item)
        print(
            f"SCORE {panel['id']} pass2 try={index} mean={item.get('mean')} "
            f"gates={item.get('gates')} action={action}",
            flush=True,
        )
        report_node("pass2", panel["id"], dest, item)
        if action == "keep":
            print(f"KEEP {panel['id']} pass2", flush=True)
            return "keep"
        failed = dest.with_name(f"{panel['id']}.pass2-below9-d{denoise}{dest.suffix}")
        dest.replace(failed)
    raise SystemExit(f"{panel['id']} 二采未过门。没有重写提示，没有换种子，没有重开一采。")


def f34_power_decision(phase: str, user_text: str = "") -> str:
    """Decide F34 power without calling the network.

    work: power on, unless this turn says 先别开.
    done, paused, idle, or wait: power off and keep the disk, unless this
    turn says 别关. Idle and waiting are not a reason to leave the GPU on.
    """
    text = user_text or ""
    if phase in F34_STOP_PHASES:
        if "别关" in text:
            return "skip_shutdown"
        return "power_off_keep_disk"
    if phase == "work":
        if "先别开" in text:
            return "skip_power_on"
        return "power_on"
    raise SystemExit(f"未知 F34 阶段：{phase}")


def _f34_guard(payload: dict, url: str) -> None:
    """F34 power_off/power_on only. Do not release the disk or touch G09."""
    uuid = str(payload.get("instance_uuid") or "")
    if uuid != F34_UUID or G09_UUID in uuid or G09_UUID in url:
        raise SystemExit("只许操作 F34。不要开、不要删 G09。")
    lowered = url.lower()
    if any(word in lowered for word in ("release", "delete", "destroy")):
        raise SystemExit("禁止释放或删除实例。关机必须留盘。")
    if set(payload) != {"instance_uuid"}:
        raise SystemExit("开关机请求只许带 instance_uuid，禁止释放数据盘。")


def _f34_website_token() -> str:
    env = os.environ.get("F34_WEBSITE_TOKEN", "").strip()
    if env:
        return env
    path = Path(os.environ.get("F34_WEBSITE_TOKEN_FILE", "/tmp/autodl_token_live.txt"))
    if path.is_file():
        return path.read_text(encoding="utf-8").strip()
    raise SystemExit("缺网站 token。F34 关机未执行。立刻手动关机留盘。")


def _f34_website_request(method: str, url: str, token: str, payload: dict | None) -> dict:
    """Website API. Authorization is the raw token. Does not print the token."""
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Authorization": token, "Content-Type": "application/json"},
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            raw = resp.read().decode()
    except urllib.error.HTTPError as exc:
        raise SystemExit(f"F34 网站请求失败：HTTP {exc.code}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit("F34 网站请求失败：URLError") from exc
    body = json.loads(raw)
    if not isinstance(body, dict):
        raise SystemExit("F34 网站返回不是对象。")
    return body


def _f34_default_post(url: str, payload: dict, token: str | None) -> dict:
    return _f34_website_request("POST", url, token or _f34_website_token(), payload)


def _f34_default_get(url: str, token: str | None) -> dict:
    return _f34_website_request("GET", url, token or _f34_website_token(), None)


def _assets_li(body: dict) -> int:
    data = body.get("data") if isinstance(body, dict) else None
    if isinstance(data, dict) and "assets" in data:
        return int(data["assets"])
    if isinstance(body, dict) and "assets" in body:
        return int(body["assets"])
    raise SystemExit("关机后没有读到钱包 assets。")


def _f34_disk_bytes(body: dict, uuid: str) -> int | None:
    data = body.get("data") if isinstance(body, dict) else None
    rows: list = []
    if isinstance(data, list):
        rows.extend(data)
    elif isinstance(data, dict):
        if data.get("uuid") or data.get("instance_uuid"):
            rows.append(data)
        nested = data.get("list") or data.get("instances") or []
        if isinstance(nested, list):
            rows.extend(nested)
    if isinstance(body, dict) and isinstance(body.get("list"), list):
        rows.extend(body["list"])
    for row in rows:
        if not isinstance(row, dict):
            continue
        row_id = str(row.get("uuid") or row.get("instance_uuid") or "")
        if row_id != uuid:
            continue
        size = row.get("expand_data_disk_size")
        if size is None:
            return None
        return int(size)
    return None


def f34_begin_work(user_text: str = "", *, post=None, token: str | None = None) -> dict:
    """Power F34 on only when this turn is real Qwen work and did not say 先别开."""
    decision = f34_power_decision("work", user_text)
    report = {
        "action": decision,
        "uuid": F34_UUID,
        "disk_bytes": F34_DISK_BYTES,
        "release": False,
    }
    if decision != "power_on":
        return report
    payload = {"instance_uuid": F34_UUID}
    _f34_guard(payload, F34_POWER_ON_URL)
    sender = post or _f34_default_post
    sender(F34_POWER_ON_URL, payload, token)
    return report


def f34_shutdown_hook(
    phase: str,
    user_text: str = "",
    *,
    post=None,
    get=None,
    list_post=None,
    token: str | None = None,
) -> dict:
    """Shut F34 down and keep the data disk. This hook never powers the machine on."""
    decision = f34_power_decision(phase, user_text)
    report = {
        "action": decision,
        "uuid": F34_UUID,
        "disk_bytes": F34_DISK_BYTES,
        "release": False,
        "assets_li": None,
    }
    if decision != "power_off_keep_disk":
        return report
    payload = {"instance_uuid": F34_UUID}
    _f34_guard(payload, F34_POWER_OFF_URL)
    sender = post or _f34_default_post
    sender(F34_POWER_OFF_URL, payload, token)
    if not (get is None and post is not None):
        reader = get or _f34_default_get
        report["assets_li"] = _assets_li(reader(F34_BALANCE_URL, token))
    if not (list_post is None and post is not None):
        lister = list_post or _f34_default_post
        listed = lister(F34_LIST_URL, {}, token)
        size = _f34_disk_bytes(listed, F34_UUID)
        if size is not None and size != F34_DISK_BYTES:
            raise SystemExit(f"数据盘不是 {F34_DISK_BYTES}。不要释放实例。")
        if size is not None:
            report["disk_bytes"] = size
    return report


def _f34_finish(phase: str, user_text: str) -> None:
    pending = sys.exc_info()[0]
    try:
        result = f34_shutdown_hook(phase, user_text)
    except SystemExit as exc:
        print(f"F34_SHUTDOWN_FAILED {exc}", flush=True)
        if pending is None:
            raise
        return
    except Exception as exc:
        print(f"F34_SHUTDOWN_FAILED {exc.__class__.__name__}", flush=True)
        if pending is None:
            raise SystemExit("F34 关机失败。立刻手动关机留盘。") from exc
        return
    if result["action"] == "power_off_keep_disk":
        print(
            f"F34_SHUTDOWN uuid={result['uuid']} disk={result['disk_bytes']} "
            f"assets_li={result.get('assets_li')}",
            flush=True,
        )
        return
    if result["action"] == "skip_shutdown":
        print("F34_SKIP_SHUTDOWN 别关", flush=True)


def main() -> None:
    # Two-stage entry. The in-flight white-snake six use the already copied
    # renderer and are not started from here.
    # Codex does not boot F34. Qwen work boots it. Done or paused shuts it down.
    turn = os.environ.get("F34_TURN", "")
    phase = "done"
    try:
        _ensure_codex()
        panels = _load_panels()
        only = require_subset(os.environ.get("EXPLICIT_ONLY", ""), {panel["id"] for panel in panels})
        os.environ.setdefault("HF_HUB_OFFLINE", "1")
        os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
        os.environ.setdefault("DIFFUSERS_OFFLINE", "1")
        os.environ.setdefault("HF_HUB_DISABLE_XET", "1")
        from comic_pipeline.config import Settings
        from comic_pipeline.providers.local import LocalProvider

        settings = Settings(
            image_provider="local",
            local_still_model="qwen-image-edit-2511",
            local_steps=40,
            local_offload="sequential",
            local_seed=1,
        )
        provider = LocalProvider(settings)
        out_root = Path(os.environ.get("EXPLICIT_OUT", "/root/autodl-tmp/out/explicit-8"))
        out_root.mkdir(parents=True, exist_ok=True)
        report_node("ready")
        booted = False
        for panel in panels:
            if panel["id"] not in only:
                continue
            report_node("start", panel["id"])
            for ref in panel["refs"]:
                if not ref.is_file():
                    raise SystemExit(f"missing ref {ref}")
            likeness = out_root / f"{panel['id']}.stage1.png"
            dest = out_root / f"{panel['id']}.png"
            seed = int(os.environ.get("EXPLICIT_SEED", "1"))
            lock_score = _run_codex_stage(panel, likeness)
            if not booted:
                boot = f34_begin_work(turn)
                if boot["action"] != "power_on":
                    raise SystemExit("用户当次说先别开。不开 F34。")
                booted = True
            _run_qwen_stage(provider, panel, likeness, dest, seed, lock_score)
        print("ALL_OK", flush=True)
    except BaseException:
        phase = "paused"
        raise
    finally:
        _f34_finish(phase, turn)


if __name__ == "__main__":
    main()
