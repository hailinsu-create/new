#!/usr/bin/env bash
# WORK runner: OpenCode Go → DeepSeek V4.1 Flash (ds 4.1). No --auto (slow).
set -euo pipefail
export PATH="${HOME}/.opencode/bin:${PATH}"
MODEL="${OPENCODE_DS41_MODEL:-opencode-go/deepseek-v4.1-flash}"
if [[ -z "${OPENCODE_API_KEY:-}" ]] && [[ -f "${HOME}/.local/share/opencode/auth.json" ]]; then
  : # auth.json used by opencode
elif [[ -z "${OPENCODE_API_KEY:-}" ]]; then
  echo "missing OPENCODE_API_KEY (Dashboard Secret or ~/.local/share/opencode/auth.json)" >&2
  exit 1
fi
exec opencode run -m "$MODEL" "$@"
