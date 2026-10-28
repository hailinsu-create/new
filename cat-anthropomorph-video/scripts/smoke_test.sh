#!/usr/bin/env bash
# Offline smoke checks for cat-anthropomorph-video.
# Default and recommended mode: --dry-run. Never boots AutoDL or runs GPU work.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$ROOT"

DRY_RUN=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --run|--real|--apply)
      DRY_RUN=0
      shift
      ;;
    -h|--help)
      echo "Usage: bash scripts/smoke_test.sh [--dry-run|--run]"
      echo "Default is --dry-run. --run requires a real GPU + explicit authorization and is intentionally not automated."
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 64
      ;;
  esac
done

fail() {
  echo "[smoke][FAIL] $*" >&2
  exit 1
}

if [[ "$DRY_RUN" -eq 0 ]]; then
  if [[ "${AUTODL_BOOT_AUTHORIZED:-}" != "1" ]]; then
    echo "[smoke][FAIL] 非 dry-run 需要用户明确授权：export AUTODL_BOOT_AUTHORIZED=1（本脚本不会自动开机/充值）" >&2
    exit 2
  fi
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    echo "[smoke][FAIL] 非 dry-run 未检测到 GPU：nvidia-smi 不存在。请先开机并获授权，或改用 --dry-run。" >&2
    exit 3
  fi
  if ! nvidia-smi -L >/dev/null 2>&1; then
    echo "[smoke][FAIL] 非 dry-run 无法访问 GPU（nvidia-smi 失败）。请检查实例状态，或改用 --dry-run。" >&2
    exit 3
  fi
  echo "[smoke][FAIL] 本仓库只交付离线/dry-run 验收；真实 GPU 生成请按 README-PIPELINE P1 在 ComfyUI 手动执行。脚本不会假跑。" >&2
  exit 4
fi

for var in MODELS_ROOT COMFYUI_ROOT INPUT_ROOT OUTPUT_ROOT; do
  value="${!var:-}"
  if [[ "$value" == *ai-realistic-comic* ]]; then
    fail "${var} 指向 ai-realistic-comic/：${value}"
  fi
done

echo "[smoke] 1/13 解析 workflow JSON 并核对 manifest 权重 / sha256"
python3 - "$ROOT" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
manifest = json.loads((root / "manifest.json").read_text(encoding="utf-8"))
groups = manifest["groups"]

workflows = {
    "workflow/01_looklock_qwen_edit.json": {
        "groups": ["looklock"],
        "required": [
            "qwen_image_edit_2511_fp8mixed.safetensors",
            "qwen_2.5_vl_7b_fp8_scaled.safetensors",
            "qwen_image_vae.safetensors",
            "Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
        ],
    },
    "workflow/02_i2v_wan21_480p.json": {
        "groups": ["i2v"],
        "required": [
            "wan2.1_i2v_480p_14B_fp16.safetensors",
            "umt5_xxl_fp8_e4m3fn_scaled.safetensors",
            "wan_2.1_vae.safetensors",
            "clip_vision_h.safetensors",
        ],
        "require_fp16_unet": True,
    },
    "workflow/03_flf2v_wan21.json": {
        "groups": ["flf2v", "i2v"],
        "required": [
            "wan2.1_flf2v_720p_14B_fp16.safetensors",
            "umt5_xxl_fp8_e4m3fn_scaled.safetensors",
            "wan_2.1_vae.safetensors",
            "clip_vision_h.safetensors",
        ],
        "require_fp16_unet": True,
    },
}

