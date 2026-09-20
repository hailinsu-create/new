#!/usr/bin/env bash
# ChatGPT.com web quota bridge (Cloud Linux). Mirrors Windows chatgpt-web.ps1 roles.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
PY="${ROOT}/.venv/bin/python"
MODE=""
REQUEST_FILE=""
OUT_FILE="${ROOT}/last-out.md"
WORKSPACE="/workspace"
TIMEOUT_S="${CHATGPT_TIMEOUT_S:-900}"

usage() {
  echo "Usage: $0 -Mode plan|review -RequestFile <path> [-OutFile <path>] [-Workspace <path>]" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Mode|--mode) MODE="${2:-}"; shift 2 ;;
    -RequestFile|--request-file) REQUEST_FILE="${2:-}"; shift 2 ;;
    -OutFile|--out-file) OUT_FILE="${2:-}"; shift 2 ;;
    -Workspace|--workspace) WORKSPACE="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

MODE="$(echo "$MODE" | tr '[:upper:]' '[:lower:]')"
if [[ "$MODE" != "plan" && "$MODE" != "review" ]]; then
  echo "chatgpt:unavailable Mode must be plan|review" >&2
  exit 1
fi
if [[ -z "$REQUEST_FILE" || ! -f "$REQUEST_FILE" ]]; then
  echo "chatgpt:unavailable RequestFile missing" >&2
  exit 1
fi
if [[ ! -x "$PY" ]]; then
  echo "chatgpt:unavailable playwright venv missing at $ROOT/.venv" >&2
  exit 2
fi

bash "$ROOT/launch-cdp-chrome.sh"
export CHATGPT_CDP_URL="${CHATGPT_CDP_URL:-http://127.0.0.1:${CHATGPT_CDP_PORT:-9222}}"
# Workspace is recorded for callers; prompt body is the request file.
export CHATGPT_WORKSPACE="$WORKSPACE"
exec "$PY" "$ROOT/drive.py" --mode "$MODE" --request-file "$REQUEST_FILE" --out-file "$OUT_FILE" --timeout "$TIMEOUT_S"
