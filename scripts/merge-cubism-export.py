#!/usr/bin/env python3
"""After Cubism exports moc3, keep 墨汐 runtime extras Cubism does not write.

Cubism's embedded export overwrites model3.json with moc + textures (+ cdi).
This merges LipSync / EyeBlink groups, idle/talk motions, and the four
expressions back in. character.json is left as-is except fallbackPng if
the texture folder name changed.
"""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path("/workspace/public/models/moxi")
MODEL3 = ROOT / "moxi.model3.json"
CHARACTER = ROOT / "character.json"

GROUPS = [
    {
        "Target": "Parameter",
        "Name": "EyeBlink",
        "Ids": ["ParamEyeLOpen", "ParamEyeROpen"],
    },
    {
        "Target": "Parameter",
        "Name": "LipSync",
        "Ids": ["ParamMouthOpenY"],
    },
]

EXPRESSIONS = [
    {"Name": "idle", "File": "expressions/idle.exp3.json"},
    {"Name": "talk", "File": "expressions/talk.exp3.json"},
    {"Name": "smile", "File": "expressions/smile.exp3.json"},
    {"Name": "surprise", "File": "expressions/surprise.exp3.json"},
    {"Name": "neutral", "File": "expressions/idle.exp3.json"},
]

MOTIONS = {
    "Idle": [{"File": "motions/idle.motion3.json", "FadeInTime": 0.5, "FadeOutTime": 0.5}],
    "Talk": [{"File": "motions/talk.motion3.json", "FadeInTime": 0.15, "FadeOutTime": 0.25}],
}


def main() -> None:
    data = json.loads(MODEL3.read_text())
    refs = data.setdefault("FileReferences", {})
    refs["Expressions"] = EXPRESSIONS
    refs["Motions"] = MOTIONS
    data["Groups"] = GROUPS
    MODEL3.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")

    textures = refs.get("Textures") or []
    if textures and CHARACTER.exists():
        character = json.loads(CHARACTER.read_text())
        character["fallbackPng"] = textures[0]
        CHARACTER.write_text(json.dumps(character, indent=2, ensure_ascii=False) + "\n")
        apk = Path("/workspace/characters/moxi/apk/character.json")
        if apk.exists():
            apk.write_text(CHARACTER.read_text())

    print("merged", MODEL3)


if __name__ == "__main__":
    main()
