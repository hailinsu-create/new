"""New two-stage still runner. Not the live white-snake workflow.

The running six use autodl/run_explicit8.py. This copy is unused until that
job finishes. Stage 1 is Codex CLI likeness. Stage 2 is local Qwen exposure only.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPT_FILES = (
    ROOT / "library" / "stills" / "explicit-8" / "prompts.md",
    ROOT / "library" / "stills" / "myth-poses" / "prompts.md",
)
ANCHOR = ROOT / "library" / "stills" / "explicit-8" / "anchor-10.jpg"
RUBRIC = ROOT / "docs" / "still-score-two-stage.md"
VISION_MODEL = "opencode-go/deepseek-v4-flash-vision-exp"
KEEP_MEAN = 9.0

SCORE_PROMPT = """按 docs/still-score-two-stage.md 给第二张图打分。第一张图是满分基准 anchor-10，八项固定 10。地上那只脚是许仙（顾承安）的，不扣。和基准一样的圆钝连体尾尖不算 H2。白蛇自己的人腿或人脚才算 H3；人身格的人腿是对的，雨桥没有蛇尾。伊莲不许尖耳或绿眼。阿德里安保留尖耳，不拿武器。别人长尖耳算 H4。
只输出一个 JSON 对象，不要改文件：
{"scene":"六个字内","gates":[],"face_drift":false,"identity":0,"distinction":0,"interaction":0,"aesthetics":0,"anatomy":0,"wardrobe":0,"motif":0,"photoreal":0,"mean":0,"note":"一句"}
gates 只填失败的门，例如 ["H2"]。没有失败就是 []。face_drift 只有脸不像定妆时才是 true。mean 是八项等权均分。"""


def codex_block_reason(binary: str | None, *, logged_in: bool) -> str | None:
    """Stop before stage 1 when Codex CLI is missing or not already logged in.

    This does not run `codex login` and it does not start a GPU.
    A missing binary does not open another image generator.
    """
    if not binary:
        return (
            "CODEX_CLI_MISSING 第一段只走 Codex CLI。"
            "本机没有 codex。禁止改走其他图像入口。不要代填账号，不要开机。"
        )
    if not logged_in:
        return (
            "CODEX_CLI_LOGGED_OUT 第一段只走 Codex CLI。"
            "codex login status 未登录。禁止改走其他图像入口。不要代填账号，不要开机。"
        )
    return None


def stage2_action(item: dict) -> str:
    """keep, reshoot the explicit edit only, or go back to stage 1."""
    if item.get("face_drift"):
        return "back"
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


def parse_score(text: str) -> dict:
    start = text.find("{")
    end = text.rfind("}")
    if start < 0 or end <= start:
        raise SystemExit("score json missing")
    data = json.loads(text[start : end + 1])
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
    if not ANCHOR.is_file():
        raise SystemExit(f"missing anchor {ANCHOR}")
    if not RUBRIC.is_file():
        raise SystemExit(f"missing rubric {RUBRIC}")
    if shutil.which("opencode") is None:
        raise SystemExit("opencode is required for still-score; do not keep an unscored frame")
    cmd = [
        "opencode",
        "run",
        "--pure",
        "--auto",
        "-m",
        VISION_MODEL,
        "--variant",
        "max",
        "--dir",
        "/tmp",
        SCORE_PROMPT,
        "-f",
        str(ANCHOR),
        "-f",
        str(image),
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    if result.returncode != 0:
        raise SystemExit(f"vision score failed: {result.stderr[-500:]}")
    return parse_score(result.stdout)


def _render_until_kept(provider, panel: dict, dest: Path, seed: int) -> None:
    attempt = 1
    while True:
        print(
            f"==== STILL {panel['id']} try={attempt} seed={seed} {panel['width']}x{panel['height']} refs={len(panel['refs'])} ====",
            flush=True,
        )
        provider.call(
            "qwen-image-edit-2511",
            {
                "prompt": f"{panel['prompt']} Avoid: {panel['negative']}.",
                "negative": panel["negative"],
                "images": panel["refs"],
                "width": panel["width"],
                "height": panel["height"],
                "steps": 40,
                "seed": seed,
                "true_cfg_scale": float(os.environ.get("EXPLICIT_CFG", "4")),
            },
            dest,
        )
        print(f"wrote {dest} {dest.stat().st_size}", flush=True)
        item = score_still(dest)
        gates = " ".join(item.get("gates") or []) or "-"
        print(
            f"SCORE {panel['id']} try={attempt} mean={item.get('mean')} gates={gates} note={item.get('note', '')}",
            flush=True,
        )
        if accepted(item):
            print(f"KEEP {panel['id']} mean={item.get('mean')}", flush=True)
            return
        failed = dest.with_name(f"{panel['id']}.below9-try{attempt}{dest.suffix}")
        dest.replace(failed)
        print(f"RESHOOT {panel['id']} below 9 or hard gate, next seed={seed + 1}", flush=True)
        attempt += 1
        seed += 1


def _codex_prompt(panel: dict, dest: Path) -> str:
    refs = "\n".join(f"- {path}" for path in panel["refs"])
    return (
        "Use the image generation tool exactly once. "
        "This stage is a non-explicit lock of pose, face, clothes, and body. "
        "Do not increase nudity or sexual contact. "
        "Match the faces and costumes on the makeup refs, and the pose and "
        "expression on the body board. Snake-tail rules still apply: one "
        "pearl-white scaled tail to a blunt connected tip, not a fish, not a "
        "snake head, and Bai herself has no human legs or feet. "
        "Gu Cheng'an's own foot is allowed. "
        "Do not edit any git repository. Do not boot a GPU.\n"
        f"Save the image only to {dest}.\n"
        f"Reference images:\n{refs}"
    )


def _stage2_edit_prompt(panel: dict) -> str:
    return (
        f"{panel['prompt']}\n"
        "Edit only to increase exposure and body contact. "
        "Do not change the faces, the pose, the expression, or the snake-tail rules. "
        f"Avoid: {panel['negative']}."
    )


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


def _ensure_codex() -> str:
    binary = _codex_binary()
    reason = codex_block_reason(binary, logged_in=_codex_logged_in())
    if reason:
        raise SystemExit(reason)
    return binary


def _codex_exec(prompt: str, images: list[Path], cwd: Path) -> subprocess.CompletedProcess[str]:
    binary = _ensure_codex()
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
    cmd.append("-")
    return subprocess.run(
        cmd,
        input=prompt,
        capture_output=True,
        text=True,
        timeout=900,
    )


def _run_codex_stage(panel: dict, dest: Path) -> None:
    """Likeness passes stay inside Codex CLI. A missing binary exits."""
    attempt = 1
    while True:
        print(f"==== CODEX {panel['id']} try={attempt} likeness ====", flush=True)
        if dest.is_file():
            dest.unlink()
        result = _codex_exec(_codex_prompt(panel, dest), list(panel["refs"]), dest.parent)
        if result.returncode != 0 or not dest.is_file():
            detail = (result.stderr or result.stdout or "codex image missing").strip()
            raise SystemExit(f"CODEX_CLI_FAILED {panel['id']} {detail[-500:]}")
        item = score_still(dest)
        gates = " ".join(item.get("gates") or []) or "-"
        print(
            f"SCORE {panel['id']} stage=1 try={attempt} mean={item.get('mean')} gates={gates}",
            flush=True,
        )
        if accepted(item):
            print(f"KEEP {panel['id']} stage=1", flush=True)
            return
        print(f"RESHOOT {panel['id']} stage=1 inside Codex CLI", flush=True)
        attempt += 1


def _run_qwen_stage(provider, panel: dict, likeness: Path, dest: Path, seed: int) -> str:
    """Return keep, or back when the face drifted. Under 9 reshoots this stage only."""
    attempt = 1
    while True:
        print(
            f"==== QWEN {panel['id']} stage=2 try={attempt} seed={seed} ====",
            flush=True,
        )
        provider.call(
            "qwen-image-edit-2511",
            {
                "prompt": _stage2_edit_prompt(panel),
                "negative": panel["negative"],
                "images": [likeness, *panel["refs"]],
                "width": panel["width"],
                "height": panel["height"],
                "steps": 40,
                "seed": seed,
                "true_cfg_scale": 4.0,
            },
            dest,
        )
        item = score_still(dest)
        action = stage2_action(item)
        gates = " ".join(item.get("gates") or []) or "-"
        print(
            f"SCORE {panel['id']} stage=2 try={attempt} mean={item.get('mean')} gates={gates} action={action}",
            flush=True,
        )
        if action == "keep":
            print(f"KEEP {panel['id']} stage=2", flush=True)
            return "keep"
        if action == "back":
            print(f"FACE {panel['id']} back to stage 1", flush=True)
            return "back"
        failed = dest.with_name(f"{panel['id']}.stage2-below9-try{attempt}{dest.suffix}")
        dest.replace(failed)
        print(f"RESHOOT {panel['id']} stage=2 only, next seed={seed + 1}", flush=True)
        attempt += 1
        seed += 1


def main() -> None:
    # Two-stage entry. The in-flight white-snake six use the already copied
    # renderer and are not started from here.
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
    for panel in panels:
        if panel["id"] not in only:
            continue
        for ref in panel["refs"]:
            if not ref.is_file():
                raise SystemExit(f"missing ref {ref}")
        likeness = out_root / f"{panel['id']}.stage1.png"
        dest = out_root / f"{panel['id']}.png"
        seed = int(os.environ.get("EXPLICIT_SEED", "1"))
        while True:
            _run_codex_stage(panel, likeness)
            if _run_qwen_stage(provider, panel, likeness, dest, seed) == "keep":
                break
            print(f"FACE {panel['id']} stage 2 drifted, restart stage 1", flush=True)
    print("ALL_OK", flush=True)


if __name__ == "__main__":
    main()
