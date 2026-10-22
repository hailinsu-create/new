#!/usr/bin/env python3
"""Minimal ComfyUI HTTP helpers for workflow-final runners."""
from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


def get_json(url: str, *, timeout: int = 60, retries: int = 4) -> dict:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as response:
                return json.load(response)
        except (TimeoutError, urllib.error.URLError) as exc:
            last = exc
            time.sleep(2 + attempt * 2)
    raise SystemExit(f"GET_FAILED {url} {last}")


def post_json(url: str, payload: dict, *, timeout: int = 120) -> dict:
    data = json.dumps(payload).encode()
    request = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", "replace")
        raise SystemExit(f"PROMPT_REJECTED {exc.code} {body[:2000]}") from exc


def wait_up(host: str, *, timeout_sec: int = 300) -> None:
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        try:
            get_json(f"{host}/system_stats", timeout=10, retries=1)
            print(f"COMFY_UP {host}", flush=True)
            return
        except SystemExit:
            time.sleep(3)
    raise SystemExit(f"COMFY_TIMEOUT {host}")


def upload_image(host: str, path: Path, name: str | None = None) -> str:
    """Upload a local image into ComfyUI input/. Returns the server-side filename."""
    path = Path(path)
    if not path.is_file():
        raise SystemExit(f"MISSING_IMAGE {path}")
    fname = name or path.name
    boundary = "----wfFinalBoundary7MA4YWxkTrZu0gW"
    body = b""
    body += f"--{boundary}\r\n".encode()
    body += f'Content-Disposition: form-data; name="image"; filename="{fname}"\r\n'.encode()
    body += b"Content-Type: application/octet-stream\r\n\r\n"
    body += path.read_bytes()
    body += f"\r\n--{boundary}\r\n".encode()
    body += b'Content-Disposition: form-data; name="overwrite"\r\n\r\n'
    body += b"true\r\n"
    body += f"--{boundary}--\r\n".encode()
    req = urllib.request.Request(
        f"{host}/upload/image",
        data=body,
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        meta = json.load(resp)
    out_name = meta.get("name") or fname
    print(f"UPLOADED {out_name}", flush=True)
    return out_name


def wait_saved(host: str, prompt_id: str, node_id: str, dest: Path, tag: str) -> Path:
    deadline = time.time() + 1800
    while time.time() < deadline:
        history = get_json(f"{host}/history/{prompt_id}")
        item = history.get(prompt_id)
        if not item:
            time.sleep(4)
            continue
        status = item.get("status") or {}
        if status.get("status_str") == "error":
            raise SystemExit(f"RUN_FAILED {tag} {json.dumps(status)[:2000]}")
        images = ((item.get("outputs") or {}).get(node_id) or {}).get("images") or []
        if images and status.get("completed"):
            image = images[0]
            query = urllib.parse.urlencode(
                {
                    "filename": image["filename"],
                    "subfolder": image.get("subfolder") or "",
                    "type": image.get("type") or "output",
                }
            )
            dest.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(f"{host}/view?{query}", timeout=120) as response:
                dest.write_bytes(response.read())
            print(f"SAVED {tag} {dest} bytes={dest.stat().st_size}", flush=True)
            return dest
        time.sleep(4)
    raise SystemExit(f"RUN_TIMEOUT {tag}")


def queue_prompt(host: str, prompt: dict, client_id: str, node_id: str, dest: Path, tag: str) -> Path:
    queued = post_json(f"{host}/prompt", {"prompt": prompt, "client_id": client_id})
    prompt_id = queued.get("prompt_id")
    if not prompt_id:
        raise SystemExit(f"PROMPT_REJECTED {tag} {queued}")
    print(f"QUEUED {tag} {prompt_id}", flush=True)
    return wait_saved(host, prompt_id, node_id, dest, tag)


def inject_lora_model_only(wf: dict, lora_name: str, strength: float, node_id: str = "99") -> None:
    unet_id = next(
        (k for k, v in wf.items() if isinstance(v, dict) and v.get("class_type") == "UNETLoader"),
        None,
    )
    if unet_id is None:
        raise SystemExit("workflow has no UNETLoader")
    wf[node_id] = {
        "class_type": "LoraLoaderModelOnly",
        "inputs": {"lora_name": lora_name, "strength_model": strength, "model": [unet_id, 0]},
    }
    for k, v in wf.items():
        if k == node_id or not isinstance(v, dict):
            continue
        for iname, val in list(v.get("inputs", {}).items()):
            if isinstance(val, list) and len(val) == 2 and val[0] == unet_id and val[1] == 0:
                v["inputs"][iname] = [node_id, 0]


def find_node(wf: dict, class_type: str) -> str:
    for k, v in wf.items():
        if isinstance(v, dict) and v.get("class_type") == class_type:
            return k
    raise SystemExit(f"NODE_MISSING {class_type}")
