#!/usr/bin/env bash
# assemble_v0.4.sh — Normandy 15s ¥0 包装（Phase6 五镜；不开机）
# 刀表：K01 0.0–0.9 · K02 0.9–1.7 · M04 1.7–4.2 (DROP~3.60) · M05 4.2–6.6
#       M08 6.6–8.7 · M09 8.7–9.8 (炮火~9.20) · M10 9.8–13.2 (插旗~12.80) · KEND 13.2–15.0
# BGM: Determined Pursuit (Emma_MA, CC0). 禁 NSFW / grok / AutoDL 开机.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="$ROOT/outputs"
OUT_DIR="$BASE/v0.4-b0-01-2026-10-28"
EDIT="$OUT_DIR/edit"
SRC="$OUT_DIR/src"
FINAL_DIR="$OUT_DIR/out"
V032_EDIT="$BASE/v0.3.2-b0-01-2026-10-28/edit"
SFX_DIR="$BASE/v0.2-b0-01-2026-10-26/edit/sfx"
P6="$BASE/h3-phase6-2026-10-28"
STILLS_V04="$BASE/cursor-stills-v0.4-2026-10-28"
STILLS_LL="$BASE/cursor-stills-looklock-v0.3.1"
mkdir -p "$EDIT" "$SRC" "$FINAL_DIR"

CAT="$ROOT/refs/cats/A/front.jpg"
[[ -f "$CAT" ]] || CAT="$ROOT/refs/cats/cat-A-ginger-white.jpg"

PORTRAIT="$STILLS_V04/portrait/master_looklock.jpg"
[[ -f "$PORTRAIT" ]] || PORTRAIT="$STILLS_LL/portrait/master_looklock.jpg"
# Prefer flag-holding still for K02 if present
if [[ -f "$STILLS_V04/door_crowd/M04_door_crowd_start.jpg" ]]; then
  FLAG_STILL="$STILLS_V04/door_crowd/M04_door_crowd_start.jpg"
else
  FLAG_STILL="$PORTRAIT"
fi

BGM_FULL="$V032_EDIT/determined_pursuit_loop_emma_ma_cc0.wav"
BGM_15="$V032_EDIT/bgm_primary_15s.wav"
BGM_SS=14.4

M04="$P6/h3_phase6_M04_door_crowd_00001_.mp4"
M05="$P6/h3_phase6_M05_wade_flag_00001_.mp4"
M08="$P6/h3_phase6_M08_mass_charge_00001_.mp4"
M09="$P6/h3_phase6_M09_artillery_00001_.mp4"
M10="$P6/h3_phase6_M10_flag_plant_00001_.mp4"

echo "[v0.4] sources M04=$M04 M05=$M05 M08=$M08 M09=$M09 M10=$M10"
echo "[v0.4] portrait=$PORTRAIT flag_still=$FLAG_STILL cat=$CAT"

for f in "$M04" "$M05" "$M08" "$M09" "$M10" "$CAT" "$PORTRAIT" "$FLAG_STILL"; do
  [[ -f "$f" ]] || { echo "MISSING $f"; exit 2; }
done

W=1080; H=1920; FPS=24
FONT="/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"

GRADE="colorbalance=rs=0.04:gs=0.01:bs=-0.03:rm=0.03:gm=0.01:bm=-0.02:rh=0.02:bh=-0.01,eq=saturation=0.94:gamma=1.02:contrast=1.02"

kburn() {
  local img="$1" out="$2" dur="$3" zexpr="$4"
  local frames; frames=$(python3 -c "print(int(round($dur*$FPS)))")
  ffmpeg -y -nostdin -loop 1 -i "$img" \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},zoompan=z='${zexpr}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${frames}:s=${W}x${H}:fps=${FPS},${GRADE}" \
    -frames:v "$frames" -pix_fmt yuv420p -an "$out"
}

scale_trim() {
  ffmpeg -y -nostdin -ss "$3" -i "$1" -t "$4" \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},setsar=1,fps=${FPS},${GRADE}" \
    -an -pix_fmt yuv420p "$2"
}

# Knee-up crop for wade/charge (hide feet)
scale_trim_knee() {
  ffmpeg -y -nostdin -ss "$3" -i "$1" -t "$4" \
    -vf "scale=${W}:${H}:force_original_aspect_ratio=increase,scale=iw*1.12:ih*1.12,crop=${W}:${H}:(iw-${W})/2:0,setsar=1,fps=${FPS},${GRADE}" \
    -an -pix_fmt yuv420p "$2"
}