errors: list[str] = []
for rel, spec in workflows.items():
    path = root / rel
    text = path.read_text(encoding="utf-8")
    try:
        payload = json.loads(text)
    except json.JSONDecodeError as exc:
        errors.append(f"{rel}: invalid JSON: {exc}")
        continue

    allowed: set[str] = set()
    for group in spec["groups"]:
        for weight in groups[group].get("weights", []):
            allowed.add(weight["filename"])

    found = set(re.findall(r"[A-Za-z0-9._-]+\.safetensors", text))
    unexpected = sorted(found - allowed)
    if unexpected:
        errors.append(f"{rel}: weights not in manifest groups {spec['groups']}: {unexpected}")

    for name in spec["required"]:
        if name not in found:
            errors.append(f"{rel}: missing required weight {name}")

    if spec.get("require_fp16_unet"):
        unet_nodes = [node for node in payload.get("nodes", []) if node.get("type") == "UNETLoader"]
        if not unet_nodes:
            errors.append(f"{rel}: missing UNETLoader node")
        else:
            unet_names = [str((node.get("widgets_values") or [""])[0]) for node in unet_nodes]
            has_fp16 = any("fp16" in name for name in unet_names)
            only_fp8 = any("fp8_e4m3fn" in name for name in unet_names) and not has_fp16
            if only_fp8:
                errors.append(f"{rel}: UNETLoader is fp8_e4m3fn only (expected fp16): {unet_names}")
            if not has_fp16:
                errors.append(f"{rel}: UNETLoader does not point at fp16: {unet_names}")

    if rel == "workflow/01_looklock_qwen_edit.json":
        nodes = {node.get("id"): node for node in payload.get("nodes", [])}
        front_path = str((nodes.get(41, {}).get("widgets_values") or [""])[0])
        costume_path = str((nodes.get(83, {}).get("widgets_values") or [""])[0])
        if front_path != "cats/A/raw/front.jpg":
            errors.append(f"{rel}: LoadImage #41 default is {front_path!r}, expected 'cats/A/raw/front.jpg'")
        if costume_path != "looklock/costume_ref_PLACEHOLDER.png":
            errors.append(f"{rel}: LoadImage #83 default is {costume_path!r}, expected costume placeholder")

        inner = {}
        for subgraph in payload.get("definitions", {}).get("subgraphs", []):
            for node in subgraph.get("nodes", []):
                inner[node.get("id")] = node
        prompt = str((inner.get(151, {}).get("widgets_values") or [""])[0])
        if "furniture" in prompt.lower():
            errors.append(f"{rel}: positive prompt still uses the official furniture demo")
        for token in ("orange-and-white", "Normandy", "US infantry", "SFW", "no weapons"):
            if token.lower() not in prompt.lower():
                errors.append(f"{rel}: positive prompt missing {token!r}")
        if inner.get(168, {}).get("widgets_values") != [False]:
            errors.append(f"{rel}: 'Enable 4steps LoRA?' must stay false for the quality gate")
        turbo = nodes.get(170, {})
        if isinstance(turbo.get("widgets_values"), list) and any(v is True for v in turbo["widgets_values"]):
            errors.append(f"{rel}: enable_turbo_mode must stay false")

    print(f"[smoke]   {rel}: {len(found)} weight filenames, all within manifest")

    if rel == "workflow/02_i2v_wan21_480p.json":
        nodes = {node.get("id"): node for node in payload.get("nodes", [])}
        wan = nodes.get(50, {})
        vals = wan.get("widgets_values") or []
        if len(vals) < 3 or int(vals[2]) != 49:
            errors.append(
                f"{rel}: WanImageToVideo.length expected 49, got "
                f"{vals[2] if len(vals) > 2 else None}"
            )
        pos = str((nodes.get(6, {}).get("widgets_values") or [""])[0]).lower()
        for token in ("gentle", "slightly", "subtle"):
            if re.search(rf"\b{re.escape(token)}\b", pos):
                errors.append(f"{rel}: positive prompt still has soft word {token!r}")
        if re.search(r"\bsmall\b", pos):
            errors.append(f"{rel}: positive prompt still has soft word 'small'")
        if "salute" not in pos and "raises" not in pos:
            errors.append(f"{rel}: positive prompt missing salute/raises strong verb")
        if "fixed camera" not in pos:
            errors.append(f"{rel}: positive prompt missing Fixed camera")
        neg = str((nodes.get(7, {}).get("widgets_values") or [""])[0]).lower()
        for need in ("static", "still picture", "frozen", "motionless", "no motion", "静止不动"):
            if need.lower() not in neg:
                errors.append(f"{rel}: negative missing {need!r}")


