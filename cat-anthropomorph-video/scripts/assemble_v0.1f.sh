#!/usr/bin/env bash
# assemble_v0.1f.sh — DRAFT ffmpeg scaffold for Opus A (¥0, no GPU).
# Does NOT ship a finished market-ready MV. BGM must be filled by operator.
# Usage (from cat-anthropomorph-video/):
#   bash scripts/assemble_v0.1f.sh
# Env overrides:
#   OUT_DIR  SRC_DIR  BGM  (default BGM=edit/bgm_PLACEHOLDER.wav — platform library / CC0 TBD)

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${OUT_DIR:-$ROOT/../outputs/v0.1f-b0-01-2026-10-25}"
# Prefer sibling outputs/ if present; else under ROOT
if [[ ! -d "$(dirname "$OUT_DIR")" ]]; then
  OUT_DIR="$ROOT/outputs/v0.1f-b0-01-2026-10-25"
fi
SRC_DIR="${SRC_DIR:-$OUT_DIR/src}"
EDIT_DIR="${EDIT_DIR:-$OUT_DIR/edit}"
BGM="${BGM:-$EDIT_DIR/bgm_PLACEHOLDER.wav}"
mkdir -p "$OUT_DIR/out" "$EDIT_DIR" "$SRC_DIR"

echo "[v0.1f] OUT_DIR=$OUT_DIR"
echo "[v0.1f] BGM path (MUST be platform-library export or CC0; do not commit pirated audio): $BGM"

if [[ ! -f "$BGM" ]]; then
  cat >&2 <<EOF
[v0.1f][STOP] Missing BGM: $BGM
Fill with:
  - Douyin / Xiaohongshu official library export for that platform only, or
  - CC0 / written-license wav
Then re-run. Refusing to invent copyrighted tracks.
EOF
  exit 2
fi

# --- placeholders: operator drops stills / clips into SRC_DIR ---
# Expected names (copy from v0.1e / refs; adjust as needed):
#   cat_front.jpg  looklock.png  boat.png
#   s04.mp4  s05.mp4  s06.mp4

need=(cat_front.jpg looklock.png boat.png s04.mp4 s05.mp4 s06.mp4)
missing=0
for f in "${need[@]}"; do
  if [[ ! -f "$SRC_DIR/$f" ]]; then
    echo "[v0.1f][WARN] missing $SRC_DIR/$f"
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  echo "[v0.1f][STOP] Drop source files into $SRC_DIR then re-run (see reviews/V0.1F-PLAN-2026-10-25.md)." >&2
  exit 2
fi

# Ken Burns still -> short clip (zoompan). Duration approx via frames.
kburn() {
  local img="$1" out="$2" dur="$3" zexpr="$4"
  ffmpeg -y -nostdin -loop 1 -i "$img" -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,zoompan=z='${zexpr}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=$((dur*30)):s=1080x1920:fps=30" \
    -t "$dur" -pix_fmt yuv420p -an "$out"
}

FLASH="$EDIT_DIR/flash_white.mp4"
ffmpeg -y -nostdin -f lavfi -i "color=c=white:s=1080x1920:d=0.07:r=30" -pix_fmt yuv420p -an "$FLASH"

kburn "$SRC_DIR/cat_front.jpg" "$EDIT_DIR/k1.mp4" 0.7 "min(1.12,1+0.001*on)"
kburn "$SRC_DIR/looklock.png" "$EDIT_DIR/k2.mp4" 0.7 "1"
kburn "$SRC_DIR/boat.png" "$EDIT_DIR/k3.mp4" 0.8 "min(1.08,1+0.0008*on)"

# Scale motion clips to 1080x1920 (letterbox/crop)
scale_clip() {
  ffmpeg -y -nostdin -i "$1" -vf "scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,setsar=1" \
    -an -pix_fmt yuv420p "$2"
}
scale_clip "$SRC_DIR/s04.mp4" "$EDIT_DIR/s04_1080.mp4"
scale_clip "$SRC_DIR/s05.mp4" "$EDIT_DIR/s05_1080.mp4"
scale_clip "$SRC_DIR/s06.mp4" "$EDIT_DIR/s06_1080.mp4"

# Concat list — coarse A-path order; trim in CapCut for beat-perfect cuts.
LIST="$EDIT_DIR/concat.txt"
cat >"$LIST" <<EOF
file '$EDIT_DIR/k1.mp4'
file '$FLASH'
file '$EDIT_DIR/k2.mp4'
file '$EDIT_DIR/k3.mp4'
file '$EDIT_DIR/s04_1080.mp4'
file '$EDIT_DIR/s05_1080.mp4'
file '$EDIT_DIR/s06_1080.mp4'
EOF

ROUGH="$EDIT_DIR/rough_silent.mp4"
ffmpeg -y -nostdin -f concat -safe 0 -i "$LIST" -c copy "$ROUGH" 2>/dev/null \
  || ffmpeg -y -nostdin -f concat -safe 0 -i "$LIST" -pix_fmt yuv420p -an "$ROUGH"

# Mux BGM with apad (do not shorten video)
OUT_AUD="$OUT_DIR/out/B0-01-normandy-v0.1f_ROUGH.mp4"
OUT_SIL="$OUT_DIR/out/B0-01-normandy-v0.1f_ROUGH_silent.mp4"
cp "$ROUGH" "$OUT_SIL"
ffmpeg -y -nostdin -i "$ROUGH" -i "$BGM" -filter_complex "[1:a]apad[a]" -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -shortest -t 15 "$OUT_AUD"

echo "[v0.1f] Wrote ROUGH (still needs CapCut beat trim / SFX / grade):"
echo "  $OUT_AUD"
echo "  $OUT_SIL"
echo "[v0.1f] Next: open in 剪映, apply V0.1F-PLAN 10-14 cuts + SFX/subs/grade, export final."
