#!/usr/bin/env bash
# Smoke-test the two archived couple stills on local GPU. Shut down the instance when finished.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export HF_HOME="${HF_HOME:-/root/autodl-tmp/hf}"
export HUGGINGFACE_HUB_CACHE="${HUGGINGFACE_HUB_CACHE:-$HF_HOME/hub}"
export TRANSFORMERS_CACHE="${TRANSFORMERS_CACHE:-$HF_HOME/transformers}"
export HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
export IMAGE_PROVIDER=local
export LOCAL_STILL_MODEL="${LOCAL_STILL_MODEL:-qwen-image-edit-2511}"
export LOCAL_CANDIDATES="${LOCAL_CANDIDATES:-1}"
export LOCAL_STEPS="${LOCAL_STEPS:-40}"
export LOCAL_HEIGHT="${LOCAL_HEIGHT:-1280}"
export LOCAL_WIDTH="${LOCAL_WIDTH:-960}"
export COMIC_QA=0
export COMIC_ANATOMY_AUDIT=0
export COMIC_STRICT_AUDIT=0
export COMIC_STILL_BUDGET_USD="${COMIC_STILL_BUDGET_USD:-50}"

echo "provider=$IMAGE_PROVIDER model=$LOCAL_STILL_MODEL"
comic doctor

STILLS=(hades-persephone-throne baisuzhen-xuxian-coil)
for s in "${STILLS[@]}"; do
  echo "==> $s"
  comic still-library "$s"
  ls -la "output/library-stills/$s/final.png"
done

OUT=/root/autodl-tmp/out
mkdir -p "$OUT"
python - <<'PY'
from pathlib import Path
from PIL import Image
import shutil
root = Path("output/library-stills")
dest = Path("/root/autodl-tmp/out")
for d in sorted(root.glob("*/final.png")):
    shutil.copy2(d, dest / f"{d.parent.name}.png")
    print("copied", d, "->", dest / f"{d.parent.name}.png")
# contact sheet vs approved
for name in ("hades-persephone-throne", "baisuzhen-xuxian-coil"):
    approved = Path(f"library/stills/{name}/approved.jpg")
    local = dest / f"{name}.png"
    if not (approved.is_file() and local.is_file()):
        continue
    tiles = [Image.open(approved).convert("RGB"), Image.open(local).convert("RGB")]
    th = 720
    tiles = [t.resize((int(t.width * th / t.height), th)) for t in tiles]
    sheet = Image.new("RGB", (sum(t.width for t in tiles), th), "white")
    x = 0
    for t in tiles:
        sheet.paste(t, (x, 0)); x += t.width
    sheet.save(dest / f"compare_{name}.jpg", quality=90)
    print("sheet", dest / f"compare_{name}.jpg")
PY

echo "All outputs under $OUT — download them, then shut down the AutoDL instance."