checksum_policy = manifest.get("checksum_policy") or {}
if checksum_policy.get("algorithm") != "sha256":
    errors.append("manifest.checksum_policy.algorithm must be sha256")
if checksum_policy.get("size_only") != "forbidden":
    errors.append("manifest.checksum_policy.size_only must be forbidden")

hashed = 0
for gname, group in groups.items():
    for weight in group.get("weights") or []:
        name = weight.get("filename") or weight.get("id")
        value = str(weight.get("sha256") or "")
        if not re.fullmatch(r"[0-9a-f]{64}", value):
            errors.append(f"manifest {gname}/{name}: missing or invalid sha256")
        else:
            hashed += 1

i2v_gates = groups["i2v"]["motion_policy"]["gates"]
if i2v_gates.get("G2") != "scripts/subject_gate.py":
    errors.append("manifest i2v gates.G2 must point at scripts/subject_gate.py")
if i2v_gates.get("status_model") != "scripts/clip_status.py":
    errors.append("manifest i2v gates.status_model must point at scripts/clip_status.py")
if "HUMAN_ACCEPTED" not in (i2v_gates.get("usable_clip_requires") or []):
    errors.append("manifest usable_clip_requires must include HUMAN_ACCEPTED")

if errors:
    for err in errors:
        print(f"[smoke][FAIL] {err}", file=sys.stderr)
    sys.exit(1)
print(f"[smoke]   manifest sha256 字段齐全：{hashed} 个权重；G2/G2m/status 已挂载")
PY

echo "[smoke] 2/13 检查三猫定妆卡"
for name in 小橘 银宝 墨墨; do
  grep -q "$name" prompts/look_cards.md || fail "prompts/look_cards.md 缺少名字：${name}"
done
if grep -q '\[待补\]' prompts/look_cards.md; then
  fail "prompts/look_cards.md 仍含 [待补]"
fi
echo "[smoke]   A小橘 / B银宝 / C墨墨 已锁定"

echo "[smoke] 3/13 检查 CHARACTER-LOCK 与 refs/cats"
LOCK_DOC="CHARACTER-LOCK-2026-10-24.md"
[[ -f "$LOCK_DOC" ]] || fail "缺少定妆锁定文档：${LOCK_DOC}"
for name in 小橘 银宝 墨墨; do
  grep -q "$name" "$LOCK_DOC" || fail "${LOCK_DOC} 缺少名字：${name}"
done
for id in 9b4c40bda6-dad38bb9 bb8c4f8e12-00c8bdac; do
  grep -q "$id" "$LOCK_DOC" || fail "${LOCK_DOC} 缺少实例 ID：${id}"
done
for cat in A B C; do
  [[ -d "refs/cats/${cat}" ]] || fail "缺少参考图目录：refs/cats/${cat}"
done
missing_cats=0
present_files=0
for cat in A B C; do
  candidates=()
  if [[ -f "refs/cats/${cat}/front.jpg" ]]; then
    candidates+=("refs/cats/${cat}/front.jpg")
  fi
  shopt -s nullglob
  candidates+=(refs/cats/${cat}/cat-*.jpg)
  shopt -u nullglob
  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "[smoke][WARN] 参考图待重传：refs/cats/${cat}/ 无 front.jpg 或 cat-*.jpg"
    missing_cats=$((missing_cats + 1))
    continue
  fi
  for ref in "${candidates[@]}"; do
    [[ -s "$ref" ]] || fail "参考图为空文件：${ref}"
    present_files=$((present_files + 1))
  done
done
if [[ "$missing_cats" -eq 3 ]]; then
  echo "[smoke][WARN] 参考图待重传（三张 jpg 均缺失）；文档锁定完成，继续验收"
