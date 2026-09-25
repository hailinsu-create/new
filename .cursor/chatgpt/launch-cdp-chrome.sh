#!/usr/bin/env bash
# Launch dedicated Chrome with CDP for ChatGPT web quota bridge.
set -euo pipefail
PORT="${CHATGPT_CDP_PORT:-9222}"
HOME_DIR="${CHATGPT_WEB_HOME:-$HOME/.chatgpt-web}"
PROFILE="$HOME_DIR/profile"
LOG="$HOME_DIR/chrome.log"
URL="${CHATGPT_URL:-https://chatgpt.com}"
CHROME_BIN="${CHATGPT_CHROME_BIN:-$(command -v google-chrome-stable || command -v google-chrome || true)}"

if [[ -z "$CHROME_BIN" ]]; then
  echo "chatgpt:unavailable chrome not found" >&2
  exit 2
fi

mkdir -p "$PROFILE" "$HOME_DIR"

if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
  echo "CDP already up on :$PORT"
  curl -s "http://127.0.0.1:${PORT}/json/version" | head -c 400
  echo
  exit 0
fi

# DISPLAY required for Cloud desktop
export DISPLAY="${DISPLAY:-:1}"

nohup "$CHROME_BIN" \
  --remote-debugging-port="$PORT" \
  --user-data-dir="$PROFILE" \
  --no-first-run \
  --no-default-browser-check \
  --disable-popup-blocking \
  --window-size=1400,900 \
  "$URL" \
  >"$LOG" 2>&1 &
echo $! >"$HOME_DIR/chrome.pid"

for _ in $(seq 1 40); do
  if curl -sf "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1; then
    echo "CDP ready :$PORT pid=$(cat "$HOME_DIR/chrome.pid")"
    exit 0
  fi
  sleep 0.25
done

echo "chatgpt:unavailable CDP did not come up; see $LOG" >&2
exit 3
