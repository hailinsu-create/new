#!/usr/bin/env python3
"""Write Play-common locale string/array XML from the English templates."""
from __future__ import annotations

import xml.etree.ElementTree as ET
import sys
from pathlib import Path

RES = Path("/workspace/android/app/src/main/res")
EN_STRINGS = RES / "values-en/strings.xml"
EN_ARRAYS = RES / "values-en/arrays.xml"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from locales_catalog import ARRAYS, STRINGS


def esc(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace("'", r"\'")
        .replace('"', r"\"")
    )


def parse_strings(path: Path) -> dict[str, str]:
    tree = ET.parse(path)
    out = {}
    for node in tree.getroot().findall("string"):
        name = node.get("name")
        if node.get("translatable") == "false":
            continue
        out[name] = "".join(node.itertext())
    return out


def parse_arrays(path: Path) -> dict[str, list[str]]:
    tree = ET.parse(path)
    out = {}
    for node in tree.getroot().findall("string-array"):
        name = node.get("name")
        out[name] = ["".join(item.itertext()) for item in node.findall("item")]
    return out


def write_strings(folder: str, data: dict[str, str]) -> None:
    dest = RES / folder
    dest.mkdir(parents=True, exist_ok=True)
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
    for key, value in data.items():
        lines.append(f'    <string name="{key}">{esc(value)}</string>')
    lines.append("</resources>\n")
    (dest / "strings.xml").write_text("\n".join(lines), encoding="utf-8")


def write_arrays(folder: str, data: dict[str, list[str]]) -> None:
    dest = RES / folder
    dest.mkdir(parents=True, exist_ok=True)
    lines = ['<?xml version="1.0" encoding="utf-8"?>', "<resources>"]
    for name, items in data.items():
        lines.append(f'    <string-array name="{name}">')
        for item in items:
            lines.append(f"        <item>{esc(item)}</item>")
        lines.append("    </string-array>")
    lines.append("</resources>\n")
    (dest / "arrays.xml").write_text("\n".join(lines), encoding="utf-8")


# Translations overlay English. Only differences need listing if I merge, but
# we list full maps for reviewability.


def main() -> None:
    en_s = parse_strings(EN_STRINGS)
    en_a = parse_arrays(EN_ARRAYS)
    for folder, overlay in STRINGS.items():
        extra = [k for k in overlay if k not in en_s]
        if extra:
            raise SystemExit(f"{folder} extra string keys: {extra}")
        merged = dict(en_s)
        merged.update(overlay)
        write_strings(folder, merged)
    for folder, overlay in ARRAYS.items():
        extra = [k for k in overlay if k not in en_a]
        if extra:
            raise SystemExit(f"{folder} extra array keys: {extra}")
        merged = dict(en_a)
        merged.update(overlay)
        write_arrays(folder, merged)
    # Locales that only have strings still get English arrays.
    for folder in STRINGS:
        if folder not in ARRAYS:
            write_arrays(folder, en_a)
    print("wrote", ", ".join(STRINGS))


if __name__ == "__main__":
    main()