else
  echo "[smoke]   refs/cats 非空 jpg ${present_files} 个；缺失 ${missing_cats} 只"
fi

echo "[smoke] 4/13 检查双机实体 ID"
for doc in scripts/race_boot.md DUAL-CREATE-RESULT-2026-10-24.md; do
  [[ -f "$doc" ]] || fail "缺少双机文档：${doc}"
  grep -q '9b4c40bda6-dad38bb9' "$doc" || fail "${doc} 缺少母机 ID 9b4c40bda6-dad38bb9"
  grep -q 'bb8c4f8e12-00c8bdac' "$doc" || fail "${doc} 缺少克隆 ID bb8c4f8e12-00c8bdac"
done
echo "[smoke]   母机/克隆实例 ID 一致"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cat-anthro-smoke.XXXXXX")"
cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

echo "[smoke] 5/13 噪声门禁 G1（self-test + fixtures 噪点 FAIL + 渐变/猫图 PASS）"
for fixture in \
  fixtures/qc/noise_uniform_96x96.pgm \
  fixtures/qc/gradient_smooth_96x96.pgm \
  fixtures/qc/subject_ref_128x128.pgm; do
  [[ -s "$fixture" ]] || fail "缺少 QC fixture：${fixture}"
done
python3 scripts/noise_gate.py --self-test || fail "noise_gate self-test 失败"

set +e
python3 scripts/noise_gate.py fixtures/qc/noise_uniform_96x96.pgm >"$TMP_ROOT/noise-gate.log" 2>&1
noise_rc=$?
set -e
if [[ "$noise_rc" -ne 2 ]]; then
  cat "$TMP_ROOT/noise-gate.log" >&2
  fail "noise_gate 未以 exit 2 拒绝 fixtures 噪点（实际 ${noise_rc}）"
fi
grep -q 'FAIL' "$TMP_ROOT/noise-gate.log" || fail "noise_gate 拒绝日志缺少 FAIL"

if ! python3 scripts/noise_gate.py fixtures/qc/gradient_smooth_96x96.pgm >"$TMP_ROOT/noise-gradient.log" 2>&1; then
  cat "$TMP_ROOT/noise-gradient.log" >&2
  fail "noise_gate 拒绝了平滑渐变正样本"
fi
if ! python3 scripts/noise_gate.py refs/cats/A/front.jpg >"$TMP_ROOT/noise-cat.log" 2>&1; then
  cat "$TMP_ROOT/noise-cat.log" >&2
  fail "noise_gate 拒绝了正常猫参考图 refs/cats/A/front.jpg"
fi
echo "[smoke]   fixtures 噪点 exit 2；渐变与 refs/cats/A/front.jpg PASS"

echo "[smoke] 6/13 主体门禁 G2 subject_gate（self-test + fixtures 噪点 FAIL + 位移 PASS）"
python3 scripts/subject_gate.py --self-test || fail "subject_gate self-test 失败"

set +e
python3 scripts/subject_gate.py \
  --start-image fixtures/qc/subject_ref_128x128.pgm \
  fixtures/qc/subject_noise_128x128.pgm >"$TMP_ROOT/subject-noise.log" 2>&1
subject_noise_rc=$?
set -e
if [[ "$subject_noise_rc" -ne 2 ]]; then
  cat "$TMP_ROOT/subject-noise.log" >&2
  fail "subject_gate 未以 exit 2 拒绝噪点负样本（实际 ${subject_noise_rc}）"
fi
grep -q 'FAIL' "$TMP_ROOT/subject-noise.log" || fail "subject_gate 拒绝日志缺少 FAIL"

if ! python3 scripts/subject_gate.py \
  --start-image fixtures/qc/subject_ref_128x128.pgm \
  fixtures/qc/subject_moved_128x128.pgm >"$TMP_ROOT/subject-moved.log" 2>&1; then
  cat "$TMP_ROOT/subject-moved.log" >&2
  fail "subject_gate 拒绝了带内位移正样本"
