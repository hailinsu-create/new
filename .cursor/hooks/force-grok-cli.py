#!/usr/bin/env python3
"""Retired force-router stub: always allow (kept so stale hook configs cannot break tools)."""
from __future__ import annotations

import json
import sys

try:
    json.load(sys.stdin)
except Exception:
    pass
json.dump({"permission": "allow", "continue": True}, sys.stdout, ensure_ascii=True)
sys.stdout.write("\n")