echo "[v0.4] hooks K01/K02..."
# K01 0.9s
kburn "$CAT" "$EDIT/k_cat.mp4" 0.90 "min(1.10,1+0.0008*on)"
if [[ -f "$FONT" ]]; then
  ffmpeg -y -nostdin -i "$EDIT/k_cat.mp4" \
    -vf "drawtext=fontfile=${FONT}:text='1944·诺曼底':fontcolor=white:fontsize=56:x=(w-text_w)/2:y=h*0.82:shadowcolor=black@0.6:shadowx=2:shadowy=2" \
    -an -pix_fmt yuv420p "$EDIT/k_cat_title.mp4" || cp "$EDIT/k_cat.mp4" "$EDIT/k_cat_title.mp4"
else
  cp "$EDIT/k_cat.mp4" "$EDIT/k_cat_title.mp4"
fi
# K02 0.8s — 定妆持旗静帧
kburn "$FLAG_STILL" "$EDIT/k_portrait.mp4" 0.80 "min(1.08,1+0.0005*on)"

echo "[v0.4] motion trims (Phase6)..."
# M04 2.5s: DROP at timeline 3.60 → 1.90s into clip.
# Prefer source mid where door is open (~ss 0.40 → relative DROP @ source ~2.30)
scale_trim "$M04" "$EDIT/m04.mp4" 0.40 2.50

# M05 2.4s wade+flag, knee crop
scale_trim_knee "$M05" "$EDIT/m05.mp4" 0.50 2.40

# M08 2.1s mass charge, knee crop
scale_trim_knee "$M08" "$EDIT/m08.mp4" 0.60 2.10

# M09 1.1s artillery; boom at 9.20 = 0.50s into clip → put explosion mid-source
# Source explosion strong around ~2.0–3.0; take ss=1.80 t=1.10 so boom ~rel 0.50
scale_trim "$M09" "$EDIT/m09.mp4" 1.80 1.10

# M10 3.4s flag plant; plant at 12.80 = 3.00s into clip
# Source ~5.17; take ss=1.00 t=3.40 → plant near end (~source 4.0)
scale_trim "$M10" "$EDIT/m10.mp4" 1.00 3.40

# KEND: freeze last M10 + title 1.8s
M10_DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$EDIT/m10.mp4")
M10_LAST=$(python3 -c "print(max(0, float('$M10_DUR')-0.08))")
ffmpeg -y -nostdin -ss "$M10_LAST" -i "$EDIT/m10.mp4" -vframes 1 "$EDIT/flag_hold_frame.png"
cp "$EDIT/flag_hold_frame.png" "$EDIT/end_frame.png"
kburn "$EDIT/end_frame.png" "$EDIT/k_end_base.mp4" 1.80 "1"
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
file '$EDIT/m04.mp4'
file '$EDIT/m05.mp4'
file '$EDIT/m08.mp4'
file '$EDIT/m09.mp4'
file '$EDIT/m10.mp4'
file '$EDIT/k_end.mp4'
LISTEOF

SILENT="$FINAL_DIR/B0-01-normandy-v0.4.silent.mp4"
FINAL="$FINAL_DIR/B0-01-normandy-v0.4.mp4"
ffmpeg -y -nostdin -f concat -safe 0 -i "$LIST" -c:v libx264 -pix_fmt yuv420p -r $FPS -movflags +faststart -an "$SILENT"
echo "[v0.4] silent -> $SILENT"
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$SILENT")
echo "[v0.4] silent duration=$DUR"

echo "[v0.4] audio bed + SFX..."
if [[ ! -f "$BGM_15" && -f "$BGM_FULL" ]]; then
  ffmpeg -y -nostdin -ss "$BGM_SS" -i "$BGM_FULL" -t 15 -ac 2 -ar 44100 "$BGM_15"
fi
[[ -f "$BGM_15" ]] || { echo "NO BGM"; exit 3; }

EDIT="$EDIT" python3 - <<'PY'
import subprocess, os
edit = os.environ["EDIT"]
clips = [
  "k_cat_title.mp4","k_portrait.mp4","m04.mp4","m05.mp4",
  "m08.mp4","m09.mp4","m10.mp4","k_end.mp4"
]
t = 0.0
marks = {}
lines = []
for c in clips:
  p = os.path.join(edit, c)
  d = float(subprocess.check_output([
    "ffprobe","-v","error","-show_entries","format=duration","-of","csv=p=0",p
  ], text=True).strip())
  marks[c] = (t, t+d, d)
  lines.append(f"{c}\t{t:.4f}\t{t+d:.4f}\t{d:.4f}")
  t += d