fi
if ! python3 scripts/subject_gate.py \
  --start-image fixtures/qc/subject_ref_128x128.pgm \
  fixtures/qc/subject_ref_128x128.pgm >"$TMP_ROOT/subject-same.log" 2>&1; then
  cat "$TMP_ROOT/subject-same.log" >&2
  fail "subject_gate 对高相似帧不应 FAIL（应 WARN）"
fi
grep -q 'WARN' "$TMP_ROOT/subject-same.log" || fail "subject_gate 高相似未给出 WARN"

set +e
python3 scripts/subject_gate.py \
  --start-image fixtures/qc/subject_ref_128x128.pgm \
  --enforce-center --center-min-ssim 0.15 \
  fixtures/qc/subject_flat_128x128.pgm >"$TMP_ROOT/subject-flat.log" 2>&1
subject_flat_rc=$?
set -e
if [[ "$subject_flat_rc" -ne 2 ]]; then
  cat "$TMP_ROOT/subject-flat.log" >&2
  fail "subject_gate 中心区门禁未以 exit 2 拒绝平场负样本（实际 ${subject_flat_rc}）"
fi
echo "[smoke]   噪点 exit 2；位移 PASS；高相似仅 WARN；中心区平场 exit 2"

echo "[smoke] 7/13 动作门禁 motion_gate（self-test + 近静帧 FAIL + 合成运动 PASS）"
python3 scripts/motion_gate.py --self-test || fail "motion_gate self-test 失败"

python3 - "$TMP_ROOT/motion-static" <<'PY'
from pathlib import Path
import sys
d = Path(sys.argv[1])
d.mkdir(parents=True, exist_ok=True)
w = h = 64
n = w * h
base = bytes([120] * n)
for i in range(5):
    buf = bytearray(base)
    for j in range(i * 20, i * 20 + 40):
        buf[j % n] = 130
    (d / f"f{i:02d}.pgm").write_bytes(b"P5\n64 64\n255\n" + bytes(buf))
PY

set +e
python3 scripts/motion_gate.py "$TMP_ROOT/motion-static" >"$TMP_ROOT/motion-static.log" 2>&1
motion_static_rc=$?
set -e
if [[ "$motion_static_rc" -ne 2 ]]; then
  cat "$TMP_ROOT/motion-static.log" >&2
  fail "motion_gate 未以 exit 2 拒绝近静帧序列（实际 ${motion_static_rc}）"
fi
grep -q 'FAIL' "$TMP_ROOT/motion-static.log" || fail "motion_gate 近静帧日志缺少 FAIL"

python3 - "$TMP_ROOT/motion-moving" <<'PY'
from pathlib import Path
import sys
d = Path(sys.argv[1])
d.mkdir(parents=True, exist_ok=True)
w = h = 64
n = w * h
for i in range(5):
    buf = bytearray([40] * n)
    offset = min(i * 8, w - 16)
    for y in range(16, 48):
        for x in range(offset, offset + 16):
            buf[y * w + x] = 220
    (d / f"f{i:02d}.pgm").write_bytes(b"P5\n64 64\n255\n" + bytes(buf))
PY

if ! python3 scripts/motion_gate.py "$TMP_ROOT/motion-moving" >"$TMP_ROOT/motion-moving.log" 2>&1; then
  cat "$TMP_ROOT/motion-moving.log" >&2
  fail "motion_gate 拒绝了合成运动序列"
fi
echo "[smoke]   近静帧 exit 2；合成运动 PASS"

echo "[smoke] 8/13 片段三态 clip_status（RENDER_DONE → AUTO_QC_PASS → HUMAN_ACCEPTED）"
python3 scripts/clip_status.py --self-test || fail "clip_status self-test 失败"
STATUS_CLIP="$TMP_ROOT/clip.mp4"
python3 scripts/clip_status.py set "$STATUS_CLIP" --state RENDER_DONE >"$TMP_ROOT/status.log" 2>&1 \
  || fail "clip_status 无法记录 RENDER_DONE"
