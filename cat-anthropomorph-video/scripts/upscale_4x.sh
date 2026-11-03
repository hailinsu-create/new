#!/usr/bin/env bash
# v0.1g 4× upscale hook — template. Does NOT download weights.
# Prefer Comfy UpscaleModelLoader on box; this script is offline/ffmpeg fallback + path contract.
set -euo pipefail
SCALE=4
MODEL_PLACEHOLDER="${UPSCALE_MODEL_PATH:-upscale_models/4x-ClearRealityV1_PLACEHOLDER.pth}"
FFMPEG_FALLBACK=0
IN=""
OUT=""

usage() {
  cat <<EOF
Usage: $0 -i <image|video> -o <out> [--ffmpeg-lanczos]
  Env: UPSCALE_MODEL_PATH= path to 4x model on AutoDL disk (not in git)
  Default model placeholder: $MODEL_PLACEHOLDER
  Without --ffmpeg-lanczos: exits 2 if model file missing (safe for BOOT checklist).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i) IN="$2"; shift 2 ;;
    -o) OUT="$2"; shift 2 ;;
    --ffmpeg-lanczos) FFMPEG_FALLBACK=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$IN" && -n "$OUT" ]] || { usage; exit 1; }
[[ -f "$IN" ]] || { echo "[upscale_4x][FAIL] missing input: $IN" >&2; exit 1; }

if [[ -f "$MODEL_PLACEHOLDER" ]]; then
  echo "[upscale_4x][INFO] model present: $MODEL_PLACEHOLDER"
  echo "[upscale_4x][INFO] run Comfy ImageUpscaleWithModel on box (this hook only records contract)."
  echo "[upscale_4x][HINT] comfy out → $OUT (scale=${SCALE}x)"
  exit 0
fi

if [[ "$FFMPEG_FALLBACK" -eq 1 ]]; then
  command -v ffmpeg >/dev/null || { echo "[upscale_4x][FAIL] ffmpeg missing" >&2; exit 1; }
  mkdir -p "$(dirname "$OUT")"
  # Image: scale iw*4; video: same. Lanczos is a stand-in, not ClearReality.
  ffmpeg -nostdin -v error -y -i "$IN" -vf "scale=iw*${SCALE}:ih*${SCALE}:flags=lanczos" "$OUT"
  echo "[upscale_4x][WARN] used ffmpeg lanczos fallback (model missing). Prefer real 4x model on boot."
  exit 0
fi

echo "[upscale_4x][FAIL] model not on disk: $MODEL_PLACEHOLDER" >&2
echo "[upscale_4x][HINT] place SFW 4x model on AutoDL or re-run with --ffmpeg-lanczos" >&2
exit 2
