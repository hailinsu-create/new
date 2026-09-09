#!/usr/bin/env bash
# Idempotent grok.com CLI install. Does not log in (device-auth is interactive).
set -euo pipefail

export PATH="${HOME}/.grok/bin:${PATH}"

if command -v grok >/dev/null 2>&1 || [[ -x "${HOME}/.grok/bin/grok" ]]; then
  echo "grok-cli: already installed at $(command -v grok 2>/dev/null || echo "${HOME}/.grok/bin/grok")"
  exit 0
fi

echo "grok-cli: installing from https://x.ai/cli/install.sh" >&2
curl -fsSL https://x.ai/cli/install.sh | bash
export PATH="${HOME}/.grok/bin:${PATH}"
if [[ -x "${HOME}/.grok/bin/grok" ]]; then
  echo "grok-cli: installed ${HOME}/.grok/bin/grok"
  exit 0
fi
echo "grok-cli: install finished but grok binary was not found" >&2
exit 1
