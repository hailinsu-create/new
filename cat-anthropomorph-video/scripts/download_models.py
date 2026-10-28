#!/usr/bin/env python3
"""Download/verify weights listed in ../manifest.json by group.

Integrity policy: SHA-256 is mandatory by default. Size-only skips are
forbidden. Existing files are re-hashed before being skipped.

Usage:
  python3 download_models.py --dry-run
  python3 download_models.py --validate-manifest
  python3 download_models.py --checksum-only --group i2v
  python3 download_models.py --group looklock --group i2v
  python3 download_models.py --no-require-sha256   # explicit downgrade

Does NOT boot GPUs or spend AutoDL balance. Requires network + optional HF_TOKEN.
Never reads paths under ai-realistic-comic/.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "manifest.json"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
PLACEHOLDER = "REQUIRED_FILL_BEFORE_APPLY"


def load_manifest(path: Path = MANIFEST) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def is_sha256(value: object) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.match(value))


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


def sha256_file(path: Path, chunk_size: int = 8 * 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while True:
            chunk = handle.read(chunk_size)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def integrity_problems(weights: list[dict]) -> list[str]:
    problems = []
    for w in weights:
        name = w.get("filename") or w.get("id")
        value = w.get("sha256")
        if not is_sha256(value):
            detail = "missing" if value in (None, "", PLACEHOLDER) else f"invalid ({value!r})"
            problems.append(f"{name}: sha256 {detail}")
    return problems


def verify_existing(dest: Path, expected: str) -> tuple[bool, str]:
    if not dest.exists():
        return False, "missing"
    if dest.stat().st_size == 0:
        return False, "empty file"
    actual = sha256_file(dest)
    if actual == expected:
        return True, actual
    return False, f"sha256 mismatch: actual={actual} expected={expected}"


def download(url: str, dest: Path, expected: str | None, dry_run: bool) -> str:
    if dry_run:
        print(f"[dry-run] GET {url} -> {dest} sha256={expected or 'MISSING (downgraded)'}")
        return "ok"
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        if expected is None:
            print(f"[WARN] exists but cannot verify sha256 (downgraded): {dest}", file=sys.stderr)
            return "ok"
        ok, detail = verify_existing(dest, expected)
        if ok:
            print(f"[skip] exists + sha256 verified {dest}")
            return "ok"
        print(f"[FAIL] existing file is not usable ({detail}): {dest}", file=sys.stderr)
        return "bad_existing"

    tmp = dest.with_name(dest.name + ".part")
    token = os.environ.get("HF_TOKEN")
    req = urllib.request.Request(url, headers={"User-Agent": "cat-anthro-restore/0.2"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    print(f"[get] {url}")
    digest = hashlib.sha256()
    try:
        with urllib.request.urlopen(req, timeout=600) as resp, tmp.open("wb") as handle:
            while True:
                chunk = resp.read(1024 * 1024)
                if not chunk:
                    break
                digest.update(chunk)
                handle.write(chunk)
    except Exception as exc:  # network / disk errors
        if tmp.exists():
            tmp.unlink()
        print(f"[FAIL] download error for {dest}: {exc}", file=sys.stderr)
        return "download_error"

    actual = digest.hexdigest()
    if expected is not None and actual != expected:
        tmp.unlink()
        print(
            f"[FAIL] sha256 mismatch for {dest}: actual={actual} expected={expected}; "
            "partial file removed",
            file=sys.stderr,
        )
        return "mismatch"
    if expected is None:
        print(f"[WARN] downloaded without sha256 verification (downgraded): {dest}", file=sys.stderr)
    tmp.replace(dest)
    suffix = "sha256 verified" if expected is not None else "unverified (downgraded)"
    print(f"[ok] {dest} ({dest.stat().st_size} bytes) {suffix}")
    return "ok"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--group", action="append", default=[], help="looklock | i2v | flf2v")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--models-root", default=os.environ.get("MODELS_ROOT", ""))
    ap.add_argument("--include-optional", action="store_true")
    ap.add_argument("--manifest", type=Path, default=MANIFEST, help="manifest path (default: manifest.json)")
    ap.add_argument(
        "--require-sha256",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="require every selected weight to carry a 64-hex sha256 (default: on)",
    )
    ap.add_argument("--validate-manifest", action="store_true", help="only validate sha256 fields")
    ap.add_argument("--checksum-only", action="store_true", help="verify existing files, no download")
    args = ap.parse_args()

    groups = args.group or ["i2v"]
    manifest = load_manifest(args.manifest)
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
    if args.validate_manifest:
        weights_selected = weights
    elif args.include_optional:
        weights_selected = weights
    else:
        weights_selected = [w for w in weights if not w.get("optional")]

    problems = integrity_problems(weights_selected)
    if problems:
        prefix = "[WARN]" if args.dry_run else "[REFUSE]"
        for item in problems:
            print(f"{prefix} sha256 required: {item}", file=sys.stderr)
        if args.require_sha256 and (not args.dry_run or args.validate_manifest):
            print(
                "[REFUSE] fill sha256 from HF API lfs.oid before applying; "
                "size-only downloads are forbidden",
                file=sys.stderr,
            )
            return 2
        if not args.require_sha256:
            print(
                "[WARN] --no-require-sha256 explicitly downgrades integrity checks",
                file=sys.stderr,
            )

    if args.validate_manifest:
        print(
            f"[ok] sha256 present for {len(weights_selected)} selected weight(s) "
            f"({args.manifest})"
        )
        return 0

    if args.checksum_only:
        failed = 0
        for w in weights_selected:
            if not is_sha256(w.get("sha256")):
                failed += 1
                print(f"[FAIL] {w.get('id')}: no valid sha256; cannot verify", file=sys.stderr)
                continue
            dest = dest_path(models_root, w)
            ok, detail = verify_existing(dest, w["sha256"])
            if ok:
                print(f"[ok] {dest} sha256 verified")
            else:
                failed += 1
                print(f"[FAIL] {dest}: {detail}", file=sys.stderr)
        return 2 if failed else 0

    failures = 0
    for w in weights:
        if w.get("optional") and not args.include_optional:
            print(f"[skip-optional] {w.get('id')} (pass --include-optional)")
            continue
        url = w.get("url") or ""
        if not url.endswith(".safetensors"):
            print(f"[manual] {w.get('id')}: open page and pick file -> {url}")
            continue
        expected = w.get("sha256")
        if not is_sha256(expected):
            if args.require_sha256:
                if args.dry_run:
                    print(
                        f"[WARN] {w.get('id')}: sha256 missing; dry-run only, apply would refuse",
                        file=sys.stderr,
                    )
                    print(f"[dry-run] GET {url} -> {dest_path(models_root, w)} sha256=MISSING")
                    continue
                print(f"[skip] {w.get('id')}: no valid sha256; refusing size-only download", file=sys.stderr)
                failures += 1
                continue
            expected = None
        result = download(url, dest_path(models_root, w), expected, args.dry_run)
        if result != "ok":
            failures += 1

    cap = os.environ.get("SPEND_CAP_CNY")
    if cap:
        print(f"[remind] SPEND_CAP_CNY={cap} (soft reminder only)")
    if failures:
        print(f"[FAIL] {failures} weight(s) failed integrity/download checks", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
