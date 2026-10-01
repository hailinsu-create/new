#!/usr/bin/env bash
# AutoDL one-time setup. Run inside the rented GPU instance.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export HF_HOME="${HF_HOME:-/root/autodl-tmp/hf}"
export HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-$HF_HOME/hub}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-$HF_HOME/transformers}"
export TORCH_HOME="${TORCH_HOME:-/root/autodl-tmp/torch}"
# AutoDL CN: huggingface.co is often blocked; hf-mirror works.
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}"
mkdir -p "$HF_HOME" "$TORCH_HOME" /root/autodl-tmp/out

echo "==> GPU"
nvidia-smi --query-gpu=name,memory.total --format=csv || true

echo "==> Python packages (pipeline + diffusers)"
export PATH="/root/miniconda3/bin:/root/miniconda/bin:/opt/conda/bin:$PATH"
PYBIN="$(command -v python3 || command -v python)"
$PYBIN -m pip -q install -U pip
$PYBIN -m pip -q install -e .

set +e
$PYBIN - <<'PY'
import torch
assert torch.cuda.is_available(), "CUDA torch missing — pick a PyTorch+CUDA AutoDL image"
print("torch", torch.__version__, "cuda", torch.version.cuda, "gpu", torch.cuda.get_device_name(0))
raise SystemExit(0 if hasattr(torch, "accelerator") else 2)
PY
status=$?
set -e
if [ "$status" -eq 2 ]; then
  echo "upgrading torch for accelerator API…"
  $PYBIN -m pip -q install -U torch torchvision --index-url https://download.pytorch.org/whl/cu124
elif [ "$status" -ne 0 ]; then
  exit "$status"
fi

$PYBIN - <<'PY'
import torch
assert torch.cuda.is_available(), "CUDA broken after torch setup"
assert hasattr(torch, "accelerator"), f"torch {torch.__version__} still missing accelerator"
print("torch ok", torch.__version__, "cuda", torch.version.cuda, "gpu", torch.cuda.get_device_name(0))
PY
$PYBIN -m pip -q install -U "diffusers>=0.35.0" transformers accelerate sentencepiece protobuf pillow pyyaml

echo "==> Done. HF cache: $HF_HOME"
echo "Next: bash autodl/run_smoke.sh"