lines.append(f"TOTAL\t0.0000\t{t:.4f}\t{t:.4f}")
open(os.path.join(edit,"sfx_timeline.txt"),"w").write("\n".join(lines)+"\n")
open(os.path.join(edit,"clip_marks.tsv"),"w").write(
  "\n".join(f"{k}\t{a:.4f}\t{b:.4f}\t{c:.4f}" for k,(a,b,c) in marks.items())+"\n"
)
m04_s, m04_e, _ = marks["m04.mp4"]
m05_s, _, _ = marks["m05.mp4"]
m08_s, _, _ = marks["m08.mp4"]
m09_s, _, _ = marks["m09.mp4"]
m10_s, _, _ = marks["m10.mp4"]
# Target locks (±0.15): DROP 3.60, BOOM 9.20, FLAG 12.80
# Use planned absolute times if clip starts allow; else clamp into segment
drop_at = max(m04_s + 0.15, min(m04_e - 0.15, 3.60))
boom_at = max(m09_s + 0.10, min(marks["m09.mp4"][1] - 0.10, 9.20))
flag_at = max(m10_s + 0.20, min(marks["m10.mp4"][1] - 0.20, 12.80))
open(os.path.join(edit,"sfx_cue_times.env"),"w").write(
  f"DROP_AT={drop_at:.3f}\n"
  f"SLAM_AT={drop_at:.3f}\n"
  f"SPLASH_AT={m05_s:.3f}\n"
  f"WHOOSH_AT={m08_s+0.05:.3f}\n"
  f"HIT_AT={m08_s+0.55:.3f}\n"
  f"BOOM_AT={boom_at:.3f}\n"
  f"FLAG1_AT={flag_at:.3f}\n"
  f"FLAG2_AT={marks['m10.mp4'][1]-0.15:.3f}\n"
  f"M04_S={m04_s:.3f}\n"
  f"M09_S={m09_s:.3f}\n"
  f"M10_S={m10_s:.3f}\n"
  f"TOTAL={t:.3f}\n"
)
print("\n".join(lines))
print(f"DROP={drop_at:.3f} BOOM={boom_at:.3f} FLAG={flag_at:.3f}")
print("cues written")
PY

set -a
# shellcheck disable=SC1090
source "$EDIT/sfx_cue_times.env"
set +a
echo "[v0.4] DROP_AT=$DROP_AT BOOM_AT=$BOOM_AT FLAG1_AT=$FLAG1_AT TOTAL=$TOTAL"

adelay_ms() { python3 -c "print(int(round(float('$1')*1000)))"; }

mix_inputs=()

ffmpeg -y -nostdin -i "$BGM_15" -t "$DUR" -ac 2 -ar 44100 "$EDIT/bgm_trim.wav"
# Mild duck around DROP (±0.25s) so SFX punch
ffmpeg -y -nostdin -i "$EDIT/bgm_trim.wav" \
  -af "volume=enable='between(t,${DROP_AT}-0.25,${DROP_AT}+0.15)':volume=0.35,volume=0.85" \
  "$EDIT/bgm_ducked.wav"
mix_inputs+=(-i "$EDIT/bgm_ducked.wav")

place_sfx() {
  local wav="$1" at="$2" vol="$3" outname="$4"
  local ms; ms=$(adelay_ms "$at")
  ffmpeg -y -nostdin -i "$wav" -ar 44100 -ac 2 \
    -af "volume=${vol},adelay=${ms}|${ms},apad=whole_dur=${DUR}" \
    -t "$DUR" "$EDIT/${outname}.wav"
  mix_inputs+=(-i "$EDIT/${outname}.wav")
}

if [[ -f "$SFX_DIR/slam.wav" ]]; then place_sfx "$SFX_DIR/slam.wav" "$SLAM_AT" 1.4 sfx_slam; fi
if [[ -f "$SFX_DIR/splash.wav" ]]; then place_sfx "$SFX_DIR/splash.wav" "$SPLASH_AT" 1.2 sfx_splash; fi
if [[ -f "$SFX_DIR/whoosh.wav" ]]; then place_sfx "$SFX_DIR/whoosh.wav" "$WHOOSH_AT" 0.9 sfx_whoosh; fi
if [[ -f "$SFX_DIR/hit.wav" ]]; then place_sfx "$SFX_DIR/hit.wav" "$HIT_AT" 1.0 sfx_hit; fi
if [[ -f "$SFX_DIR/boom.wav" ]]; then place_sfx "$SFX_DIR/boom.wav" "$BOOM_AT" 1.6 sfx_boom; fi
if [[ -f "$SFX_DIR/flagwind.wav" ]]; then
  place_sfx "$SFX_DIR/flagwind.wav" "$FLAG1_AT" 0.85 sfx_flag1
  place_sfx "$SFX_DIR/flagwind.wav" "$FLAG2_AT" 0.65 sfx_flag2
