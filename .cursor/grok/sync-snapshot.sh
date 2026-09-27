#!/usr/bin/env bash
# Copy the git-tracked grok.com CLI router into ~/.grok-cursor-router.
# Disk edits persist to future Cloud Agents only after Environment Save.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ROOT="${GROK_CURSOR_ROUTER_ROOT:-${HOME}/.grok-cursor-router}"

if [[ ! -f "${WS}/AGENTS.md" || ! -f "${WS}/.cursor/grok/run.sh" ]]; then
  echo "grok-cli: ${WS} is not a grok CLI router checkout" >&2
  exit 1
fi

mkdir -p "${ROOT}/grok" "${ROOT}/hooks" "${ROOT}/rules"
cp -a "${WS}/AGENTS.md" "${ROOT}/AGENTS.md"
cp -a "${WS}/.cursor/hooks.json" "${ROOT}/hooks.json"
cp -a "${WS}/.cursor/hooks/force-grok-cli.py" "${ROOT}/hooks/force-grok-cli.py"
cp -a "${WS}/.cursor/rules/always-use-grok-cli.mdc" "${ROOT}/rules/always-use-grok-cli.mdc"

shopt -s nullglob
for path in "${WS}/.cursor/grok/"*; do
  base="$(basename "${path}")"
  case "${base}" in
    __pycache__) continue ;;
    *.pyc) continue ;;
  esac
  cp -a "${path}" "${ROOT}/grok/${base}"
done

cp -a "${WS}/.cursor/grok/inject-from-snapshot.sh" "${ROOT}/inject.sh"
chmod +x "${ROOT}/inject.sh" "${ROOT}/grok/run.sh" "${ROOT}/grok/install.sh" \
  "${ROOT}/grok/inject-from-snapshot.sh" "${ROOT}/grok/pin_profile.py" \
  "${ROOT}/grok/sync-snapshot.sh" "${ROOT}/hooks/force-grok-cli.py" \
  2>/dev/null || true

echo "grok-cli: snapshot updated at ${ROOT} from ${WS}"
echo "grok-cli: click Environment Save on the keeper to persist (not Git)"
echo "grok-cli: https://cursor.com/agents/bc-886bf39b-fc12-43b3-80c4-0135a6598ca5"
echo "grok-cli: https://cursor.com/dashboard/cloud-agents/environments/e/fbfdc9fc-a3c0-11f1-a7d1-d6b4613131ce"
