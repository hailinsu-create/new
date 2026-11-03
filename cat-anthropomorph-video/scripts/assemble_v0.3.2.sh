#!/usr/bin/env bash
# assemble_v0.3.2.sh — Normandy 15s ¥0精剪草案（对齐 reviews/*v0.3.2* 切刀）
# 本轮不开机；禁 NSFW。BGM: Determined Pursuit (Emma_MA, CC0).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/outputs"
OUT_DIR="$BASE/v0.3.2-b0-01-2026-10-28"
EDIT="$OUT_DIR/edit"
SRC="$OUT_DIR/src"
FINAL_DIR="$OUT_DIR/out"
mkdir -p "$EDIT" "$SRC" "$FINAL_DIR"

P4="$BASE/h3-phase4-2026-10-27"
STILLS="$BASE/cursor-stills-looklock-v0.3.1"
CAT="$ROOT/refs/cats/A/front.jpg"
[[ -f "$CAT" ]] || CAT="$ROOT/refs/cats/cat-A-ginger-white.jpg"
PORTRAIT="$STILLS/portrait/master_looklock.jpg"
[[ -f "$PORTRAIT" ]] || PORTRAIT="$STILLS/portrait/looklock_portrait_semi_chibi_A.jpg"
BOAT_STILL="$STILLS/boat_ramp/S04_boat_ramp_start.jpg"
BGM_FULL="$EDIT/determined_pursuit_loop_emma_ma_cc0.wav"
BGM_15="$EDIT/bgm_primary_15s.wav"
BGM_SS=14.4

S04="$P4/h3_phase4_S04_boat_ramp_00001_.mp4"
S05="$P4/h3_phase4_S05_wade_00001_.mp4"
S08="$P4/h3_phase4_S08_charge_00001_.mp4"
S10="$P4/h3_phase4_S10_flag_00001_.mp4"

for f in "$S04" "$S05" "$S08" "$S10" "$CAT" "$PORTRAIT" "$BOAT_STILL"; do
  [[ -f "$f" ]] || { echo "MISSING $f"; exit 2; }
done

W=1080; H=1920; FPS=24
FONT="/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"

kburn() {
  local img="$1" out="$2" dur="$3" zexpr="$4"
  local frames; frames=$(python3 -c "print(int(round($dur*$FPS)))")
  ffmpeg -y -nostdin -loop 1 -i "$img" \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},zoompan=z='${zexpr}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${W}x${H}:fps=${FPS}" \
    -frames:v "$frames" -pix_fmt yuv420p -an "$out"
}

scale_trim() {
  ffmpeg -y -nostdin -ss "$3" -i "$1" -t "$4" \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},setsar=1,fps=${FPS}" \
    -an -pix_fmt yuv420p "$2"
}

echo "[v0.3.2] hooks..."
kburn "$CAT" "$EDIT/k_cat.mp4" 1.0 "min(1.10,1+0.0008*on)"
if [[ -f "$FONT" ]]; then
  ffmpeg -y -nostdin -i "$EDIT/k_cat.mp4" \
    -vf "drawtext=fontfile=${FONT}:text='1944·诺曼底':fontcolor=white:fontsize=56:x=(w-text_w)/2:y=h*0.82:shadowcolor=black@0.6:shadowx=2:shadowy=2" \
    -an -pix_fmt yuv420p "$EDIT/k_cat_title.mp4" || cp "$EDIT/k_cat.mp4" "$EDIT/k_cat_title.mp4"
else
  cp "$EDIT/k_cat.mp4" "$EDIT/k_cat_title.mp4"
fi
kburn "$PORTRAIT" "$EDIT/k_portrait.mp4" 1.0 "min(1.08,1+0.0005*on)"
kburn "$BOAT_STILL" "$EDIT/k_boat.mp4" 0.5 "1"

echo "[v0.3.2] motion trims (cutlist)..."
# S04 + flash/shake on last 0.30s via split-concat
scale_trim "$S04" "$EDIT/s04_body.mp4" 0.90 2.00
scale_trim "$S04" "$EDIT/s04_tail_raw.mp4" 2.90 0.30
ffmpeg -y -nostdin -i "$EDIT/s04_tail_raw.mp4" \
  -vf "eq=brightness=0.25:saturation=1.15,rotate=0.012*sin(12*2*PI*t):c=white@0:ow=rotw(0.012):oh=roth(0.012),scale=${W}:${H},crop=${W}:${H},setsar=1,fps=${FPS}" \
  -an -pix_fmt yuv420p "$EDIT/s04_tail.mp4"
