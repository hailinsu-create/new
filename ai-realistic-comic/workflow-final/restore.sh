#!/usr/bin/env bash
# One-shot restore on a fresh AutoDL GPU box.
# Requires: HF_TOKEN, CIVITAI_API_TOKEN, AUTODL_TOKEN (export before run).
# Usage:
#   cd /root/autodl-tmp && git clone ... && cd .../ai-realistic-comic/workflow-final
#   set -a; source ./env.local; set +a   # or export the three tokens
#   bash restore.sh
set -euo pipefail

WF_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="${COMFY_ROOT:-/root/autodl-tmp/comfyui}"
COMFY_PY="${COMFY_PY:-/root/miniconda3/bin/python}"
PIP_INDEX="${PIP_INDEX:-https://pypi.tuna.tsinghua.edu.cn/simple}"
HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
COMFYUI_URL="${COMFYUI_URL:-http://127.0.0.1:8188}"
SKIP_SMOKE_IMAGE="${SKIP_SMOKE_IMAGE:-0}"
GROUPS="${RESTORE_GROUPS:-all}"

export HF_ENDPOINT COMFY_ROOT COMFYUI_URL
export HF_TOKEN="${HF_TOKEN:-}"
export CIVITAI_API_TOKEN="${CIVITAI_API_TOKEN:-}"
export AUTODL_TOKEN="${AUTODL_TOKEN:-}"

say() { printf '%s %s\n' "$(date -u +%FT%TZ)" "$*"; }

die() { say "ERROR $*"; exit 1; }

need_tokens() {
  [[ -n "$HF_TOKEN" ]] || die "export HF_TOKEN=..."
  [[ -n "$CIVITAI_API_TOKEN" ]] || die "export CIVITAI_API_TOKEN=..."
  [[ -n "$AUTODL_TOKEN" ]] || die "export AUTODL_TOKEN=... (web JWT or developer token)"
}

# AutoDL: academic turbo helps git/GitHub; keep pip/HF direct.
with_turbo() {
  if [[ -f /etc/network_turbo ]]; then
    # shellcheck disable=SC1091
    ( source /etc/network_turbo >/dev/null 2>&1; "$@" )
  else
    "$@"
  fi
}

unset_proxy_for_pip() {
  unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy || true
}

install_comfy() {
  local commit tag repo
  commit="$(python3 -c 'import json;print(json.load(open("'"$WF_ROOT"'/pins.json"))["comfyui"]["commit"])')"
  tag="$(python3 -c 'import json;print(json.load(open("'"$WF_ROOT"'/pins.json"))["comfyui"]["tag"])')"
  repo="$(python3 -c 'import json;print(json.load(open("'"$WF_ROOT"'/pins.json"))["comfyui"]["repo"])')"
  mkdir -p "$(dirname "$COMFY_ROOT")"
  if [[ -d "$COMFY_ROOT/.git" ]]; then
    say "ComfyUI present; fetching pin $commit"
    with_turbo git -C "$COMFY_ROOT" fetch --tags --depth 1 origin "$tag" || with_turbo git -C "$COMFY_ROOT" fetch --depth 1 origin "$commit"
    git -C "$COMFY_ROOT" checkout --force "$commit"
  else
    say "Cloning ComfyUI $tag ($commit)"
    rm -rf "$COMFY_ROOT"
    with_turbo git clone --filter=blob:none "$repo" "$COMFY_ROOT"
    with_turbo git -C "$COMFY_ROOT" fetch --tags --depth 1 origin "refs/tags/$tag:refs/tags/$tag" || true
    git -C "$COMFY_ROOT" checkout --force "$commit"
  fi
  local got
  got="$(git -C "$COMFY_ROOT" rev-parse HEAD)"
  [[ "$got" == "$commit" ]] || die "comfy pin mismatch $got != $commit"
  say "OK ComfyUI @$got"
}

