#!/usr/bin/env bash
# Cloud Agent start hook (copied into the environment snapshot).
# 1) Ensure Grok CLI + PATH
# 2) Ensure other quota CLIs (agy, opencode, kimi) — NOT Codex/GPT
# 3) If this checkout does not already contain the grok CLI router, inject it so
#    every Cloud Agent on this environment can route onto grok.com CLI.
set -euo pipefail

export PATH="${HOME}/.grok/bin:${HOME}/.local/bin:${HOME}/.opencode/bin:${HOME}/.kimi-code/bin:${PATH}"

MARKER="# grok-cli-path"
if [[ -f "${HOME}/.bashrc" ]] && ! grep -q "${MARKER}" "${HOME}/.bashrc" 2>/dev/null; then
  printf '\n%s\nexport PATH="$HOME/.grok/bin:$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.kimi-code/bin:$PATH"\n' "${MARKER}" >> "${HOME}/.bashrc"
fi

ROOT="${GROK_CURSOR_ROUTER_ROOT:-${HOME}/.grok-cursor-router}"
WS="${CURSOR_WORKSPACE:-/workspace}"

if [[ ! -x "${HOME}/.grok/bin/grok" ]]; then
  curl -fsSL https://x.ai/cli/install.sh | bash || true
  export PATH="${HOME}/.grok/bin:${PATH}"
fi

# Install agy + opencode + kimi (idempotent). Prefer workspace script if present.
QUOTA_INSTALL=""
if [[ -x "${WS}/.cursor/quota-clis/install-all.sh" ]]; then
  QUOTA_INSTALL="${WS}/.cursor/quota-clis/install-all.sh"
elif [[ -x "${ROOT}/quota-clis/install-all.sh" ]]; then
  QUOTA_INSTALL="${ROOT}/quota-clis/install-all.sh"
fi
if [[ -n "${QUOTA_INSTALL}" ]]; then
  bash "${QUOTA_INSTALL}" || echo "quota-clis: install-all reported errors (continuing)" >&2
else
  echo "quota-clis: install-all.sh not found yet; Grok-only this boot" >&2
fi

if [[ ! -d "${ROOT}" ]]; then
  echo "grok-cli: snapshot router missing at ${ROOT}" >&2
  exit 0
fi

if [[ ! -d "${WS}/.git" ]]; then
  echo "grok-cli: no git workspace at ${WS}" >&2
  exit 0
fi

if git -C "${WS}" ls-files --error-unmatch .cursor/grok/run.sh >/dev/null 2>&1; then
  chmod +x "${WS}/.cursor/grok/run.sh" "${WS}/.cursor/grok/install.sh" 2>/dev/null || true
  chmod +x "${WS}/.cursor/hooks/force-grok-cli.py" 2>/dev/null || true
  chmod +x "${WS}/.cursor/quota-clis/install-all.sh" 2>/dev/null || true
  chmod +x "${WS}/.cursor/grok/inject-from-snapshot.sh" 2>/dev/null || true
  echo "grok-cli: workspace already has router from git"
  exit 0
fi

mkdir -p "${WS}/.cursor/rules" "${WS}/.cursor/grok" "${WS}/.cursor/hooks" "${WS}/.cursor/quota-clis"
cp -a "${ROOT}/rules/." "${WS}/.cursor/rules/"
cp -a "${ROOT}/grok/." "${WS}/.cursor/grok/"
cp -a "${ROOT}/hooks/." "${WS}/.cursor/hooks/"
cp -a "${ROOT}/hooks.json" "${WS}/.cursor/hooks.json"
if [[ -d "${ROOT}/quota-clis" ]]; then
  cp -a "${ROOT}/quota-clis/." "${WS}/.cursor/quota-clis/"
fi
chmod +x "${WS}/.cursor/grok/run.sh" "${WS}/.cursor/grok/install.sh" "${WS}/.cursor/hooks/force-grok-cli.py" "${WS}/.cursor/grok/inject-from-snapshot.sh" || true
chmod +x "${WS}/.cursor/quota-clis/install-all.sh" 2>/dev/null || true
echo "grok-cli: injected grok.com CLI router + quota-clis into ${WS}/.cursor"
