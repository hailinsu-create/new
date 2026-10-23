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

echo "[smoke] 1/5 解析 workflow JSON 并核对 manifest 权重"
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
            "wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors",
            "umt5_xxl_fp8_e4m3fn_scaled.safetensors",
            "wan_2.1_vae.safetensors",
            "clip_vision_h.safetensors",
        ],
    },
    "workflow/03_flf2v_wan21.json": {
        "groups": ["flf2v", "i2v"],
        "required": [
            "wan2.1_flf2v_720p_14B_fp8_e4m3fn.safetensors",
            "umt5_xxl_fp8_e4m3fn_scaled.safetensors",
            "wan_2.1_vae.safetensors",
            "clip_vision_h.safetensors",
        ],
    },
}

errors: list[str] = []
for rel, spec in workflows.items():
    path = root / rel
    text = path.read_text(encoding="utf-8")
    try:
        json.loads(text)
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

    stale = sorted(set(re.findall(r"wan2\.1_[A-Za-z0-9._-]*fp16\.safetensors", text)))
    if stale:
        errors.append(f"{rel}: stale fp16 UNET references: {stale}")

    print(f"[smoke]   {rel}: {len(found)} weight filenames, all within manifest")

if errors:
    for err in errors:
        print(f"[smoke][FAIL] {err}", file=sys.stderr)
    sys.exit(1)
PY

echo "[smoke] 2/5 检查三猫定妆卡"
for name in 小橘 银宝 墨墨; do
  grep -q "$name" prompts/look_cards.md || fail "prompts/look_cards.md 缺少名字：${name}"
done
if grep -q '\[待补\]' prompts/look_cards.md; then
  fail "prompts/look_cards.md 仍含 [待补]"
fi
echo "[smoke]   A小橘 / B银宝 / C墨墨 已锁定"

echo "[smoke] 3/5 检查双机实体 ID"
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

echo "[smoke] 4/5 执行 restore.sh dry-run（i2v / looklock / flf2v）"
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

grep -q 'wan2.1_i2v_480p_14B_fp8_e4m3fn.safetensors' "$TMP_ROOT/restore-i2v.log" \
  || fail "i2v restore 日志缺少 fp8 UNET"

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

echo "[smoke] 5/5 检查 comic 路径拒绝"
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

echo "[smoke] PASS (dry-run): workflow/manifest、三猫定妆、双机 ID、restore 隔离均通过"
echo "[smoke] 未开机、未跑 GPU、未产生计费。"
exit 0
