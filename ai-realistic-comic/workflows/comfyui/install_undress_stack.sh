#!/usr/bin/env bash
# Idempotent P0 stack for the semantic undress pipeline on Beijing B (359a49a1c3-4cda10df).
# Run on that machine only. Never on F34 / G09. Skips anything already on disk.
#   bash install_undress_stack.sh [inventory|install]
set -uo pipefail

MODE="${1:-install}"
ROOT="${COMFY_ROOT:-/root/autodl-tmp/comfyui}"
PY="${COMFY_PY:-/root/miniconda3/bin/python}"
HF="${HF_ENDPOINT:-https://hf-mirror.com}"
PIP_INDEX="${PIP_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"
MANIFEST="${ROOT}/undress-stack-manifest.txt"

unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy

NODES=(
  "ComfyUI-Inpaint-CropAndStitch|https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch"
  "comfyui-inpaint-nodes|https://github.com/Acly/comfyui-inpaint-nodes"
  "comfyui_segment_anything|https://github.com/storyicon/comfyui_segment_anything"
  "Comfyui_segformer_b2_clothes|https://github.com/StartHua/Comfyui_segformer_b2_clothes"
  "ComfyUI_InstantID|https://github.com/cubiq/ComfyUI_InstantID"
)

# dest (relative to ROOT)|hf repo|file in repo
MODELS=(
  "models/inpaint/fooocus_inpaint_head.pth|lllyasviel/fooocus_inpaint|fooocus_inpaint_head.pth"
  "models/inpaint/inpaint_v26.fooocus.patch|lllyasviel/fooocus_inpaint|inpaint_v26.fooocus.patch"
  "models/segformer_b2_clothes/config.json|mattmdjaga/segformer_b2_clothes|config.json"
  "models/segformer_b2_clothes/preprocessor_config.json|mattmdjaga/segformer_b2_clothes|preprocessor_config.json"
  "models/segformer_b2_clothes/model.safetensors|mattmdjaga/segformer_b2_clothes|model.safetensors"
  "models/grounding-dino/GroundingDINO_SwinT_OGC.cfg.py|ShilongLiu/GroundingDINO|GroundingDINO_SwinT_OGC.cfg.py"
)

# Beijing B cannot reach github.com directly (git clone hangs). AutoDL's academic acceleration
# (/etc/network_turbo) makes GitHub work; use it for git only. pip and Hugging Face stay direct.
gh_clone() {
  local url="$1" dest="$2"
  ( [ -f /etc/network_turbo ] && source /etc/network_turbo >/dev/null 2>&1; timeout 300 git clone --depth 1 "${url}" "${dest}" )
}

say() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*"; }

inventory() {
  say "== nodes"
  for spec in "${NODES[@]}"; do
    name="${spec%%|*}"
    if [ -d "${ROOT}/custom_nodes/${name}/.git" ]; then
      say "HAVE node ${name} $(git -C "${ROOT}/custom_nodes/${name}" rev-parse --short HEAD)"
    else
      say "MISS node ${name}"
    fi
  done
  say "== models"
  for spec in "${MODELS[@]}"; do
    dest="${spec%%|*}"
    if [ -s "${ROOT}/${dest}" ]; then
      say "HAVE ${dest} $(stat -c %s "${ROOT}/${dest}")"
    else
      say "MISS ${dest}"
    fi
  done
  for extra in models/sams models/grounding-dino models/checkpoints models/inpaint models/instantid; do
    say "DIR ${extra}: $(ls "${ROOT}/${extra}" 2>/dev/null | tr '\n' ' ')"
  done
  df -h "${ROOT}" | tail -1
}

fetch() {
  local dest="$1" repo="$2" file="$3"
  mkdir -p "$(dirname "${ROOT}/${dest}")"
  if [ -s "${ROOT}/${dest}" ]; then say "SKIP ${dest}"; return 0; fi
  local url="${HF}/${repo}/resolve/main/${file}"
  say "GET ${url}"
  for attempt in 1 2 3; do
    if curl -fL --retry 3 --connect-timeout 20 -o "${ROOT}/${dest}.part" "${url}"; then
      mv "${ROOT}/${dest}.part" "${ROOT}/${dest}"
      printf '%s  %s\n' "$(sha256sum "${ROOT}/${dest}" | cut -d' ' -f1)" "${dest}" >> "${MANIFEST}"
      return 0
    fi
    say "retry ${attempt} ${dest}"; sleep 5
  done
  say "FAILED ${dest}"; return 1
}

