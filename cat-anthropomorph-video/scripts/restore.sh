#!/usr/bin/env bash
# Restore / sync SFW weights for cat-anthropomorph-video ComfyUI pipelines.
# Default: dry-run. Does not boot AutoDL or claim balance changes.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a
  source .env
  set +a
fi

GROUP_ARGS=()
DRY_RUN=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --group)
      GROUP_ARGS+=(--group "$2")
      shift 2
      ;;
    --apply)
      DRY_RUN=0
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      echo "Usage: bash scripts/restore.sh [--dry-run|--apply] [--group looklock|i2v|flf2v]..."
      echo "Default is --dry-run. Pass --apply to actually download."
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ${#GROUP_ARGS[@]} -eq 0 ]]; then
  GROUP_ARGS=(--group i2v)
fi

EXTRA=()
if [[ "$DRY_RUN" -eq 1 ]]; then
  EXTRA+=(--dry-run)
  echo "restore.sh: dry-run (pass --apply to download)"
else
  echo "restore.sh: APPLY downloads into MODELS_ROOT=${MODELS_ROOT:-models}"
fi

# Isolation: refuse comic tree
if [[ "${MODELS_ROOT:-}" == *ai-realistic-comic* ]] || [[ "${COMFYUI_ROOT:-}" == *ai-realistic-comic* ]]; then
  echo "Refusing paths under ai-realistic-comic/" >&2
  exit 2
fi

mkdir -p "${INPUT_ROOT:-./input}/cats/A/raw" "${INPUT_ROOT:-./input}/cats/B/raw" "${INPUT_ROOT:-./input}/cats/C/raw" \
  "${INPUT_ROOT:-./input}/shots" "${OUTPUT_ROOT:-./output}/i2v" "${OUTPUT_ROOT:-./output}/flf2v" "${OUTPUT_ROOT:-./output}/exports"

python3 scripts/download_models.py "${EXTRA[@]}" "${GROUP_ARGS[@]}" \
  ${MODELS_ROOT:+--models-root "$MODELS_ROOT"}

echo "Done. Next: open workflow JSON under workflow/ in ComfyUI."
