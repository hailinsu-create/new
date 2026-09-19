#!/usr/bin/env bash
# Cloud Agent start hook. Wire in the Cursor Environment install/start command:
#   bash "$HOME/.grok-cursor-router/inject.sh"
# Skip-if-valid OIDC refresh on boot (never --force). Seed the grok.com CLI
# router without overwriting git-tracked files from a stale snapshot.
set -euo pipefail

export PATH="${HOME}/.grok/bin:${PATH}"

ROUTER_MARKER="grok-cli-router:lningha@gmail.com"

MARKER="# grok-cli-path"
if [[ -f "${HOME}/.bashrc" ]] && ! grep -q "${MARKER}" "${HOME}/.bashrc" 2>/dev/null; then
  printf '\n%s\nexport PATH="$HOME/.grok/bin:$PATH"\n' "${MARKER}" >> "${HOME}/.bashrc"
fi

ROOT="${GROK_CURSOR_ROUTER_ROOT:-${HOME}/.grok-cursor-router}"
WS="${CURSOR_WORKSPACE:-/workspace}"

if [[ ! -x "${HOME}/.grok/bin/grok" ]]; then
  if [[ "${GROK_INJECT_SKIP_INSTALL:-}" == "1" ]]; then
    echo "grok-cli: skip install (GROK_INJECT_SKIP_INSTALL=1)" >&2
  else
    curl -fsSL https://x.ai/cli/install.sh | bash || true
    export PATH="${HOME}/.grok/bin:${PATH}"
  fi
fi

# Skip-if-valid refresh. Never --force on boot: a still-valid access token must
# skip, otherwise Bot cold start rotates refresh_token and poisons the Saved disk.
if [[ "${GROK_INJECT_SKIP_REFRESH:-}" != "1" && -f "${ROOT}/grok/oidc_refresh.py" ]]; then
  python3 "${ROOT}/grok/oidc_refresh.py" >/tmp/grok-oidc-refresh.log 2>&1 || true
fi

if [[ ! -d "${ROOT}" ]]; then
  echo "grok-cli: snapshot router missing at ${ROOT}" >&2
  exit 0
fi

if [[ ! -d "${WS}/.git" ]]; then
  echo "grok-cli: no git workspace at ${WS}" >&2
  exit 0
fi

copy_missing_tree() {
  local src="$1"
  local dest="$2"
  [[ -d "${src}" ]] || return 0
  mkdir -p "${dest}"
  local file rel
  while IFS= read -r -d '' file; do
    rel="${file#"${src}"/}"
    case "${rel}" in
      __pycache__/*|*/__pycache__/*|*.pyc) continue ;;
    esac
    if [[ ! -e "${dest}/${rel}" ]]; then
      mkdir -p "$(dirname "${dest}/${rel}")"
      cp -a "${file}" "${dest}/${rel}"
    fi
  done < <(find "${src}" -type f -print0)
}

ensure_agents_md() {
  local src="${ROOT}/AGENTS.md"
  local dest="${WS}/AGENTS.md"
  [[ -f "${src}" ]] || return 0
  if [[ -f "${dest}" ]] && grep -q "${ROUTER_MARKER}" "${dest}"; then
    return 0
  fi
  if [[ ! -f "${dest}" ]]; then
    cp -a "${src}" "${dest}"
    return 0
  fi
  local tmp
  tmp="$(mktemp)"
  {
    cat "${src}"
    printf '\n\n---\n\n'
    cat "${dest}"
  } >"${tmp}"
  mv "${tmp}" "${dest}"
}

write_home_hooks() {
  mkdir -p "${HOME}/.cursor"
  local cmd="python3 ${ROOT}/hooks/force-grok-cli.py"
  cat >"${HOME}/.cursor/hooks.json" <<EOF
{
  "version": 1,
  "hooks": {
    "sessionStart": [{"command": "${cmd}", "timeout": 10}],
    "beforeSubmitPrompt": [{"command": "${cmd}", "timeout": 10}],
    "preToolUse": [{"command": "${cmd}", "timeout": 10}],
    "beforeShellExecution": [{"command": "${cmd}", "timeout": 10}],
    "subagentStart": [{"command": "${cmd}", "timeout": 10}]
  }
}
EOF
}

mkdir -p "${WS}/.cursor/grok" "${WS}/.cursor/rules" "${WS}/.cursor/hooks"
copy_missing_tree "${ROOT}/grok" "${WS}/.cursor/grok"
copy_missing_tree "${ROOT}/rules" "${WS}/.cursor/rules"
copy_missing_tree "${ROOT}/hooks" "${WS}/.cursor/hooks"
if [[ ! -f "${WS}/.cursor/hooks.json" && -f "${ROOT}/hooks.json" ]]; then
  cp -a "${ROOT}/hooks.json" "${WS}/.cursor/hooks.json"
fi
ensure_agents_md

chmod +x "${WS}/.cursor/grok/run.sh" "${WS}/.cursor/grok/install.sh" \
  "${WS}/.cursor/grok/inject-from-snapshot.sh" "${WS}/.cursor/grok/pin_profile.py" \
  "${WS}/.cursor/grok/sync-snapshot.sh" "${WS}/.cursor/hooks/force-grok-cli.py" \
  2>/dev/null || true

if [[ -d "${ROOT}/rules" ]]; then
  mkdir -p "${HOME}/.cursor/rules"
  cp -a "${ROOT}/rules/." "${HOME}/.cursor/rules/"
fi
if [[ -f "${ROOT}/hooks/force-grok-cli.py" ]]; then
  write_home_hooks
fi

if [[ -f "${ROOT}/grok/pin_profile.py" ]]; then
  python3 "${ROOT}/grok/pin_profile.py" user-config >/dev/null 2>&1 || true
elif [[ -f "${WS}/.cursor/grok/pin_profile.py" ]]; then
  python3 "${WS}/.cursor/grok/pin_profile.py" user-config >/dev/null 2>&1 || true
fi

echo "grok-cli: snapshot router synced; Extra High Fast pinned; OIDC refresh skipped-or-attempted (never force on boot); required account lningha@gmail.com"
