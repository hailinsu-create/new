#!/usr/bin/env bash
# Cloud Agent start hook (copied into the environment snapshot).
# If this checkout does not already contain the grok CLI router, inject it so
# every Cloud Agent on this environment is forced onto grok.com CLI.
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

if [[ ! -d "${ROOT}" ]]; then
  echo "grok-cli: snapshot router missing at ${ROOT}" >&2
  exit 0
fi

if [[ ! -d "${WS}/.git" ]]; then
  echo "grok-cli: no git workspace at ${WS}" >&2
  exit 0
fi

pin_profile() {
  local pin="${WS}/.cursor/grok/pin_profile.py"
  if [[ ! -f "${pin}" && -f "${ROOT}/grok/pin_profile.py" ]]; then
    pin="${ROOT}/grok/pin_profile.py"
  fi
  if [[ -f "${pin}" ]]; then
    python3 "${pin}" user-config >/dev/null 2>&1 || true
  fi
}

seed_agents_md() {
  if [[ -f "${WS}/AGENTS.md" ]]; then
    return 0
  fi
  if [[ -f "${ROOT}/AGENTS.md" ]]; then
    cp -a "${ROOT}/AGENTS.md" "${WS}/AGENTS.md"
  fi
}

if git -C "${WS}" ls-files --error-unmatch .cursor/grok/run.sh >/dev/null 2>&1; then
  chmod +x "${WS}/.cursor/grok/run.sh" "${WS}/.cursor/grok/install.sh" 2>/dev/null || true
  chmod +x "${WS}/.cursor/hooks/force-grok-cli.py" "${WS}/.cursor/grok/pin_profile.py" 2>/dev/null || true
  seed_agents_md
  pin_profile
  echo "grok-cli: workspace already has router from git"
  exit 0
fi

mkdir -p "${WS}/.cursor/rules" "${WS}/.cursor/grok" "${WS}/.cursor/hooks"
cp -a "${ROOT}/rules/." "${WS}/.cursor/rules/"
cp -a "${ROOT}/grok/." "${WS}/.cursor/grok/"
cp -a "${ROOT}/hooks/." "${WS}/.cursor/hooks/"
cp -a "${ROOT}/hooks.json" "${WS}/.cursor/hooks.json"
chmod +x "${WS}/.cursor/grok/run.sh" "${WS}/.cursor/grok/install.sh" "${WS}/.cursor/hooks/force-grok-cli.py" "${WS}/.cursor/grok/inject-from-snapshot.sh" "${WS}/.cursor/grok/pin_profile.py" || true
seed_agents_md
pin_profile
echo "grok-cli: injected grok.com CLI router into ${WS}/.cursor"
