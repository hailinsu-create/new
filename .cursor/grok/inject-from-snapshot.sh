#!/usr/bin/env bash
# Optional start helper: CLI/PATH only. Never inject force-routing hooks/rules.
set -euo pipefail
export PATH="${HOME}/.grok/bin:${HOME}/.local/bin:${HOME}/.opencode/bin:${HOME}/.kimi-code/bin:${PATH}"
MARKER="# grok-cli-path"
if [[ -f "${HOME}/.bashrc" ]] && ! grep -q "${MARKER}" "${HOME}/.bashrc" 2>/dev/null; then
  printf '\n%s\nexport PATH="$HOME/.grok/bin:$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.kimi-code/bin:$PATH"\n' "${MARKER}" >> "${HOME}/.bashrc"
fi
WS="${CURSOR_WORKSPACE:-/workspace}"
if [[ -x "${WS}/.cursor/quota-clis/install-all.sh" ]]; then
  bash "${WS}/.cursor/quota-clis/install-all.sh" || true
fi
echo "grok-cli: start helper OK (no force-routing)"
