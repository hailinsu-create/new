#!/usr/bin/env python3
"""Route C prep: install pose library + VNCCS UI workflow, refresh, list poses.

Full VNCCS Pose Studio needs the ComfyUI frontend (live pose capture). This script
places assets and refreshes the library; open the workflow in the UI to queue.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import comfy_api as api  # noqa: E402


def install_poses(comfy: Path) -> Path:
    dest = comfy / "custom_nodes" / "ComfyUI_VNCCS_Utils" / "PoseLibrary" / "local_user_poses"
    src = ROOT / "assets" / "poses" / "local_user_poses"
    if not src.is_dir():
        raise SystemExit(f"MISS_POSES {src}")
    dest.mkdir(parents=True, exist_ok=True)
    # copy tree (json only already vendored)
    for path in src.rglob("*"):
        rel = path.relative_to(src)
        target = dest / rel
        if path.is_dir():
            target.mkdir(parents=True, exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
    n = len(list(dest.rglob("*.json")))
    print(f"POSES_INSTALLED {dest} n={n}", flush=True)
    return dest


def install_workflow(comfy: Path) -> Path:
    wf_src = ROOT / "workflows" / "VNCCS_PoseStudio_QI2.1.json"
    dest_dir = comfy / "user" / "default" / "workflows"
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / "VNCCS_PoseStudio_QI2.1.json"
    shutil.copy2(wf_src, dest)
    # also drop a copy next to input for easy Load
    shutil.copy2(wf_src, comfy / "user" / "default" / "VNCCS_PoseStudio_QI2.1.json")
    print(f"WF_INSTALLED {dest}", flush=True)
    return dest


def refresh_library(host: str) -> None:
    req = urllib.request.Request(
        f"{host}/vnccs/pose_library/repositories/refresh",
        data=b"{}",
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = resp.read().decode("utf-8", "replace")
        print(f"POSE_REFRESH {body[:300]}", flush=True)
    except Exception as exc:  # noqa: BLE001
        print(f"POSE_REFRESH_SKIP {exc}", flush=True)


def list_poses(host: str) -> int:
    try:
        data = api.get_json(f"{host}/vnccs/pose_library/list", timeout=60, retries=2)
    except SystemExit as exc:
        print(f"POSE_LIST_FAIL {exc}", flush=True)
        return 0
    items = data if isinstance(data, list) else data.get("poses") or data.get("items") or []
    print(f"POSE_LIST n={len(items)}", flush=True)
    for item in items[:12]:
        if isinstance(item, dict):
            print(f"  - {item.get('name') or item.get('id') or item}", flush=True)
        else:
            print(f"  - {item}", flush=True)
    return len(items)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--comfy", default=os.environ.get("COMFY_ROOT", "/root/autodl-tmp/comfyui"))
    ap.add_argument("--host", default=os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188"))
    ap.add_argument("--char", type=Path, default=ROOT / "assets" / "refs" / "lin_qipao_nine_tail.png")
    ap.add_argument("--prepare-only", action="store_true", help="install assets; do not require Comfy up")
    args = ap.parse_args()
    comfy = Path(args.comfy)
    if not (comfy / "custom_nodes" / "ComfyUI_VNCCS_Utils").is_dir():
        raise SystemExit("VNCCS node missing; run restore.sh first")
    install_poses(comfy)
    install_workflow(comfy)
    # stage character into input/
    input_dir = comfy / "input"
    input_dir.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.char, input_dir / args.char.name)
    print(f"CHAR_STAGED {input_dir / args.char.name}", flush=True)
    if args.prepare_only:
        print(
            "ROUTE_C_PREPARED open ComfyUI → Load workflow "
            "VNCCS_PoseStudio_QI2.1.json → pick pose → Queue",
            flush=True,
        )
        return 0
    api.wait_up(args.host, timeout_sec=60)
    try:
        api.upload_image(args.host, args.char)
    except SystemExit as exc:
        print(f"UPLOAD_SKIP {exc}", flush=True)
    refresh_library(args.host)
    n = list_poses(args.host)
    print(
        json.dumps(
            {
                "status": "prepared",
                "poses_listed": n,
                "workflow": "VNCCS_PoseStudio_QI2.1.json",
                "char": args.char.name,
                "next": "Open UI, load workflow, select pose, Queue Prompt",
            },
            ensure_ascii=False,
        ),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