grep -q 'usable=False' "$TMP_ROOT/status.log" || fail "RENDER_DONE 不应是可用的"
set +e
python3 scripts/clip_status.py set "$STATUS_CLIP" --state AUTO_QC_PASS --g1 pass >"$TMP_ROOT/status-bad.log" 2>&1
status_bad_rc=$?
set -e
if [[ "$status_bad_rc" -ne 2 ]]; then
  cat "$TMP_ROOT/status-bad.log" >&2
  fail "clip_status 未以 exit 2 拒绝缺 G2/G2m 的 AUTO_QC_PASS（实际 ${status_bad_rc}）"
fi
python3 scripts/clip_status.py set "$STATUS_CLIP" --state AUTO_QC_PASS --g1 pass --g2 pass --g2m pass \
  >"$TMP_ROOT/status-auto.log" 2>&1 || fail "clip_status 无法记录三门禁全过的 AUTO_QC_PASS"
grep -q 'usable=False' "$TMP_ROOT/status-auto.log" || fail "AUTO_QC_PASS 不应是可用的"
set +e
python3 scripts/clip_status.py set "$STATUS_CLIP" --state HUMAN_ACCEPTED --g1 pass --g2 pass --g2m pass \
  >"$TMP_ROOT/status-human-bad.log" 2>&1
status_human_bad_rc=$?
set -e
if [[ "$status_human_bad_rc" -ne 2 ]]; then
  cat "$TMP_ROOT/status-human-bad.log" >&2
  fail "clip_status 未拒绝无 --human 的 HUMAN_ACCEPTED（实际 ${status_human_bad_rc}）"
fi
python3 scripts/clip_status.py set "$STATUS_CLIP" --state HUMAN_ACCEPTED \
  --g1 pass --g2 pass --g2m pass --human >"$TMP_ROOT/status-human.log" 2>&1 \
  || fail "clip_status 无法记录人眼确认的 HUMAN_ACCEPTED"
grep -q 'usable=True' "$TMP_ROOT/status-human.log" || fail "HUMAN_ACCEPTED 应为唯一可用状态"
python3 scripts/clip_status.py verify "$STATUS_CLIP" --require HUMAN_ACCEPTED >/dev/null \
  || fail "clip_status verify HUMAN_ACCEPTED 失败"
echo "[smoke]   三态严格；AUTO_QC_PASS 仍不可用；HUMAN_ACCEPTED 唯一可用"

echo "[smoke] 9/13 一键装配 assemble_clip self-test（三态 + 候选 + 节拍床）"
python3 scripts/assemble_clip.py --self-test >"$TMP_ROOT/assemble.log" 2>&1 \
  || { cat "$TMP_ROOT/assemble.log" >&2; fail "assemble_clip self-test 失败"; }
grep -q 'PASS' "$TMP_ROOT/assemble.log" || fail "assemble_clip self-test 未打印 PASS"
echo "[smoke]   RENDER_DONE→AUTO→candidates、--human、静帧 G2m FAIL、音频 bed 均通过"

echo "[smoke] 10/13 有声/节拍床 stitch_audio self-test"
python3 scripts/stitch_audio.py --self-test >"$TMP_ROOT/audio.log" 2>&1 \
  || { cat "$TMP_ROOT/audio.log" >&2; fail "stitch_audio self-test 失败"; }
grep -q 'PASS' "$TMP_ROOT/audio.log" || fail "stitch_audio self-test 未打印 PASS"
echo "[smoke]   128 BPM 节拍床生成、混流、静音剥离均通过"

echo "[smoke] 11/13 执行 restore.sh dry-run（i2v / looklock / flf2v）"