install_nodes() {
  mkdir -p "$COMFY_ROOT/custom_nodes"
  # pins.json currently has one node; loop via python for JSON only
  local map_file="/tmp/wf-nodes.map"
  python3 -c "
import json
from pathlib import Path
pins=json.loads(Path(r'$WF_ROOT/pins.json').read_text())
for name, meta in pins.get('custom_nodes', {}).items():
    print(f\"{name}\t{meta['repo']}\t{meta['commit']}\")
" > "$map_file"
  while IFS=$'\t' read -r name repo commit; do
    [[ -n "$name" ]] || continue
    local dest="$COMFY_ROOT/custom_nodes/$name"
    if [[ -d "$dest/.git" ]]; then
      say "NODE_UPDATE $name"
      with_turbo git -C "$dest" fetch --depth 1 origin "$commit" || true
    else
      say "NODE_CLONE $name"
      rm -rf "$dest"
      with_turbo git clone "$repo" "$dest"
    fi
    git -C "$dest" checkout --force "$commit"
    local got
    got="$(git -C "$dest" rev-parse HEAD)"
    [[ "$got" == "$commit" ]] || die "node pin mismatch $name $got != $commit"
    say "OK $name @$got"
  done < "$map_file"
}

pip_deps() {
  unset_proxy_for_pip
  [[ -x "$COMFY_PY" ]] || COMFY_PY="$(command -v python3)"
  say "Using python $COMFY_PY"
  # Strip torch lines so AutoDL's preinstalled cu128 stack is kept.
  local req="/tmp/comfy-requirements-notorch.txt"
  grep -viE '^(torch|torchvision|torchaudio|comfyui-workflow-templates)' \
    "$COMFY_ROOT/requirements.txt" > "$req" || true
  "$COMFY_PY" -m pip install -q -i "$PIP_INDEX" -r "$req"
  # pinned extras
  "$COMFY_PY" -m pip install -q -i "$PIP_INDEX" \
    'pytorch-lightning' 'roma' 'dynamicprompts>=0.31,<1' || true
  # VNCCS node requirements if present
  if [[ -f "$COMFY_ROOT/custom_nodes/ComfyUI_VNCCS_Utils/requirements.txt" ]]; then
    "$COMFY_PY" -m pip install -q -i "$PIP_INDEX" \
      -r "$COMFY_ROOT/custom_nodes/ComfyUI_VNCCS_Utils/requirements.txt" || true
  fi
  say "PIP_OK"
}

download_models() {
  say "Downloading models (~46.6 GiB if cold cache) groups=$GROUPS"
  "$COMFY_PY" "$WF_ROOT/scripts/download_models.py" \
    --manifest "$WF_ROOT/manifest.json" \
    --comfy "$COMFY_ROOT" \
    --groups "$GROUPS"
}

place_assets() {
  mkdir -p \
    "$COMFY_ROOT/input" \
    "$COMFY_ROOT/user/default/workflows" \
    "$COMFY_ROOT/custom_nodes/ComfyUI_VNCCS_Utils/PoseLibrary"
  cp -a "$WF_ROOT/workflows/." "$COMFY_ROOT/user/default/workflows/"
  cp -a "$WF_ROOT/assets/refs/." "$COMFY_ROOT/input/"
  # Route C poses
  WF_ROOT="$WF_ROOT" COMFY_ROOT="$COMFY_ROOT" "$COMFY_PY" \
    "$WF_ROOT/scripts/run_route_c_pose.py" --comfy "$COMFY_ROOT" --prepare-only
  # convenience symlink
  ln -sfn "$WF_ROOT" /root/autodl-tmp/workflow-final 2>/dev/null || true
  say "ASSETS_OK"
}

run_smoke() {
  local args=(--comfy "$COMFY_ROOT" --host "$COMFYUI_URL" --py "$COMFY_PY")
  if [[ "$SKIP_SMOKE_IMAGE" == "1" ]]; then
    args+=(--no-image)
  fi
  "$COMFY_PY" "$WF_ROOT/scripts/smoke_check.py" "${args[@]}"
}

main() {
  need_tokens
  export WF_ROOT
  say "=== workflow-final restore ==="
  say "WF_ROOT=$WF_ROOT COMFY_ROOT=$COMFY_ROOT"
  df -h /root/autodl-tmp 2>/dev/null || df -h
  install_comfy
  install_nodes
  pip_deps
  download_models
  place_assets
  run_smoke
  say "RESTORE_DONE"
  say "Next: python scripts/run_r4_edit.py  OR  python scripts/run_qwen21_torn.py"
}

main "$@"
