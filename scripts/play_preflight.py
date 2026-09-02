#!/usr/bin/env python3
"""Checks that would make Play Console reject this package before you upload."""
from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "android/app/src/main/AndroidManifest.xml"
GRADLE = ROOT / "android/app/build.gradle.kts"
ASSETS = ROOT / "docs/play/assets"
LISTING = ROOT / "docs/play/listing.md"
LISTING_I18N = ROOT / "docs/play/listing-i18n.md"

BANNED_PERMS = {
    "com.google.android.gms.permission.AD_ID",
    "android.permission.READ_MEDIA_IMAGES",
    "android.permission.READ_MEDIA_VIDEO",
    "android.permission.READ_EXTERNAL_STORAGE",
    "android.permission.WRITE_EXTERNAL_STORAGE",
}
KEEP_PERMS = {
    "android.permission.SYSTEM_ALERT_WINDOW",
    "android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION",
    "android.permission.FOREGROUND_SERVICE_SPECIAL_USE",
    "com.android.vending.BILLING",
}


def fail(msg: str) -> None:
    print("FAIL:", msg)
    raise SystemExit(1)


def check_gradle() -> None:
    text = GRADLE.read_text()
    sdk = re.search(r"targetSdk\s*=\s*(\d+)", text)
    code = re.search(r"versionCode\s*=\s*(\d+)", text)
    name = re.search(r'versionName\s*=\s*"([^"]+)"', text)
    if not sdk or int(sdk.group(1)) < 36:
        fail("targetSdk must be 36+ for new Play apps")
    if not code or not name:
        fail("missing versionCode / versionName")
    print(f"OK gradle targetSdk={sdk.group(1)} version={name.group(1)} ({code.group(1)})")


def check_manifest() -> None:
    ns = {"a": "http://schemas.android.com/apk/res/android", "tools": "http://schemas.android.com/tools"}
    root = ET.parse(MANIFEST).getroot()
    declared = []
    removed = set()
    for node in root.findall("uses-permission"):
        name = node.get("{http://schemas.android.com/apk/res/android}name")
        action = node.get("{http://schemas.android.com/tools}node")
        if action == "remove":
            removed.add(name)
        else:
            declared.append(name)
    for perm in KEEP_PERMS:
        if perm not in declared:
            fail(f"manifest missing {perm}")
    leaked = [p for p in declared if p in BANNED_PERMS]
    if leaked:
        fail(f"banned permissions declared: {leaked}")
    for perm in BANNED_PERMS:
        if perm not in removed:
            fail(f"expected tools:node=remove for {perm}")
    print("OK manifest permissions")


def check_listing_limits() -> None:
    text = LISTING.read_text() + "\n## \n" + LISTING_I18N.read_text()
    parts = re.split(r"\n## ", text)
    bad = []
    for part in parts[1:]:
        m = re.search(r"\*\*(?:短说明|简短说明|Short description)\*\*.*?\n\n(.+?)\n\n", part, re.S)
        if not m:
            continue
        short = m.group(1).strip()
        if len(short) > 80:
            title = part.split("\n", 1)[0].strip()
            bad.append(f"{title}: {len(short)} {short}")
    if bad:
        fail("short descriptions over 80 chars:\n  " + "\n  ".join(bad))
    print("OK store short descriptions")


def check_graphics() -> None:
    from PIL import Image

    specs = {
        "play_icon_512.png": (512, 512),
        "feature_graphic_1024x500.png": (1024, 500),
        "screenshot_settings.png": (1080, 1920),
        "screenshot_consent.png": (1080, 1920),
        "screenshot_overlay.png": (1080, 1920),
        "screenshot_overlay_closeup.png": (1080, 1920),
    }
    for name, size in specs.items():
        path = ASSETS / name
        if not path.exists():
            fail(f"missing {path}")
        im = Image.open(path)
        if im.size != size:
            fail(f"{name} is {im.size}, want {size}")
        if im.mode not in ("RGB", "RGBA"):
            fail(f"{name} mode {im.mode}")
    print("OK listing graphics")


def check_package(path: Path) -> None:
    if not path.exists():
        print(f"SKIP package (not built): {path}")
        return
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        sos = [n for n in names if n.endswith(".so")]
        xml = ""
        for candidate in ("AndroidManifest.xml", "base/manifest/AndroidManifest.xml"):
            if candidate in names:
                xml = candidate
                break
        print(f"OK package {path.name} entries={len(names)} native_libs={len(sos)} manifest={xml or 'binary'}")
        if sos:
            print("WARN native .so present; confirm 16 KB ELF alignment before Play upload")
        else:
            print("OK no native .so (16 KB page-size rule does not apply to Java/Kotlin-only code)")


def main() -> None:
    check_gradle()
    check_manifest()
    check_listing_limits()
    check_graphics()
    check_package(ROOT / "dist/pangchuang-0.10.0-debug.apk")
    aab = Path("/opt/cursor/artifacts/pangchuang-0.10.0.aab")
    check_package(aab)
    print("play preflight passed")


if __name__ == "__main__":
    main()
