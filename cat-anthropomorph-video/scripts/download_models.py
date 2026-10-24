#!/usr/bin/env python3
"""Stub: download weights listed in ../manifest.json by group.

Usage:
  python3 download_models.py --dry-run
  python3 download_models.py --group i2v
  python3 download_models.py --group looklock --group i2v

Does NOT boot GPUs or spend AutoDL balance. Requires network + optional HF_TOKEN.
Never reads paths under ai-realistic-comic/.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "manifest.json"


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


# Explicit group expansion only. looklock has no expansion: it must never be
# silently remapped to i2v (fail closed instead).
GROUP_EXPANSIONS = {"flf2v": {"i2v"}}


def collect_weights(manifest: dict, groups: list[str]) -> list[dict]:
    wanted = set(groups)
    for gname in sorted(wanted):
        if gname not in manifest["groups"]:
            raise SystemExit(f"unknown group: {gname}")
        wanted |= GROUP_EXPANSIONS.get(gname, set())
    if GROUP_EXPANSIONS.get("looklock"):
        raise SystemExit("refusing implicit looklock -> i2v remap")
    out: list[dict] = []
    seen = set()
    for gname in wanted:
        g = manifest["groups"].get(gname)
        if not g:
            raise SystemExit(f"unknown group: {gname}")
        for w in g.get("weights") or []:
            wid = w.get("id") or w.get("filename")
            if wid in seen:
                continue
            seen.add(wid)
            out.append({**w, "_group": gname})
    return out


def dest_path(models_root: Path, w: dict) -> Path:
    return models_root / w["dest"].lstrip("/") / w["filename"]


def download(url: str, dest: Path, dry_run: bool) -> None:
    if dry_run:
        print(f"[dry-run] GET {url} -> {dest}")
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 0:
        print(f"[skip] exists {dest}")
        return
    token = os.environ.get("HF_TOKEN")
    req = urllib.request.Request(url, headers={"User-Agent": "cat-anthro-restore/0.1"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    print(f"[get] {url}")
    with urllib.request.urlopen(req, timeout=600) as resp, open(dest, "wb") as f:
        while True:
            chunk = resp.read(1024 * 1024)
            if not chunk:
                break
            f.write(chunk)
    print(f"[ok] {dest} ({dest.stat().st_size} bytes)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", action="append", default=[], help="looklock | i2v | flf2v")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--models-root", default=os.environ.get("MODELS_ROOT", ""))
    ap.add_argument("--include-optional", action="store_true")
    args = ap.parse_args()
    groups = args.group or ["i2v"]
    manifest = load_manifest()
    models_root = Path(args.models_root or "models")
    forbidden_markers = {"ai-realistic-comic"}
    extra_forbidden = os.environ.get("FORBIDDEN_PREFIX", "").strip()
    if extra_forbidden:
        forbidden_markers.add(extra_forbidden)
    resolved_root = str(models_root.resolve())
    if any(marker in resolved_root for marker in forbidden_markers):
        print(f"refusing models_root under forbidden tree: {models_root}", file=sys.stderr)
        return 2
    weights = collect_weights(manifest, groups)
    for w in weights:
        if w.get("optional") and not args.include_optional:
            print(f"[skip-optional] {w.get('id')} (pass --include-optional)")
            continue
        url = w.get("url") or ""
        if not url.endswith(".safetensors"):
            print(f"[manual] {w.get('id')}: open page and pick file -> {url}")
            continue
        download(url, dest_path(models_root, w), args.dry_run)
    cap = os.environ.get("SPEND_CAP_CNY")
    if cap:
        print(f"[remind] SPEND_CAP_CNY={cap} (soft reminder only)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