install_nodes() {
  mkdir -p "${ROOT}/custom_nodes"
  for spec in "${NODES[@]}"; do
    name="${spec%%|*}"; url="${spec#*|}"
    if [ -d "${ROOT}/custom_nodes/${name}/.git" ]; then say "SKIP node ${name}"; continue; fi
    say "CLONE ${url}"
    rm -rf "${ROOT}/custom_nodes/${name}"
    gh_clone "${url}" "${ROOT}/custom_nodes/${name}" || { say "FAILED clone ${name}"; rm -rf "${ROOT}/custom_nodes/${name}"; continue; }
    if [ -f "${ROOT}/custom_nodes/${name}/requirements.txt" ]; then
      grep -v -i -E '^(torch|torchvision|torchaudio|git\+)' "${ROOT}/custom_nodes/${name}/requirements.txt" > "/tmp/req-${name}.txt" || true
      "${PY}" -m pip install -q -i "${PIP_INDEX}" -r "/tmp/req-${name}.txt" || say "PIP_WARN ${name}"
    fi
    printf '%s  node:%s\n' "$(git -C "${ROOT}/custom_nodes/${name}" rev-parse HEAD)" "${name}" >> "${MANIFEST}"
  done
}

# The node reads models/segformer_b2_clothes at import time, and its __init__ also imports the b3 fashion
# variant, whose weights we do not use. Keep only the b2 clothes node so the package imports cleanly.
patch_segformer_init() {
  local init="${ROOT}/custom_nodes/Comfyui_segformer_b2_clothes/__init__.py"
  [ -f "${init}" ] || return 0
  if grep -q '^from .segformer_b3_fashion' "${init}"; then
    cat > "${init}" <<'PYEOF'
from .segformer_b2_clothes import *

NODE_CLASS_MAPPINGS = {"segformer_b2_clothes": segformer_b2_clothes}
NODE_DISPLAY_NAME_MAPPINGS = {"segformer_b2_clothes": "segformer_b2_clothes"}
PYEOF
    say "PATCHED segformer __init__ (b2 only)"
  fi
}

# comfyui_segment_anything's GroundingDINO uses BertModel.get_extended_attention_mask, which transformers 5.x
# removed. Pin the 4.46 line so the DINO text encoder builds.
pin_transformers() {
  local have
  have="$("${PY}" -c 'import transformers; print(transformers.__version__)' 2>/dev/null)"
  case "${have}" in
    4.46.*) say "SKIP transformers ${have}" ;;
    *) say "PIN transformers 4.46.3 (was ${have:-none})"
       "${PY}" -m pip install -q -i "${PIP_INDEX}" "transformers==4.46.3" "tokenizers>=0.20,<0.21" "huggingface_hub<1.0" || say "PIN_FAILED transformers" ;;
  esac
}

# GroundingDINO's text encoder is bert-base-uncased; huggingface.co is unreachable here, so warm the cache
# through the mirror (ComfyUI is started with the same HF_ENDPOINT).
prefetch_bert() {
  HF_ENDPOINT="${HF}" "${PY}" - <<'PYEOF' || say "BERT_PREFETCH_FAILED"
from huggingface_hub import snapshot_download
print(snapshot_download("bert-base-uncased", allow_patterns=["*.json", "*.txt", "model.safetensors"]))
PYEOF
}

case "${MODE}" in
  inventory) inventory ;;
  install)
    inventory
    install_nodes
    for spec in "${MODELS[@]}"; do
      IFS='|' read -r dest repo file <<<"${spec}"
      fetch "${dest}" "${repo}" "${file}"
    done
    patch_segformer_init
    pin_transformers
    prefetch_bert
    say "== after"
    inventory
    ;;
  *) echo "usage: $0 [inventory|install]" >&2; exit 2 ;;
esac
