#!/usr/bin/env bash
# Download R4 Qwen-Image-Edit-2511 stack onto the current AutoDL machine.
set -uo pipefail

COMFY="${COMFY:-/root/autodl-tmp/comfyui}"
HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export HF_ENDPOINT
OUT_JSON="${OUT_JSON:-/root/autodl-tmp/fox-semantic-out-r4/MODEL_HOST.json}"
STUCK_SEC="${STUCK_SEC:-900}"

mkdir -p \
  "$COMFY/models/diffusion_models" \
  "$COMFY/models/text_encoders" \
  "$COMFY/models/vae" \
  "$COMFY/models/loras" \
  "$(dirname "$OUT_JSON")"

if [[ -f /etc/network_turbo ]]; then
  # shellcheck disable=SC1091
  source /etc/network_turbo || true
fi

download_one() {
  local url="$1" dest="$2" min_bytes="$3"
  if [[ -f "$dest" ]]; then
    local sz
    sz=$(stat -c%s "$dest" 2>/dev/null || echo 0)
    if [[ "$sz" -ge "$min_bytes" ]]; then
      echo "SKIP $(basename "$dest") size=$sz"
      return 0
    fi
    echo "REDOWNLOAD $(basename "$dest") size=$sz < $min_bytes"
  fi
  echo "GET $url -> $dest"
  local tmp="${dest}.part"
  rm -f "$tmp"
  curl -L --fail --retry 5 --retry-delay 5 -H "User-Agent: fox-r4" -o "$tmp" "$url" &
  local pid=$!
  local last=0 last_t now sz
  last_t=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    sleep 20
    now=$(date +%s)
    sz=$(stat -c%s "$tmp" 2>/dev/null || echo 0)
    echo "PROG $(basename "$dest") bytes=$sz"
    if [[ "$sz" -gt "$last" ]]; then
      last=$sz
      last_t=$now
    elif [[ $((now - last_t)) -ge $STUCK_SEC ]]; then
      echo "STUCK_DOWNLOAD $(basename "$dest") no growth >${STUCK_SEC}s"
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      rm -f "$tmp"
      return 42
    fi
  done
  if ! wait "$pid"; then
    echo "CURL_FAIL $(basename "$dest")"
    rm -f "$tmp"
    return 1
  fi
  mv -f "$tmp" "$dest"
  local final
  final=$(stat -c%s "$dest")
  if [[ "$final" -lt "$min_bytes" ]]; then
    echo "TOO_SMALL $(basename "$dest") $final < $min_bytes"
    return 43
  fi
  echo "OK $(basename "$dest") $final"
  return 0
}

fail=0
download_one \
  "$HF_ENDPOINT/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors" \
  "$COMFY/models/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors" \
  15000000000 || fail=1
download_one \
  "$HF_ENDPOINT/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
  "$COMFY/models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors" \
  7000000000 || fail=1
download_one \
  "$HF_ENDPOINT/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors" \
  "$COMFY/models/vae/qwen_image_vae.safetensors" \
  200000000 || fail=1
download_one \
  "$HF_ENDPOINT/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" \
  "$COMFY/models/loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors" \
  500000000 || fail=1

if ! download_one \
  "$HF_ENDPOINT/starsfriday/Qwen-Image-Edit-Remove-Clothes/resolve/main/qwen-edit-remove-clothes.safetensors" \
  "$COMFY/models/loras/qwen-edit-remove-clothes.safetensors" \
  200000000; then
  echo "FALLBACK_REMOVE Sentinel7"
  download_one \
    "$HF_ENDPOINT/Sentinel7/qwen-image/resolve/main/lora/qwen_image_edit_remove-clothing_v1.0.safetensors" \
    "$COMFY/models/loras/qwen-edit-remove-clothes.safetensors" \
    200000000 || fail=1
fi

download_one \
  "$HF_ENDPOINT/prithivMLmods/Qwen-Image-Edit-2511-Object-Remover/resolve/main/Qwen-Image-Edit-2511-Object-Remover.safetensors" \
  "$COMFY/models/loras/Qwen-Image-Edit-2511-Object-Remover.safetensors" \
  100000000 || fail=1

HOST_ID="$(hostname)"
ALIAS="${AUTODL_MACHINE_ALIAS:-unknown}"
UUID="${AUTODL_INSTANCE_UUID:-unknown}"
DF="$(df -h /root/autodl-tmp | tail -1 || true)"

/root/miniconda3/bin/python - <<PY
import json
from pathlib import Path
comfy = Path("$COMFY")
files = {
  "unet": comfy / "models/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors",
  "clip": comfy / "models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors",
  "vae": comfy / "models/vae/qwen_image_vae.safetensors",
  "lightning": comfy / "models/loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors",
  "remove_clothes": comfy / "models/loras/qwen-edit-remove-clothes.safetensors",
  "object_remover": comfy / "models/loras/Qwen-Image-Edit-2511-Object-Remover.safetensors",
}
meta = {
  "pipeline": "r4_qwen_models",
  "hostname": "$HOST_ID",
  "alias": "$ALIAS",
  "uuid": "$UUID",
  "comfy": str(comfy),
  "df": "$DF",
  "files": {k: {"path": str(p), "bytes": p.stat().st_size if p.is_file() else 0} for k, p in files.items()},
  "total_bytes": sum(p.stat().st_size for p in files.values() if p.is_file()),
}
Path("$OUT_JSON").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
print("MODEL_HOST_JSON", "$OUT_JSON")
print("TOTAL_GB", round(meta["total_bytes"] / 1e9, 2))
missing = [k for k, p in files.items() if not p.is_file() or p.stat().st_size < 1]
if missing:
    print("MISSING", missing)
    raise SystemExit(2)
print("R4_MODELS_OK")
PY
rc=$?
if [[ $fail -ne 0 || $rc -ne 0 ]]; then
  echo "R4_MODELS_FAIL fail=$fail py=$rc"
  exit 1
fi
echo "R4_MODELS_DONE"
