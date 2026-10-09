#!/usr/bin/env python3
"""Surgical collar+hip cleanup on lin a9 (best clean residual base) with tight boxes."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bringup_and_run import ship, ssh  # noqa: E402

SRC = Path("/opt/cursor/artifacts/fox-centaur-semantic/run13/attempts/lin-qipao-nine-tail-nude-a9.png")
OUT = Path("/opt/cursor/artifacts/fox-centaur-semantic/run13")
key = os.path.expanduser("~/.ssh/bjb791")

script = r'''
import sys
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0, "/root/autodl-tmp/arc/ai-realistic-comic/workflows/comfyui")
import semantic_undress as sem
import run_fox_centaur_semantic as run
from comfy_util import resolve_base_models

host = "http://127.0.0.1:8188"
models = resolve_base_models(host)
base = Image.open("/root/autodl-tmp/fox-semantic-out/lin-surg-v2-base.png").convert("RGB")
shape = (base.size[1], base.size[0])
plan = sem.PLANS["lin"]
mask = np.zeros(shape, dtype=bool)
# Tight collar standing band + hip wrap / slit panel only (avoid full-leg redo).
for box in ((340, 285, 600, 385), (310, 740, 540, 1050), (280, 780, 400, 1180)):
    mask |= sem.box_array(shape, box)
mask = sem.dilate(mask, 12)
mask &= ~sem.box_array(shape, plan.face_clear)
work = Path("/root/autodl-tmp/fox-semantic-work-lin-surg-v2"); work.mkdir(parents=True, exist_ok=True)
inp = Path("/root/autodl-tmp/fox-semantic-in-lin-surg-v2"); inp.mkdir(parents=True, exist_ok=True)
# LaMa erase then high-mid Fooocus
cur = run.run_bands(host, models, base, mask, positive=run.RESIDUAL_SKIN_POS,
                    negative=run.RESIDUAL_SKIN_NEG + ", collar, mandarin collar, wrap skirt, loincloth",
                    seed=20271001, stem="lin-surg-v2-lama", denoise=0.0, edge=False,
                    input_dir=inp, out_dir=work, lama_only=True)
pos = "bare neck and collarbone, bare hips and outer thigh skin, skin tone matches the face, pores"
neg = run.RESIDUAL_SKIN_NEG + ", collar, mandarin collar, wrap skirt, loincloth, bikini, panties"
cur = run.run_bands(host, models, cur, mask, positive=pos, negative=neg, seed=20271011,
                    stem="lin-surg-v2", denoise=0.92, edge=False, input_dir=inp, out_dir=work,
                    cfg=5.5, lama_prefill=True)
edge = sem.edge_band(mask, 10) & ~sem.box_array(shape, plan.face_clear)
cur = run.run_bands(host, models, cur, edge, positive=run.NUDE_EDGE_POS, negative=run.NUDE_EDGE_NEG,
                    seed=20271021, stem="lin-surg-v2-edge", denoise=0.30, edge=True,
                    input_dir=inp, out_dir=work, cfg=3.5)
dest = Path("/root/autodl-tmp/fox-semantic-out/lin-qipao-nine-tail-nude.png")
cur.save(dest)
print("SURG_V2_OK", dest.stat().st_size, flush=True)
'''


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing {SRC}")
    # Wait until seed batch is between attempts so we do not collide with Comfy queue.
    ship(light=True)
    subprocess.check_call([
        "scp", "-i", key, "-P", "36250", "-o", "BatchMode=yes",
        str(SRC), "root@connect.bjb1.seetacloud.com:/root/autodl-tmp/fox-semantic-out/lin-surg-v2-base.png",
    ])
    Path("/tmp/lin_surg_v2.py").write_text(script, encoding="utf-8")
    subprocess.check_call([
        "scp", "-i", key, "-P", "36250", "-o", "BatchMode=yes",
        "/tmp/lin_surg_v2.py", "root@connect.bjb1.seetacloud.com:/tmp/lin_surg_v2.py",
    ])
    ssh("/root/miniconda3/bin/python -u /tmp/lin_surg_v2.py", timeout=7200)
    subprocess.check_call([
        "scp", "-i", key, "-P", "36250", "-o", "BatchMode=yes",
        "root@connect.bjb1.seetacloud.com:/root/autodl-tmp/fox-semantic-out/lin-qipao-nine-tail-nude.png",
        str(OUT / "lin-qipao-nine-tail-nude.png"),
    ])
    (OUT / "attempts/lin-qipao-nine-tail-nude-surg-v2.png").write_bytes(
        (OUT / "lin-qipao-nine-tail-nude.png").read_bytes()
    )
    print("LOCAL_SURG_V2_READY", flush=True)


if __name__ == "__main__":
    main()
