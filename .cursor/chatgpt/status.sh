#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
bash "$ROOT/launch-cdp-chrome.sh"
export CHATGPT_CDP_URL="${CHATGPT_CDP_URL:-http://127.0.0.1:${CHATGPT_CDP_PORT:-9222}}"
exec "$ROOT/.venv/bin/python" "$ROOT/drive.py" --status-only