printf "file '%s'\nfile '%s'\n" "$EDIT/s04_body.mp4" "$EDIT/s04_tail.mp4" > "$EDIT/s04_concat.txt"
ffmpeg -y -nostdin -f concat -safe 0 -i "$EDIT/s04_concat.txt" -c:v libx264 -pix_fmt yuv420p -an "$EDIT/s04.mp4"

scale_trim "$S05" "$EDIT/s05.mp4" 1.00 2.30
scale_trim "$S08" "$EDIT/s08.mp4" 0.35 1.55
scale_trim "$S10" "$EDIT/s10.mp4" 0.80 4.00

# blast flash ~0.60s
ffmpeg -y -nostdin -f lavfi -i "color=c=white:s=${W}x${H}:d=0.60:r=${FPS}" \
  -vf "noise=alls=8:allf=t,rotate=0.01*sin(20*2*PI*t):c=white@0:ow=iw:oh=ih" \
  -frames:v 15 -pix_fmt yuv420p -an "$EDIT/fx_blast.mp4"

ffmpeg -y -nostdin -sseof -0.05 -i "$S10" -vframes 1 "$EDIT/end_frame.png"
kburn "$EDIT/end_frame.png" "$EDIT/k_end_base.mp4" 1.75 "1"
if [[ -f "$FONT" ]]; then
  ffmpeg -y -nostdin -i "$EDIT/k_end_base.mp4" \
    -vf "drawtext=fontfile=${FONT}:text='Normandy 1944 · AI生成':fontcolor=white:fontsize=48:x=(w-text_w)/2:y=h*0.78:shadowcolor=black@0.7:shadowx=2:shadowy=2" \
    -an -pix_fmt yuv420p "$EDIT/k_end.mp4" || cp "$EDIT/k_end_base.mp4" "$EDIT/k_end.mp4"
else
  cp "$EDIT/k_end_base.mp4" "$EDIT/k_end.mp4"
fi

LIST="$EDIT/concat.txt"
cat >"$LIST" <<LISTEOF
file '$EDIT/k_cat_title.mp4'
file '$EDIT/k_portrait.mp4'
file '$EDIT/k_boat.mp4'
file '$EDIT/s04.mp4'
file '$EDIT/s05.mp4'
file '$EDIT/s08.mp4'
file '$EDIT/fx_blast.mp4'
file '$EDIT/s10.mp4'
file '$EDIT/k_end.mp4'
LISTEOF

SILENT="$FINAL_DIR/B0-01-normandy-v0.3.2.silent.mp4"
FINAL="$FINAL_DIR/B0-01-normandy-v0.3.2.mp4"
ffmpeg -y -nostdin -f concat -safe 0 -i "$LIST" -c:v libx264 -pix_fmt yuv420p -r $FPS -movflags +faststart -an "$SILENT"
echo "[v0.3.2] silent -> $SILENT"

# ensure 15s BGM bed
if [[ ! -f "$BGM_15" && -f "$BGM_FULL" ]]; then
  ffmpeg -y -nostdin -ss "$BGM_SS" -i "$BGM_FULL" -t 15 -ac 2 -ar 44100 "$BGM_15"
fi
AUDIO_NOTE="silent (no BGM)"
if [[ -f "$BGM_15" ]]; then
  DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$SILENT")
  ffmpeg -y -nostdin -i "$BGM_15" -t "$DUR" -ac 2 -ar 44100 "$EDIT/bgm_trim.wav"
  ffmpeg -y -nostdin -i "$SILENT" -i "$EDIT/bgm_trim.wav" -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart "$FINAL"
  AUDIO_NOTE='CC0 Determined Pursuit by Emma_MA (OpenGameArt); bed ss=14.4'
  printf '%s\nURL: https://opengameart.org/content/determined-pursuit-epic-orchestra-loop\n' "$AUDIO_NOTE" > "$FINAL_DIR/audio-credits.md"
  echo "[v0.3.2] with audio -> $FINAL"
else
  cp -f "$SILENT" "$FINAL"
  echo "NO BGM bed; shipped silent" > "$FINAL_DIR/audio-credits.md"
fi
ffprobe -v quiet -print_format json -show_format -show_streams "$FINAL" > "$FINAL.ffprobe.json"
echo "AUDIO=$AUDIO_NOTE"
echo ASSEMBLE_V032_DONE