for group in i2v looklock flf2v; do
  if ! env \
    CAT_ANTHRO_SKIP_ENV=1 \
    MODELS_ROOT="$TMP_ROOT/models" \
    COMFYUI_ROOT="$TMP_ROOT/ComfyUI" \
    INPUT_ROOT="$TMP_ROOT/input" \
    OUTPUT_ROOT="$TMP_ROOT/output" \
    bash scripts/restore.sh --dry-run --group "$group" >"$TMP_ROOT/restore-${group}.log" 2>&1; then
    cat "$TMP_ROOT/restore-${group}.log" >&2
    fail "restore.sh --dry-run --group ${group} 失败"
  fi
  echo "[smoke]   restore --dry-run --group ${group}: ok"
done

grep -q 'wan2.1_i2v_480p_14B_fp16.safetensors' "$TMP_ROOT/restore-i2v.log" \
  || fail "i2v restore 日志缺少 fp16 UNET（默认权重未生效）"
grep -q 'wan2.1_flf2v_720p_14B_fp16.safetensors' "$TMP_ROOT/restore-flf2v.log" \
  || fail "flf2v restore 日志缺少 fp16 UNET（默认权重未生效）"
grep -q 'Wan 侧默认 UNET=fp16' "$TMP_ROOT/restore-i2v.log" \
  || fail "i2v restore 日志缺少 Wan fp16 提醒"

LOOKLOCK_LOG="$TMP_ROOT/restore-looklock.log"
grep -q 'qwen_image_edit_2511_fp8mixed.safetensors' "$LOOKLOCK_LOG" \
  || fail "looklock restore 日志缺少 fp8mixed 默认 UNET"
grep -q 'fp8mixed OK' "$LOOKLOCK_LOG" \
  || fail "looklock restore 日志缺少 fp8mixed 精度策略"
grep -q -- '--force-fp16 on Qwen' "$LOOKLOCK_LOG" \
  || fail "looklock restore 日志缺少禁止 Qwen --force-fp16 警告"
grep -q -- '--use-sage-attention' "$LOOKLOCK_LOG" \
  || fail "looklock restore 日志缺少禁止 sage-attention 警告"
grep -q 'Lightning 4steps LoRA' "$LOOKLOCK_LOG" \
  || fail "looklock restore 日志缺少 Lightning 仅 fp8mixed/默认 OFF 说明"
grep -q 'fp16 (separate policy)' "$LOOKLOCK_LOG" \
  || fail "looklock restore 日志缺少 Wan fp16 独立策略说明"
if grep -q 'wan2.1_i2v_480p_14B' "$LOOKLOCK_LOG"; then
  cat "$LOOKLOCK_LOG" >&2
  fail "looklock restore 静默回退到 i2v（fail-closed 被破坏）"
fi
echo "[smoke]   looklock 精度策略完整，且未回退到 i2v"

for cat in A B C; do
  src="refs/cats/${cat}/front.jpg"
  [[ -f "$src" ]] || continue
  dest="$TMP_ROOT/input/cats/${cat}/raw/front.jpg"
  if [[ ! -s "$dest" ]]; then
    fail "restore 未把 ${src} 同步到 ${dest}"
  fi
  cmp -s "$src" "$dest" || fail "同步后的参考图与 ${src} 不一致：${dest}"
done
echo "[smoke]   refs/cats/*/front.jpg 已同步到 INPUT_ROOT（内容一致）"

for rel in \
  input/cats/A/raw \
  input/cats/B/raw \
  input/cats/C/raw \
  input/looklock \
  input/shots \
  output/i2v \
  output/flf2v \
  output/exports; do
  [[ -d "$TMP_ROOT/$rel" ]] || fail "restore 未创建目录：${rel}"
done
echo "[smoke]   输入/输出目录结构完整"
grep -q 'sha256 必验' "$TMP_ROOT/restore-i2v.log" || fail "restore 日志缺少 sha256 必验提醒"
grep -q 'sha256=' "$TMP_ROOT/restore-i2v.log" || fail "restore dry-run 日志缺少 sha256（可能回退 size-only）"

