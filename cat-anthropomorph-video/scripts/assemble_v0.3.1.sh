#!/usr/bin/env bash
# assemble_v0.3.1.sh — Normandy ~15s vertical from NEW looklock H3 S04/S05/S08/S10
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/outputs"
OUT_DIR="$BASE/v0.3.1-b0-01-2026-10-27"
EDIT="$OUT_DIR/edit"
SRC="$OUT_DIR/src"
FINAL_DIR="$OUT_DIR/out"
mkdir -p "$EDIT" "$SRC" "$FINAL_DIR"

P4="$BASE/h3-phase4-2026-10-27"
STILLS="$BASE/cursor-stills-looklock-v0.3.1"
CAT="$ROOT/refs/cats/cat-A-ginger-white.jpg"
[[ -f "$CAT" ]] || CAT="$ROOT/refs/cats/A/front.jpg"
PORTRAIT="$STILLS/portrait/master_looklock.jpg"
[[ -f "$PORTRAIT" ]] || PORTRAIT="$STILLS/portrait/looklock_portrait_semi_chibi_A.jpg"
BOAT_STILL="$STILLS/boat_ramp/S04_boat_ramp_start.jpg"
BGM_SRC="$BASE/v0.1f-b0-01-2026-10-25/edit/horde_war_drums_by_william_hector.wav"
[[ -f "$BGM_SRC" ]] || BGM_SRC="$BASE/v0.1f-b0-01-2026-10-25/edit/bgm_cc0_war_drums.wav"

find_clip() {
  local pat="$1"
  local f
  f=$(ls "$P4"/$pat 2>/dev/null | head -1 || true)
  if [[ -z "${f:-}" ]]; then
    f=$(find "$P4" -name "$pat" 2>/dev/null | head -1 || true)
  fi
  echo "$f"
}

S04=$(find_clip 'h3_phase4_S04_boat_ramp*.mp4')
[[ -z "$S04" ]] && S04=$(find_clip '*S04*.mp4')
S05=$(find_clip 'h3_phase4_S05_wade*.mp4')
[[ -z "$S05" ]] && S05=$(find_clip '*S05*.mp4')
S08=$(find_clip 'h3_phase4_S08_charge*.mp4')
[[ -z "$S08" ]] && S08=$(find_clip '*S08*.mp4')
S10=$(find_clip 'h3_phase4_S10_flag*.mp4')
[[ -z "$S10" ]] && S10=$(find_clip '*S10*.mp4')

echo "[v0.3.1] S04=$S04"
echo "[v0.3.1] S05=$S05"
echo "[v0.3.1] S08=$S08"
echo "[v0.3.1] S10=$S10"

for f in "$S04" "$S05" "$S08" "$S10" "$CAT" "$PORTRAIT" "$BOAT_STILL"; do
  [[ -n "$f" && -f "$f" ]] || { echo "MISSING $f"; exit 2; }
done

# copy sources for audit
cp -f "$S04" "$SRC/$(basename "$S04")"
cp -f "$S05" "$SRC/$(basename "$S05")"
cp -f "$S08" "$SRC/$(basename "$S08")"
cp -f "$S10" "$SRC/$(basename "$S10")"

W=1080; H=1920; FPS=24

kburn() {
  local img="$1" out="$2" dur="$3" zexpr="$4"
  local frames
  frames=$(python3 -c "print(int(round($dur*$FPS)))")
  ffmpeg -y -nostdin -loop 1 -i "$img" \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},zoompan=z='${zexpr}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${W}x${H}:fps=${FPS}" \
    -frames:v "$frames" -pix_fmt yuv420p -an "$out"
}

scale_trim() {
  local ss="$3" dur="$4"
  ffmpeg -y -nostdin -ss "$ss" -i "$1" -t "$dur" \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},setsar=1,fps=${FPS}" \
    -an -pix_fmt yuv420p "$2"
}

