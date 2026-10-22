#!/usr/bin/env python3
"""Download manifest.json files with resume + size/sha256 verify.

HF: Authorization Bearer $HF_TOKEN (optional for public).
Civitai: resolve Location with Bearer $CIVITAI_API_TOKEN, then download CDN bare
(CDN rejects Authorization — see hybrid LoRA install lessons).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path


def log(msg: str) -> None:
    print(msg, flush=True)


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def ok_existing(dest: Path, expect_bytes: int, expect_sha: str | None) -> bool:
    if not dest.is_file():
        return False
    sz = dest.stat().st_size
    if sz != expect_bytes:
        log(f"REDOWNLOAD {dest.name} size={sz} != {expect_bytes}")
        return False
    if expect_sha:
        got = sha256_file(dest)
        if got != expect_sha:
            log(f"REDOWNLOAD {dest.name} sha256 mismatch")
            return False
    log(f"SKIP {dest.name} size={sz}")
    return True


def wget_c(url: str, dest: Path, headers: list[tuple[str, str]] | None = None) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_suffix(dest.suffix + ".part")
    cmd = ["wget", "-c", "--timeout=120", "--tries=8", "-O", str(part), url]
    for k, v in headers or []:
        cmd[1:1] = ["--header", f"{k}: {v}"]
    # put headers after wget: rebuild properly
    cmd = ["wget", "-c", "--timeout=120", "--tries=8"]
    for k, v in headers or []:
        cmd += ["--header", f"{k}: {v}"]
    cmd += ["-O", str(part), url]
    log(f"WGET {dest.name}")
    subprocess.check_call(cmd)
    part.replace(dest)


def curl_c(url: str, dest: Path, headers: list[tuple[str, str]] | None = None) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_suffix(dest.suffix + ".part")
    cmd = ["curl", "-fL", "--retry", "8", "--retry-delay", "2", "-C", "-", "-o", str(part), url]
    for k, v in headers or []:
        cmd[1:1] = ["-H", f"{k}: {v}"]
    cmd = ["curl", "-fL", "--retry", "8", "--retry-delay", "2", "-C", "-"]
    for k, v in headers or []:
        cmd += ["-H", f"{k}: {v}"]
    cmd += ["-o", str(part), url]
    log(f"CURL {dest.name}")
    subprocess.check_call(cmd)
    part.replace(dest)


def civitai_resolve_location(url: str, token: str) -> str:
    req = urllib.request.Request(url, method="GET", headers={"Authorization": f"Bearer {token}"})
    # don't follow redirects
    class NoRedirect(urllib.request.HTTPErrorProcessor):
        def http_response(self, request, response):  # noqa: ANN001
            return response

        https_response = http_response

    opener = urllib.request.build_opener(NoRedirect)
    with opener.open(req, timeout=60) as resp:
        loc = resp.headers.get("Location") or resp.headers.get("location")
        if not loc:
            raise RuntimeError(f"Civitai no Location for {url} status={resp.status}")
        return loc


def download_one(item: dict, comfy: Path, hf_token: str, civ_token: str) -> None:
    dest = comfy / item["dest"]
    expect = int(item["bytes"])
    sha = item.get("sha256")
    if ok_existing(dest, expect, sha):
        return
    source = item.get("source", "hf")
    url = item["url"]
    try:
        if source == "civitai":
            if not civ_token:
                raise SystemExit("CIVITAI_API_TOKEN required for Civitai downloads")
            loc = civitai_resolve_location(url, civ_token)
            log(f"CIVITAI_LOC {dest.name} len={len(loc)}")
            try:
                wget_c(loc, dest)  # bare CDN
            except subprocess.CalledProcessError:
                curl_c(loc, dest)
        else:
            headers = []
            if hf_token:
                headers.append(("Authorization", f"Bearer {hf_token}"))
            try:
                wget_c(url, dest, headers)
            except subprocess.CalledProcessError:
                if item.get("fallback_url"):
                    log(f"FALLBACK {dest.name}")
                    wget_c(item["fallback_url"], dest, headers)
                else:
                    curl_c(url, dest, headers)
    except Exception:
        if item.get("fallback_url") and source == "hf":
            log(f"FALLBACK {dest.name}")
            headers = []
            if hf_token:
                headers.append(("Authorization", f"Bearer {hf_token}"))
            wget_c(item["fallback_url"], dest, headers)
        else:
            raise
    if dest.stat().st_size != expect:
        raise SystemExit(f"BAD_SIZE {dest.name} {dest.stat().st_size} != {expect}")
    if sha:
        got = sha256_file(dest)
        if got != sha:
            raise SystemExit(f"BAD_SHA {dest.name} {got} != {sha}")
    log(f"OK {dest.name}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--comfy", required=True)
    ap.add_argument("--groups", default="all", help="comma groups or all")
    args = ap.parse_args()
    man = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    comfy = Path(args.comfy)
    groups = None if args.groups == "all" else set(args.groups.split(","))
    hf = os.environ.get("HF_TOKEN", "").strip()
    civ = os.environ.get("CIVITAI_API_TOKEN", "").strip()
    os.environ.setdefault("HF_ENDPOINT", man.get("hf_endpoint_default", "https://hf-mirror.com"))
    for item in man["files"]:
        if groups and item.get("group") not in groups:
            continue
        download_one(item, comfy, hf, civ)
    log("DOWNLOAD_ALL_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
