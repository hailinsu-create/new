#!/usr/bin/env bash
# Cloud Agent start helper (also copied into environment snapshots).
# 1) Ensure Grok CLI + PATH
# 2) Ensure other quota CLIs (agy, opencode, kimi) — NOT Codex/GPT
# 3) Do NOT inject force-routing hooks/rules. Grok CLI is opt-in only.
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

# Opt-in tooling only: never copy hooks.json / alwaysApply rules / force-grok-cli.py
if [[ -d "${WS}/.git" && -d "${ROOT}/grok" ]]; then
  mkdir -p "${WS}/.cursor/grok" "${WS}/.cursor/quota-clis"
  for f in run.sh install.sh oidc_refresh.py test_oidc_refresh.py inject-from-snapshot.sh; do
    if [[ -e "${ROOT}/grok/${f}" && ! -e "${WS}/.cursor/grok/${f}" ]]; then
      cp -a "${ROOT}/grok/${f}" "${WS}/.cursor/grok/${f}"
    fi
  done
  if [[ -d "${ROOT}/quota-clis" ]]; then
    for f in install-all.sh CALL-RECIPES.md; do
      if [[ -e "${ROOT}/quota-clis/${f}" && ! -e "${WS}/.cursor/quota-clis/${f}" ]]; then
        cp -a "${ROOT}/quota-clis/${f}" "${WS}/.cursor/quota-clis/${f}"
      fi
    done
  fi
  chmod +x "${WS}/.cursor/grok/"*.sh 2>/dev/null || true
  chmod +x "${WS}/.cursor/quota-clis/install-all.sh" 2>/dev/null || true
fi

echo "grok-cli: start helper OK (CLI/PATH only; force-routing disabled)"
