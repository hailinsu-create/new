#!/usr/bin/env bash
# Run the grok.com CLI with the session already logged in on this machine.
# Always pinned to Grok 4.6 Extra High Fast. Fast is xAI priority processing
# (no grok-4.6-fast slug exists).
set -euo pipefail

export PATH="${HOME}/.grok/bin:${PATH}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OIDC_REFRESH="${SCRIPT_DIR}/oidc_refresh.py"

PINNED_MODEL="grok-4.6"
PINNED_EFFORT="xhigh"
PINNED_FAST_HEADER="x-grok-service-tier"
PINNED_FAST_VALUE="priority"

die() {
  echo "grok-cli: $*" >&2
  exit 1
}

find_grok() {
  if [[ -n "${GROK_BIN:-}" && -x "${GROK_BIN}" ]]; then
    printf '%s\n' "${GROK_BIN}"
    return 0
  fi
  if command -v grok >/dev/null 2>&1; then
    command -v grok
    return 0
  fi
  if [[ -x "${HOME}/.grok/bin/grok" ]]; then
    printf '%s\n' "${HOME}/.grok/bin/grok"
    return 0
  fi
  return 1
}

ensure_install() {
  if find_grok >/dev/null; then
    return 0
  fi
  echo "grok-cli: Grok CLI not found; installing..." >&2
  curl -fsSL https://x.ai/cli/install.sh | bash
  export PATH="${HOME}/.grok/bin:${PATH}"
  find_grok >/dev/null || die "install finished but grok binary was not found"
}

# Prints VALID | NEEDS_REFRESH | LOGGED_OUT. $1 is min remaining seconds (default 60).
auth_state() {
  local min_remaining="${1:-60}"
  python3 - "${min_remaining}" <<'PY'
import json, os, sys
from datetime import datetime, timezone

min_remaining = float(sys.argv[1])
path = os.path.expanduser("~/.grok/auth.json")
try:
    data = json.load(open(path))
except Exception:
    print("LOGGED_OUT")
    raise SystemExit(0)

now = datetime.now(timezone.utc)
best_remaining = None
has_unexpiring = False
has_refresh = False
for value in data.values() if isinstance(data, dict) else []:
    if not isinstance(value, dict):
        continue
    if value.get("refresh_token") and value.get("oidc_client_id"):
        has_refresh = True
    if not value.get("key"):
        continue
    exp = value.get("expires_at")
    if not exp:
        has_unexpiring = True
        continue
    try:
        dt = datetime.fromisoformat(exp.replace("Z", "+00:00"))
    except Exception:
        has_unexpiring = True
        continue
    remaining = (dt - now).total_seconds()
    if best_remaining is None or remaining > best_remaining:
        best_remaining = remaining

if has_unexpiring or (best_remaining is not None and best_remaining > min_remaining):
    print("VALID")
elif has_refresh:
    print("NEEDS_REFRESH")
else:
    print("LOGGED_OUT")
PY
}

refresh_oidc() {
  [[ -f "${OIDC_REFRESH}" ]] || die "missing OIDC refresh helper: ${OIDC_REFRESH}"
  python3 "${OIDC_REFRESH}"
}

logged_in() {
  [[ -f "${HOME}/.grok/auth.json" ]] || return 1
  local state
  state="$(auth_state 60)"
  if [[ "${state}" == "VALID" ]]; then
    return 0
  fi
  if [[ "${state}" == "NEEDS_REFRESH" ]]; then
    refresh_oidc >&2 || return 1
    state="$(auth_state 0)"
    [[ "${state}" == "VALID" ]]
    return
  fi
  return 1
}

cmd_status() {
  ensure_install
  local grok
  grok="$(find_grok)"
  echo "binary: ${grok}"
  "$grok" --version
  echo "profile: ${PINNED_MODEL} extra-high fast (effort=${PINNED_EFFORT}, ${PINNED_FAST_HEADER}=${PINNED_FAST_VALUE})"
  if logged_in; then
    echo "auth: grok.com session present"
    "$grok" models || true
    return 0
  fi
  echo "auth: not logged in"
  echo "Run: $0 login"
  echo "Then complete grok login --device-auth in a browser with the grok.com account whose quota you want."
  echo "An expired access token is auto-refreshed when a refresh_token remains; device login is only needed when refresh fails."
  return 2
}

cmd_refresh() {
  [[ -f "${HOME}/.grok/auth.json" ]] || die "not authenticated. Run: $0 login   (grok login --device-auth) with the grok.com account whose quota you want to use."
  refresh_oidc
}

cmd_login() {
  ensure_install
  exec "$(find_grok)" login --device-auth "$@"
}

cmd_run() {
  ensure_install
  local grok
  grok="$(find_grok)"
  if ! logged_in; then
    die "not authenticated. Run: $0 login   (grok login --device-auth) with the grok.com account whose quota you want to use."
  fi

  local cwd="${GROK_CLI_CWD:-$(pwd)}"
  if [[ -z "${GROK_CONFIG:-}" ]]; then
    export GROK_CONFIG="$(python3 - <<PY
import json
print(json.dumps({
    "models": {
        "default": "${PINNED_MODEL}",
        "default_reasoning_effort": "${PINNED_EFFORT}",
        "extra_headers": {"${PINNED_FAST_HEADER}": "${PINNED_FAST_VALUE}"},
    }
}))
PY
)"
  fi
  local extra=(
    --always-approve
    --no-auto-update
    --output-format plain
    --cwd "${cwd}"
    -m "${PINNED_MODEL}"
    --effort "${PINNED_EFFORT}"
  )
  echo "grok-cli: using ${PINNED_MODEL} extra-high fast" >&2

  local prompt_file=""
  local cleanup=0
  if [[ "${1:-}" == "--file" ]]; then
    [[ -n "${2:-}" ]] || die "run --file requires a path"
    prompt_file="$2"
    [[ -f "${prompt_file}" ]] || die "prompt file not found: ${prompt_file}"
  elif [[ $# -gt 0 ]]; then
    prompt_file="$(mktemp)"
    cleanup=1
    printf '%s\n' "$*" >"${prompt_file}"
  elif [[ ! -t 0 ]]; then
    prompt_file="$(mktemp)"
    cleanup=1
    cat >"${prompt_file}"
  else
    die "usage: run.sh run [--file PATH] [prompt...]"
  fi

  set +e
  "${grok}" "${extra[@]}" --prompt-file "${prompt_file}"
  local rc=$?
  set -e
  if [[ "${cleanup}" -eq 1 ]]; then
    rm -f "${prompt_file}"
  fi
  return "${rc}"
}

case "${1:-}" in
  status | ensure)
    shift
    cmd_status "$@"
    ;;
  login)
    shift
    cmd_login "$@"
    ;;
  refresh)
    shift
    cmd_refresh "$@"
    ;;
  run)
    shift
    cmd_run "$@"
    ;;
  -h | --help | help | "")
    cat <<'EOF'
usage: run.sh <command>

  status   Show grok binary and grok.com login state
  login    Start grok login --device-auth
  refresh  Renew the grok.com OIDC access token using the stored refresh_token
  run      Send a prompt to grok CLI (grok-4.6 extra-high fast, grok.com quota)

  run --file PATH
  run PROMPT...
  echo PROMPT | run.sh run
EOF
    ;;
  *)
    die "unknown command: $1 (try: status | login | refresh | run)"
    ;;
esac
