#!/usr/bin/env python3
"""Pin grok.com CLI to Grok 4.6 Extra High Fast.

Highest advertised grok-4.6 effort is Extra High (`xhigh`). Fast is xAI
priority processing (`x-grok-service-tier: priority`); there is no
`grok-4.6-fast` slug.
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

PINNED_MODEL = "grok-4.6"
PINNED_EFFORT = "xhigh"
PINNED_FAST_HEADER = "x-grok-service-tier"
PINNED_FAST_VALUE = "priority"

MODELS_TOML = {
    "default": f'"{PINNED_MODEL}"',
    "default_reasoning_effort": f'"{PINNED_EFFORT}"',
    "extra_headers": f'{{ "{PINNED_FAST_HEADER}" = "{PINNED_FAST_VALUE}" }}',
}

USAGE = "usage: pin_profile.py grok-config | user-config [--config-file PATH] | print"


def grok_config_overlay(existing_raw: str | None = None) -> dict:
    cfg: dict = {}
    raw = existing_raw if existing_raw is not None else os.environ.get("GROK_CONFIG", "")
    if isinstance(raw, str) and raw.strip():
        try:
            parsed = json.loads(raw)
        except Exception:
            parsed = {}
        if isinstance(parsed, dict):
            cfg = parsed
    models = cfg.get("models")
    if not isinstance(models, dict):
        models = {}
    headers = models.get("extra_headers")
    if not isinstance(headers, dict):
        headers = {}
    headers[PINNED_FAST_HEADER] = PINNED_FAST_VALUE
    models["default"] = PINNED_MODEL
    models["default_reasoning_effort"] = PINNED_EFFORT
    models["extra_headers"] = headers
    cfg["models"] = models
    return cfg


def grok_config_json(existing_raw: str | None = None) -> str:
    return json.dumps(grok_config_overlay(existing_raw), separators=(",", ":"))


def upsert_models_toml(text: str) -> str:
    lines = text.splitlines()
    start = None
    for i, line in enumerate(lines):
        if line.strip() == "[models]":
            start = i
            break
    block_lines = [f"{key} = {value}" for key, value in MODELS_TOML.items()]
    if start is None:
        body = text.rstrip()
        block = "[models]\n" + "\n".join(block_lines) + "\n"
        if body:
            return body + "\n\n" + block
        return block

    end = len(lines)
    for j in range(start + 1, len(lines)):
        stripped = lines[j].strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            end = j
            break

    found = {key: False for key in MODELS_TOML}
    new_section: list[str] = []
    for line in lines[start + 1 : end]:
        stripped = line.strip()
        replaced = False
        if stripped and not stripped.startswith("#") and "=" in stripped:
            keypart = stripped.split("=", 1)[0].strip()
            if keypart in MODELS_TOML:
                new_section.append(f"{keypart} = {MODELS_TOML[keypart]}")
                found[keypart] = True
                replaced = True
        if not replaced:
            new_section.append(line)
    missing = [f"{key} = {value}" for key, value in MODELS_TOML.items() if not found[key]]
    rebuilt = lines[: start + 1] + missing + new_section + lines[end:]
    return "\n".join(rebuilt).rstrip() + "\n"


def write_user_config(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text(encoding="utf-8") if path.is_file() else ""
    path.write_text(upsert_models_toml(existing), encoding="utf-8")


def cmd_user_config(argv: list[str]) -> int:
    path = Path(os.path.expanduser("~/.grok/config.toml"))
    args = list(argv)
    i = 0
    while i < len(args):
        if args[i] == "--config-file" and i + 1 < len(args):
            path = Path(args[i + 1])
            i += 2
            continue
        print(USAGE, file=sys.stderr)
        return 1
    write_user_config(path)
    print(f"pinned {path} to {PINNED_MODEL} extra-high fast")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    if not args or args[0] in {"-h", "--help", "help"}:
        print(USAGE)
        return 0
    cmd = args[0]
    if cmd == "print":
        print(
            f"{PINNED_MODEL} extra-high fast "
            f"(effort={PINNED_EFFORT}, {PINNED_FAST_HEADER}={PINNED_FAST_VALUE})"
        )
        return 0
    if cmd == "grok-config":
        print(grok_config_json())
        return 0
    if cmd == "user-config":
        return cmd_user_config(args[1:])
    print(USAGE, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
