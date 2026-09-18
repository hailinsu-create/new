#!/usr/bin/env bash
# Cloud Agent start hook (lives in the environment snapshot).
# Skip-if-valid OIDC refresh on boot (never --force), then inject the CLI router.
set -euo pipefail

export PATH="${HOME}/.grok/bin:${PATH}"

MARKER="# grok-cli-path"
if [[ -f "${HOME}/.bashrc" ]] && ! grep -q "${MARKER}" "${HOME}/.bashrc" 2>/dev/null; then
  printf '\n%s\nexport PATH="$HOME/.grok/bin:$PATH"\n' "${MARKER}" >> "${HOME}/.bashrc"
fi

ROOT="${GROK_CURSOR_ROUTER_ROOT:-${HOME}/.grok-cursor-router}"
WS="${CURSOR_WORKSPACE:-/workspace}"

if [[ ! -x "${HOME}/.grok/bin/grok" ]]; then
  curl -fsSL https://x.ai/cli/install.sh | bash || true
  export PATH="${HOME}/.grok/bin:${PATH}"
fi

# Skip-if-valid refresh. Never --force on boot: a still-valid access token must
# skip, otherwise Bot cold start rotates refresh_token and poisons the Saved disk.
if [[ -f "${ROOT}/grok/oidc_refresh.py" ]]; then
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

mkdir -p "${WS}/.cursor/grok" "${WS}/.cursor/rules" "${WS}/.cursor/hooks"
if [[ -d "${ROOT}/grok" ]]; then
  cp -a "${ROOT}/grok/." "${WS}/.cursor/grok/"
  chmod +x "${WS}/.cursor/grok/run.sh" "${WS}/.cursor/grok/install.sh" "${WS}/.cursor/grok/inject-from-snapshot.sh" "${WS}/.cursor/grok/pin_profile.py" 2>/dev/null || true
fi
if [[ -d "${ROOT}/rules" ]]; then
  cp -a "${ROOT}/rules/." "${WS}/.cursor/rules/"
fi
if [[ -d "${ROOT}/hooks" ]]; then
  cp -a "${ROOT}/hooks/." "${WS}/.cursor/hooks/"
fi
if [[ -f "${ROOT}/hooks.json" ]]; then
  cp -a "${ROOT}/hooks.json" "${WS}/.cursor/hooks.json"
fi
chmod +x "${WS}/.cursor/hooks/force-grok-cli.py" 2>/dev/null || true
if [[ ! -f "${WS}/AGENTS.md" && -f "${ROOT}/AGENTS.md" ]]; then
  cp -a "${ROOT}/AGENTS.md" "${WS}/AGENTS.md"
fi
if [[ -f "${WS}/.cursor/grok/pin_profile.py" ]]; then
  python3 "${WS}/.cursor/grok/pin_profile.py" user-config >/dev/null 2>&1 || true
elif [[ -f "${ROOT}/grok/pin_profile.py" ]]; then
  python3 "${ROOT}/grok/pin_profile.py" user-config >/dev/null 2>&1 || true
fi
echo "grok-cli: snapshot router synced; Extra High Fast pinned; OIDC refresh skipped-or-attempted (never force on boot)"
