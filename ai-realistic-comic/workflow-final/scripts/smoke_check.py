#!/usr/bin/env python3
"""Post-restore self-check: pins, manifest files, optional ComfyUI first image."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import comfy_api as api  # noqa: E402


def log(msg: str) -> None:
    print(msg, flush=True)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def check_pins(comfy: Path) -> None:
    pins = json.loads((ROOT / "pins.json").read_text(encoding="utf-8"))
    expect = pins["comfyui"]["commit"]
    got = subprocess.check_output(["git", "-C", str(comfy), "rev-parse", "HEAD"], text=True).strip()
    if got != expect:
        raise SystemExit(f"COMFY_PIN_MISMATCH got={got} expect={expect}")
    log(f"OK comfyui@{got[:12]}")
    for name, meta in pins.get("custom_nodes", {}).items():
        node = comfy / "custom_nodes" / name
        if not node.is_dir():
            raise SystemExit(f"NODE_MISSING {name}")
        ngot = subprocess.check_output(["git", "-C", str(node), "rev-parse", "HEAD"], text=True).strip()
        if ngot != meta["commit"]:
            raise SystemExit(f"NODE_PIN_MISMATCH {name} got={ngot} expect={meta['commit']}")
        log(f"OK node {name}@{ngot[:12]}")


def check_manifest(comfy: Path) -> None:
    man = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
    bad = 0
    for item in man["files"]:
        dest = comfy / item["dest"]
        if not dest.is_file():
            log(f"MISS {item['id']} {item['dest']}")
            bad += 1
            continue
        sz = dest.stat().st_size
        if sz != int(item["bytes"]):
            log(f"BAD_SIZE {item['id']} {sz} != {item['bytes']}")
            bad += 1
            continue
        sha = item.get("sha256")
        if sha:
            got = sha256_file(dest)
            if got != sha:
                log(f"BAD_SHA {item['id']} {got} != {sha}")
                bad += 1
                continue
            log(f"OK {item['id']} sha256")
        else:
            log(f"OK {item['id']} size={sz}")
    if bad:
        raise SystemExit(f"MANIFEST_FAIL bad={bad}")
    log("MANIFEST_OK")


def check_assets() -> None:
    refs = ROOT / "assets" / "refs" / "lin_qipao_nine_tail.png"
    if not refs.is_file():
        raise SystemExit(f"MISS_REF {refs}")
    poses = list((ROOT / "assets" / "poses" / "local_user_poses").rglob("*.json"))
    if len(poses) < 50:
        raise SystemExit(f"POSE_COUNT_LOW {len(poses)}")
    log(f"OK assets refs+poses n={len(poses)}")


def ensure_comfy_running(comfy: Path, host: str, py: str) -> subprocess.Popen | None:
    try:
        api.get_json(f"{host}/system_stats", timeout=5, retries=1)
        log(f"COMFY_ALREADY_UP {host}")
        return None
    except SystemExit:
        pass
    log_path = Path(os.environ.get("SMOKE_COMFY_LOG", "/tmp/workflow-final-comfy.log"))
    log_path.parent.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.setdefault("HF_ENDPOINT", "https://hf-mirror.com")
    proc = subprocess.Popen(
        [py, "main.py", "--listen", "127.0.0.1", "--port", "8188", "--disable-auto-launch"],
        cwd=str(comfy),
        env=env,
        stdout=log_path.open("a"),
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    log(f"COMFY_STARTED pid={proc.pid} log={log_path}")
    api.wait_up(host, timeout_sec=420)
    return proc


def run_first_image(host: str, out: Path) -> Path:
    wf = json.loads((ROOT / "workflows" / "r4_qwen_edit_2511.api.json").read_text(encoding="utf-8"))
    prompt_txt = (ROOT / "prompts" / "r4_torn_edge.txt").read_text(encoding="utf-8").strip()
    img_name = api.upload_image(host, ROOT / "assets" / "refs" / "lin_qipao_nine_tail.png")
    load_id = api.find_node(wf, "LoadImage")
    save_id = api.find_node(wf, "SaveImage")
    pos_id = "11"
    wf[load_id]["inputs"]["image"] = img_name
    wf[pos_id]["inputs"]["prompt"] = prompt_txt
    wf[save_id]["inputs"]["filename_prefix"] = "wf-final-smoke"
    return api.queue_prompt(host, wf, "wf-final-smoke", save_id, out, "smoke-r4-torn")


def main() -> int:
    ap = argparse.ArgumentParser(description="workflow-final smoke / self-check")
    ap.add_argument("--comfy", default=os.environ.get("COMFY_ROOT", "/root/autodl-tmp/comfyui"))
    ap.add_argument("--host", default=os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188"))
    ap.add_argument("--py", default=os.environ.get("COMFY_PY", "/root/miniconda3/bin/python"))
    ap.add_argument("--files-only", action="store_true", help="skip starting ComfyUI / first image")
    ap.add_argument("--no-image", action="store_true", help="check Comfy up only, no prompt")
    ap.add_argument(
        "--out",
        type=Path,
        default=Path(os.environ.get("SMOKE_OUT", "/root/autodl-tmp/workflow-final-smoke.png")),
    )
    args = ap.parse_args()
    comfy = Path(args.comfy)
    if not (comfy / "main.py").is_file():
        raise SystemExit(f"COMFY_MISSING {comfy}")
    check_pins(comfy)
    check_manifest(comfy)
    check_assets()
    if args.files_only:
        log("SMOKE_FILES_ONLY_OK")
        return 0
    ensure_comfy_running(comfy, args.host, args.py)
    if args.no_image:
        log("SMOKE_COMFY_OK")
        return 0
    dest = run_first_image(args.host, args.out)
    if dest.stat().st_size < 10_000:
        raise SystemExit(f"SMOKE_IMAGE_TOO_SMALL {dest.stat().st_size}")
    log(f"SMOKE_OK first_image={dest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