echo "[v0.3.1] building still hooks..."
kburn "$CAT" "$EDIT/k_cat.mp4" 1.2 "min(1.10,1+0.0007*on)"
ffmpeg -y -nostdin -i "$EDIT/k_cat.mp4" -vf "drawtext=fontfile=/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc:text='1944·诺曼底':fontcolor=white:fontsize=56:x=(w-text_w)/2:y=h*0.82:shadowcolor=black@0.6:shadowx=2:shadowy=2" \
  -an -pix_fmt yuv420p "$EDIT/k_cat_title.mp4" || cp "$EDIT/k_cat.mp4" "$EDIT/k_cat_title.mp4"

kburn "$PORTRAIT" "$EDIT/k_portrait.mp4" 1.3 "min(1.08,1+0.0005*on)"
kburn "$BOAT_STILL" "$EDIT/k_boat.mp4" 1.0 "1"

echo "[v0.3.1] trimming motion clips..."
scale_trim "$S04" "$EDIT/s04.mp4" 1.0 2.5
scale_trim "$S05" "$EDIT/s05.mp4" 1.0 2.5
scale_trim "$S08" "$EDIT/s08.mp4" 1.0 2.5
scale_trim "$S10" "$EDIT/s10.mp4" 1.0 2.5

ffmpeg -y -nostdin -sseof -0.05 -i "$S10" -vframes 1 "$EDIT/end_frame.png"
kburn "$EDIT/end_frame.png" "$EDIT/k_end_base.mp4" 1.5 "1"
ffmpeg -y -nostdin -i "$EDIT/k_end_base.mp4" \
  -vf "drawtext=fontfile=/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc:text='Normandy 1944 · AI生成':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=h*0.78:shadowcolor=black@0.7:shadowx=2:shadowy=2" \
  -an -pix_fmt yuv420p "$EDIT/k_end.mp4" || cp "$EDIT/k_end_base.mp4" "$EDIT/k_end.mp4"

LIST="$EDIT/concat.txt"
cat >"$LIST" <<EOF
file '$EDIT/k_cat_title.mp4'
file '$EDIT/k_portrait.mp4'
file '$EDIT/k_boat.mp4'
file '$EDIT/s04.mp4'
file '$EDIT/s05.mp4'
file '$EDIT/s08.mp4'
file '$EDIT/s10.mp4'
file '$EDIT/k_end.mp4'
EOF

SILENT="$FINAL_DIR/B0-01-normandy-v0.3.1.silent.mp4"
FINAL="$FINAL_DIR/B0-01-normandy-v0.3.1.mp4"

ffmpeg -y -nostdin -f concat -safe 0 -i "$LIST" -c:v libx264 -pix_fmt yuv420p -r $FPS -movflags +faststart -an "$SILENT"
echo "[v0.3.1] silent -> $SILENT"
ffprobe -v quiet -print_format json -show_format -show_streams "$SILENT" > "$SILENT.ffprobe.json"

AUDIO_NOTE="silent (no BGM mixed)"
if [[ -f "$BGM_SRC" ]]; then
  cp -f "$BGM_SRC" "$EDIT/bgm_cc0_war_drums.wav"
  DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$SILENT")
  ffmpeg -y -nostdin -stream_loop -1 -i "$EDIT/bgm_cc0_war_drums.wav" -t "$DUR" -ac 2 -ar 44100 "$EDIT/bgm_trim.wav"
  ffmpeg -y -nostdin -i "$SILENT" -i "$EDIT/bgm_trim.wav" -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart "$FINAL"
  AUDIO_NOTE="CC0 Horde War Drums by William Hector (OpenGameArt/CC0; reused from v0.1f)"
  echo "$AUDIO_NOTE" > "$FINAL_DIR/audio-credits.md"
  echo "[v0.3.1] with audio -> $FINAL"
else
  cp -f "$SILENT" "$FINAL"
  echo "NO local CC0 war drums found; shipped silent copy as v0.3.1" > "$FINAL_DIR/audio-credits.md"
  AUDIO_NOTE="silent; no local CC0 war drums"
fi
ffprobe -v quiet -print_format json -show_format -show_streams "$FINAL" > "$FINAL.ffprobe.json"
ls -la "$FINAL_DIR"
echo "AUDIO=$AUDIO_NOTE"
echo ASSEMBLE_V031_DONE
