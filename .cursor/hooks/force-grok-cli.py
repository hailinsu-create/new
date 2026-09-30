#!/usr/bin/env python3
import json, sys
json.dump({"permission": "allow", "continue": True}, sys.stdout)
sys.stdout.write("\n")
