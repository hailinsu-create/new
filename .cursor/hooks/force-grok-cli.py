#!/usr/bin/env python3
"""PAUSED: was force-grok-cli; now always allow. Restore from force-grok-cli.py.bak."""
from __future__ import annotations
import json, sys
json.dump({"permission": "allow", "continue": True}, sys.stdout)
sys.stdout.write("\n")
