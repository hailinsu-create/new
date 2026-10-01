#!/usr/bin/env bash
# AutoDL one-time setup. Run inside the rented GPU instance.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export HF_HOME="${HF_HOME:-/root/autodl-tmp/hf}"
export HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-$HF_HOME/hub}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-$HF_HOME/transformers}"
export TORCH_HOME="${TORCH_HOME:-/root/autodl-tmp/torch}"
mkdir -p "$HF_HOME" "$TORCH_HOME" /root/autodl-tmp/out

echo "==> GPU"
nvidia-smi --query-gpu=name,memory.total --format=csv || true

echo "==> Python packages (pipeline + diffusers)"
pip -q install -U pip
pip -q install -e .
# Prefer the image's torch if CUDA works; only reinstall if missing.
python - <<'PY'
import torch
assert torch.cuda.is_available(), "CUDA torch missing — pick a PyTorch+CUDA AutoDL image"
print("torch", torch.__version__, "cuda", torch.version.cuda, "gpu", torch.cuda.get_device_name(0))
PY
pip -q install -U "git+https://github.com/huggingface/diffusers" transformers accelerate sentencepiece protobuf pillow pyyaml

echo "==> Done. HF cache: $HF_HOME"
echo "Next: bash autodl/run_smoke.sh"
