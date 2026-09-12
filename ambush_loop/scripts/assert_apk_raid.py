#!/usr/bin/env python3
"""Assert a sideload APK was exported from the Commandos / WW2 raid tree."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import zipfile

REQUIRED_ASSETS = (
    "assets/scripts/raid/raid_director.gdc",
    "assets/scripts/raid/weapon_catalog.gdc",
    "assets/scripts/raid/stash.gdc",
    "assets/scripts/art/weapon_art.gdc",
    "assets/scripts/art/ww2_palette.gdc",
)

AAPT = "/home/ubuntu/Android/Sdk/build-tools/34.0.0/aapt"


def _badging(apk: str) -> str:
    if not os.path.isfile(AAPT):
        return ""
    out = subprocess.check_output([AAPT, "dump", "badging", apk], text=True)
    return out.splitlines()[0]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("apk")
    p.add_argument("--version", default="0.3.1")
    p.add_argument("--version-code", type=int, default=3)
    args = p.parse_args()
    if not os.path.isfile(args.apk):
        print("ASSERT_APK_MISSING", args.apk, file=sys.stderr)
        return 2
    with zipfile.ZipFile(args.apk) as z:
        names = set(z.namelist())
    missing = [n for n in REQUIRED_ASSETS if n not in names]
    if missing:
        print("ASSERT_APK_MISSING_RAID", missing, file=sys.stderr)
        return 3
    badge = _badging(args.apk)
    if badge:
        want_name = "versionName='%s'" % args.version
        want_code = "versionCode='%s'" % args.version_code
        if want_name not in badge or want_code not in badge:
            print("ASSERT_APK_VERSION", badge, file=sys.stderr)
            return 4
        print("ASSERT_APK_BADGING", badge)
    print("ASSERT_OK_RAID_APK", os.path.basename(args.apk), "n_raid", len(REQUIRED_ASSETS))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