echo "[smoke] 12/13 manifest sha256 真实性 + 缺失拒绝（不下载大权重）"
for group in i2v looklock flf2v; do
  if ! python3 scripts/download_models.py --validate-manifest --group "$group" >"$TMP_ROOT/sha-${group}.log" 2>&1; then
    cat "$TMP_ROOT/sha-${group}.log" >&2
    fail "download_models --validate-manifest --group ${group} 失败"
  fi
done

python3 - "$TMP_ROOT/manifest-missing.json" <<'PY'
import json
import sys
from pathlib import Path
source = json.loads(Path("manifest.json").read_text(encoding="utf-8"))
source["groups"]["i2v"]["weights"][0].pop("sha256", None)
Path(sys.argv[1]).write_text(json.dumps(source), encoding="utf-8")
PY

set +e
python3 scripts/download_models.py \
  --group i2v \
  --manifest "$TMP_ROOT/manifest-missing.json" \
  --models-root "$TMP_ROOT/models-missing" >"$TMP_ROOT/sha-refuse.log" 2>&1
sha_refuse_rc=$?
set -e
if [[ "$sha_refuse_rc" -ne 2 ]]; then
  cat "$TMP_ROOT/sha-refuse.log" >&2
  fail "缺 sha256 的非 dry-run 未以 exit 2 拒绝（实际 ${sha_refuse_rc}）"
fi
grep -q 'REFUSE' "$TMP_ROOT/sha-refuse.log" || fail "缺 sha256 拒绝日志缺少 REFUSE"
if grep -q '^\[get\]' "$TMP_ROOT/sha-refuse.log"; then
  fail "缺 sha256 时不应开始下载（size-only 被破坏）"
fi

set +e
python3 scripts/download_models.py \
  --dry-run \
  --group i2v \
  --manifest "$TMP_ROOT/manifest-missing.json" \
  --models-root "$TMP_ROOT/models-missing" >"$TMP_ROOT/sha-dry.log" 2>&1
sha_dry_rc=$?
set -e
if [[ "$sha_dry_rc" -ne 0 ]]; then
  cat "$TMP_ROOT/sha-dry.log" >&2
  fail "缺 sha256 的 dry-run 应 WARN 且 exit 0（实际 ${sha_dry_rc}）"
fi
grep -q 'WARN' "$TMP_ROOT/sha-dry.log" || fail "缺 sha256 的 dry-run 未打印 WARN"
echo "[smoke]   三个 group sha256 齐全；缺 sha 的 apply 拒绝、dry-run WARN"

echo "[smoke] 13/13 检查 comic 路径拒绝"
set +e
env \
  CAT_ANTHRO_SKIP_ENV=1 \
  MODELS_ROOT="$TMP_ROOT/ai-realistic-comic/models" \
  COMFYUI_ROOT="$TMP_ROOT/ComfyUI" \
  INPUT_ROOT="$TMP_ROOT/input-refuse" \
  OUTPUT_ROOT="$TMP_ROOT/output-refuse" \
  bash scripts/restore.sh --dry-run --group i2v >"$TMP_ROOT/refuse.log" 2>&1
refuse_rc=$?
set -e
if [[ "$refuse_rc" -ne 2 ]]; then
  cat "$TMP_ROOT/refuse.log" >&2
  fail "restore.sh 未以 exit 2 拒绝 ai-realistic-comic 路径（实际 ${refuse_rc}）"
fi
grep -q 'Refusing' "$TMP_ROOT/refuse.log" || fail "restore.sh 拒绝信息不明确"
echo "[smoke]   ai-realistic-comic 路径已被拒绝"

echo "[smoke] PASS (dry-run): workflow/manifest+sha256、三猫定妆、CHARACTER-LOCK、refs/cats、双机 ID、G1/G2/G2m、clip_status、assemble、stitch_audio、restore 隔离均通过"
echo "[smoke] 未开机、未跑 GPU、未生成真实视频、未产生计费；此 PASS 不代表生成成功。"
exit 0