fi

# Optional ducked H3 native beds
ffmpeg -y -nostdin -ss 0.50 -i "$M05" -t 2.40 -vn -ac 2 -ar 44100 "$EDIT/h3_m05_aud.wav" || true
ffmpeg -y -nostdin -ss 0.60 -i "$M08" -t 2.10 -vn -ac 2 -ar 44100 "$EDIT/h3_m08_aud.wav" || true
ffmpeg -y -nostdin -ss 1.80 -i "$M09" -t 1.10 -vn -ac 2 -ar 44100 "$EDIT/h3_m09_aud.wav" || true
ffmpeg -y -nostdin -ss 1.00 -i "$M10" -t 3.40 -vn -ac 2 -ar 44100 "$EDIT/h3_m10_aud.wav" || true
[[ -f "$EDIT/h3_m05_aud.wav" ]] && place_sfx "$EDIT/h3_m05_aud.wav" "$SPLASH_AT" 0.20 h3bed_m05
[[ -f "$EDIT/h3_m08_aud.wav" ]] && place_sfx "$EDIT/h3_m08_aud.wav" "$WHOOSH_AT" 0.18 h3bed_m08
[[ -f "$EDIT/h3_m09_aud.wav" ]] && place_sfx "$EDIT/h3_m09_aud.wav" "$M09_S" 0.25 h3bed_m09
[[ -f "$EDIT/h3_m10_aud.wav" ]] && place_sfx "$EDIT/h3_m10_aud.wav" "$M10_S" 0.15 h3bed_m10

nfiles=$(( ${#mix_inputs[@]} / 2 ))
echo "[v0.4] mixing $nfiles audio stems..."
ffmpeg -y -nostdin "${mix_inputs[@]}" \
  -filter_complex "amix=inputs=${nfiles}:duration=first:dropout_transition=0:normalize=0,volume=1.05,alimiter=limit=0.95" \
  -ac 2 -ar 44100 "$EDIT/mix_audio.wav"

ffmpeg -y -nostdin -i "$SILENT" -i "$EDIT/mix_audio.wav" \
  -c:v copy -c:a aac -b:a 160k -shortest -movflags +faststart "$FINAL"

printf '%s\n' \
  'BGM: "Determined Pursuit" by Emma_MA — OpenGameArt — CC0' \
  'https://opengameart.org/content/determined-pursuit-epic-orchestra-loop' \
  'SFX: lavfi/procedural CC0 stems reused from v0.2 (slam/splash/whoosh/hit/boom/flagwind)' \
  'H3 native audio beds: ducked under M05/M08/M09/M10 (phase6)' \
  > "$FINAL_DIR/audio-credits.md"

# CUTLIST snapshot
{
  echo "# CONTENT-CUTLIST v0.4 — $(date '+%Y-%m-%d %H:%M %z')"
  echo
  echo "| 段 | 计划秒 | 实际起 | 实际止 | 源 |"
  echo "|---|---:|---:|---:|---|"
  echo "| K01 | 0.0–0.9 | (见 clip_marks) | | 真猫 + 1944·诺曼底 |"
  echo "| K02 | 0.9–1.7 | | | 定妆持旗静帧 |"
  echo "| M04 | 1.7–4.2 | | | Phase6 M04；DROP≈${DROP_AT} |"
  echo "| M05 | 4.2–6.6 | | | Phase6 M05 |"
  echo "| M08 | 6.6–8.7 | | | Phase6 M08 |"
  echo "| M09 | 8.7–9.8 | | | Phase6 M09；炮火≈${BOOM_AT} |"
  echo "| M10 | 9.8–13.2 | | | Phase6 M10；插旗≈${FLAG1_AT} |"
  echo "| KEND | 13.2–15.0 | | | 定格 + Normandy 1944 · AI生成 |"
  echo
  echo "## clip_marks.tsv"
  echo '```'
  cat "$EDIT/clip_marks.tsv"
  echo '```'
  echo
  echo "## SFX cues"
  echo '```'
  cat "$EDIT/sfx_cue_times.env"
  echo '```'
} > "$OUT_DIR/CONTENT-CUTLIST-v0.4.md"
cp "$OUT_DIR/CONTENT-CUTLIST-v0.4.md" "$ROOT/reviews/CONTENT-CUTLIST-v0.4-2026-10-28.md" 2>/dev/null || true

ffprobe -v quiet -print_format json -show_format -show_streams "$FINAL" > "$FINAL.ffprobe.json"
echo "[v0.4] FINAL=$FINAL"
ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,width,height -of default=noprint_wrappers=1 "$FINAL"
echo ASSEMBLE_V04_DONE
