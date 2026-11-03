#!/usr/bin/env python3
"""Gate: looklock still short side must be >= min (default 1024). Offline; no GPU.

Exit 0 on PASS, 1 on FAIL / decode error.
Uses ffprobe when available; falls back to PNG/JPEG header parse for PNG IHDR / JPEG SOF.
"""
from __future__ import annotations

import argparse
import json
import shutil
import struct
import subprocess
import sys
from pathlib import Path


def _ffprobe_size(path: Path) -> tuple[int, int] | None:
    if not shutil.which("ffprobe"):
        return None
    cmd = [
        "ffprobe", "-v", "error", "-select_streams", "v:0",
        "-show_entries", "stream=width,height", "-of", "json", str(path),
    ]
    r = subprocess.run(cmd, capture_output=True, check=False, text=True)
    if r.returncode != 0:
        return None
    data = json.loads(r.stdout or "{}")
    streams = data.get("streams") or []
    if not streams:
        return None
    w, h = int(streams[0]["width"]), int(streams[0]["height"])
    return w, h


def _png_size(path: Path) -> tuple[int, int] | None:
    raw = path.read_bytes()[:24]
    if raw[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    w, h = struct.unpack(">II", raw[16:24])
    return int(w), int(h)


def _jpeg_size(path: Path) -> tuple[int, int] | None:
    data = path.read_bytes()
    if data[:2] != b"\xff\xd8":
        return None
    i = 2
    while i < len(data) - 8:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xC0, 0xC1, 0xC2):
            h, w = struct.unpack(">HH", data[i + 5 : i + 9])
            return int(w), int(h)
        if marker == 0xD9:
            break
        if marker in (0xD8, 0x01) or (0xD0 <= marker <= 0xD7):
            i += 2
            continue
        seglen = struct.unpack(">H", data[i + 2 : i + 4])[0]
        i += 2 + seglen
    return None


def image_size(path: Path) -> tuple[int, int]:
    for fn in (_ffprobe_size, _png_size, _jpeg_size):
        got = fn(path)
        if got:
            return got
    raise RuntimeError(f"cannot read image size: {path}")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Require looklock short side >= N (default 1024)")
    ap.add_argument("input", type=Path)
    ap.add_argument("--min-short-side", type=int, default=1024)
    ap.add_argument("--require-multiple-of", type=int, default=16)
    args = ap.parse_args(argv)
    if not args.input.is_file():
        print(f"[looklock_size_gate][FAIL] missing: {args.input}", file=sys.stderr)
        return 1
    try:
        w, h = image_size(args.input)
    except Exception as e:
        print(f"[looklock_size_gate][FAIL] {e}", file=sys.stderr)
        return 1
    short = min(w, h)
    ok = short >= args.min_short_side
    mult_ok = (w % args.require_multiple_of == 0 and h % args.require_multiple_of == 0)
    status = "PASS" if ok else "FAIL"
    print(f"[looklock_size_gate][{status}] {args.input} {w}x{h} short={short} min={args.min_short_side}")
    if not mult_ok:
        print(
            f"[looklock_size_gate][WARN] sides not multiple of {args.require_multiple_of} (community I2V tip)",
            file=sys.stderr,
        )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
