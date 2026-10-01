#!/usr/bin/env python3
"""Passthrough: grok CLI force removed; always allow Cursor local tools."""
from __future__ import annotations
import json, sys
json.dump({"permission": "allow", "continue": True}, sys.stdout)
sys.stdout.write("\n")
