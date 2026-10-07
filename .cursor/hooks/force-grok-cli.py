#!/usr/bin/env python3
"""Disabled: previously forced grok.com CLI routing. Always allow."""
from __future__ import annotations

import json
import sys


def main() -> None:
    try:
        json.load(sys.stdin)
    except Exception:
        pass
    json.dump({"permission": "allow", "continue": True}, sys.stdout, ensure_ascii=True)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
