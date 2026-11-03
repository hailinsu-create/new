#!/usr/bin/env bash
# Restore / sync SFW weights for cat-anthropomorph-video ComfyUI pipelines.
# Default: dry-run. Does not boot AutoDL, recharge, or touch ai-realistic-comic/.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT"

if [[ -f .env && "${CAT_ANTHRO_SKIP_ENV:-0}" != "1" ]]; then
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
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --group (looklock|i2v|flf2v)" >&2
        exit 1
      fi
      case "$2" in
        looklock|i2v|flf2v) ;;
        *)
          echo "Unknown group: $2 (expected looklock|i2v|flf2v)" >&2
          exit 1
          ;;
      esac
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

SELECTED_GROUPS=()
for ((idx = 0; idx < ${#GROUP_ARGS[@]}; idx += 2)); do
  SELECTED_GROUPS+=("${GROUP_ARGS[$((idx + 1))]}")
done

group_selected() {
  local needle="$1" g
  for g in "${SELECTED_GROUPS[@]}"; do
    if [[ "$g" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

# Fail closed: an explicit looklock selection is never rewritten to i2v here.
if group_selected looklock; then
  echo "[precision] Qwen looklock default UNET = qwen_image_edit_2511_fp8mixed.safetensors (fp8mixed OK)."
  echo "[precision] Do NOT add --force-fp16 on Qwen (black-image risk)."
  echo "[precision] Never --use-sage-attention."
  echo "[precision] Lightning 4steps LoRA: optional speed only; only with fp8mixed base; never stack on a fused lightning checkpoint; quality default OFF."
  echo "[precision] Wan2.1 I2V/FLF2V remain fp16 (separate policy)."
fi

refuse_comic() {
  local name="$1"
  local value="${2:-}"
  if [[ "$value" == *ai-realistic-comic* ]]; then
    echo "Refusing ${name} under ai-realistic-comic/: ${value}" >&2
    exit 2
  fi
}

refuse_comic MODELS_ROOT "${MODELS_ROOT:-}"
refuse_comic COMFYUI_ROOT "${COMFYUI_ROOT:-}"
refuse_comic INPUT_ROOT "${INPUT_ROOT:-}"
refuse_comic OUTPUT_ROOT "${OUTPUT_ROOT:-}"

INPUT_ROOT="${INPUT_ROOT:-./input}"
OUTPUT_ROOT="${OUTPUT_ROOT:-./output}"
REFS_CATS="${ROOT}/refs/cats"

mkdir -p \
  "${REFS_CATS}/A" \
  "${REFS_CATS}/B" \
  "${REFS_CATS}/C" \
  "${INPUT_ROOT}/cats/A/raw" \
  "${INPUT_ROOT}/cats/B/raw" \
  "${INPUT_ROOT}/cats/C/raw" \
  "${INPUT_ROOT}/looklock" \
  "${INPUT_ROOT}/shots" \
  "${OUTPUT_ROOT}/i2v" \
  "${OUTPUT_ROOT}/flf2v" \
  "${OUTPUT_ROOT}/exports"

sync_ref_photos() {
  local cat="$1"
  local src_dir="${REFS_CATS}/${cat}"
  local dest_dir="${INPUT_ROOT}/cats/${cat}/raw"
  local candidates=()
  local src dest name

  shopt -s nullglob
  candidates=("${src_dir}/front.jpg" "${src_dir}"/cat-*.jpg)
  shopt -u nullglob

  for src in "${candidates[@]}"; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"
    dest="${dest_dir}/${name}"
    if [[ -e "$dest" || -L "$dest" ]]; then
      echo "restore.sh: skip existing ${dest}"
      continue
    fi
    if cp -p "$src" "$dest" 2>/dev/null; then
      echo "restore.sh: copied ${src} -> ${dest}"
    elif ln -s "$(cd "$(dirname "$src")" && pwd)/${name}" "$dest" 2>/dev/null; then
      echo "restore.sh: symlinked ${src} -> ${dest}"
    else
      echo "restore.sh: failed to sync ${src} -> ${dest}" >&2
      exit 1
    fi
  done
}

for cat in A B C; do
  sync_ref_photos "$cat"
done

CMD=(python3 scripts/download_models.py "${GROUP_ARGS[@]}" --require-sha256)
if [[ "$DRY_RUN" -eq 1 ]]; then
  CMD+=(--dry-run)
  echo "restore.sh: dry-run (pass --apply to download)"
else
  echo "restore.sh: APPLY downloads into MODELS_ROOT=${MODELS_ROOT:-models}"
fi
if [[ -n "${MODELS_ROOT:-}" ]]; then
  CMD+=(--models-root "$MODELS_ROOT")
fi

"${CMD[@]}"

echo "[remind] 权重 sha256 必验（禁 size-only）；缺 sha256 的 apply 会被拒绝；--no-require-sha256 仅显式降级。"
echo "[remind] Wan 侧默认 UNET=fp16；fp8_e4m3fn 仅 VRAM 回退，最低档、易噪，不推荐。"
if group_selected looklock; then
  echo "[remind] Qwen looklock 默认 fp8mixed（OK）；不要对 Qwen 加 --force-fp16（黑图风险）。"
fi
echo "[remind] ComfyUI 禁止 --use-sage-attention（Wan I2V 黑废，ComfyUI#8573）；可选 --force-upcast-attention（#6987）。"
echo "Done. Next: open workflow JSON under workflow/ in ComfyUI."
