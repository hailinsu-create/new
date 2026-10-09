#!/usr/bin/env python3
"""Hard-fill mandarin collar with sampled neck skin, then light Fooocus blend.

Fooocus alone redraws the standing collar from context. Seed the hole with real
skin pixels first so low denoise sticks to bare neck.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bringup_and_run import ship, ssh  # noqa: E402

SRC = Path("/opt/cursor/artifacts/fox-centaur-semantic/run13/attempts/lin-qipao-nine-tail-nude-surg-v2.png")
PLATE = Path("/workspace/ai-realistic-comic/library/stills/fox-centaur-embrace/lin-qipao-nine-tail.png")
OUT = Path("/opt/cursor/artifacts/fox-centaur-semantic/run13")
key = os.path.expanduser("~/.ssh/bjb791")


def build_local_fill() -> tuple[Path, Path]:
    base = Image.open(SRC).convert("RGB")
    plate = Image.open(PLATE).convert("RGB")
    arr = np.asarray(base).copy()
    plate_a = np.asarray(plate)
    # Collar band: prefer plate pixels that differ from current (still patterned).
    y0, y1, x0, x1 = 290, 390, 360, 620
    band = arr[y0:y1, x0:x1]
    plat = plate_a[y0:y1, x0:x1]
    diff = np.abs(band.astype(int) - plat.astype(int)).mean(axis=2)
    # Also catch dark blue piping via low R relative to neighbors.
    piping = (plat[:, :, 2].astype(int) - plat[:, :, 0].astype(int) > 15) & (plat[:, :, 2] > 90)
    # If current still matches plate pattern, mark for fill.
    mask = (diff < 35) | piping
    # Always include a standing-collar rectangle near the neck.
    mask[10:70, 40:220] = True
    full = np.zeros(arr.shape[:2], dtype=bool)
    full[y0:y1, x0:x1] = mask
    # Dilate a bit
    from scipy import ndimage  # type: ignore

    full = ndimage.binary_dilation(full, iterations=4)
    # Sample skin from bare chest just below band.
    skin = arr[410:470, 420:560].reshape(-1, 3).astype(np.float32)
    mean = skin.mean(axis=0)
    # Soft noise so Fooocus has pores to latch onto.
    noise = np.random.default_rng(7).normal(0, 4, arr.shape).astype(np.float32)
    filled = arr.astype(np.float32)
    filled[full] = mean + noise[full]
    filled = np.clip(filled, 0, 255).astype(np.uint8)
    fill_path = Path("/tmp/lin_collar_hardfill.png")
    mask_path = Path("/tmp/lin_collar_hardfill_mask.png")
    Image.fromarray(filled).save(fill_path)
    Image.fromarray((full.astype(np.uint8) * 255)).save(mask_path)
    print("LOCAL_FILL", int(full.sum()), "mean", mean.astype(int).tolist(), flush=True)
    return fill_path, mask_path


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
base = Image.open("/root/autodl-tmp/fox-semantic-out/lin-hardfill-base.png").convert("RGB")
mask = sem.to_bool(Image.open("/root/autodl-tmp/fox-semantic-out/lin-hardfill-mask.png"))
work = Path("/root/autodl-tmp/fox-semantic-work-lin-hardfill"); work.mkdir(parents=True, exist_ok=True)
inp = Path("/root/autodl-tmp/fox-semantic-in-lin-hardfill"); inp.mkdir(parents=True, exist_ok=True)
pos = "bare neck skin continuing from the chest, smooth collarbone, pores, matching face skin tone"
neg = "collar, mandarin collar, qipao neckline, embroidery, frog button, piping, fabric, lace, clothes, text"
# Low denoise so painted skin sticks; one mid pass for blend.
cur = run.run_bands(host, models, base, mask, positive=pos, negative=neg, seed=20271101,
                    stem="lin-hardfill", denoise=0.42, edge=False, input_dir=inp, out_dir=work,
                    cfg=4.0, lama_prefill=False)
edge = sem.edge_band(mask, 8)
cur = run.run_bands(host, models, cur, edge, positive=run.NUDE_EDGE_POS, negative=run.NUDE_EDGE_NEG,
                    seed=20271111, stem="lin-hardfill-edge", denoise=0.28, edge=True,
                    input_dir=inp, out_dir=work, cfg=3.5)
dest = Path("/root/autodl-tmp/fox-semantic-out/lin-qipao-nine-tail-nude.png")
cur.save(dest)
print("HARDFILL_OK", dest.stat().st_size, flush=True)
'''


def main() -> None:
    fill, mask = build_local_fill()
    # Do not ship while seed batch owns Comfy — caller must pause batch first.
    ship(light=True)
    for local, remote in (
        (fill, "lin-hardfill-base.png"),
        (mask, "lin-hardfill-mask.png"),
    ):
        subprocess.check_call([
            "scp", "-i", key, "-P", "36250", "-o", "BatchMode=yes",
            str(local), f"root@connect.bjb1.seetacloud.com:/root/autodl-tmp/fox-semantic-out/{remote}",
        ])
    Path("/tmp/lin_hardfill.py").write_text(script, encoding="utf-8")
    subprocess.check_call([
        "scp", "-i", key, "-P", "36250", "-o", "BatchMode=yes",
        "/tmp/lin_hardfill.py", "root@connect.bjb1.seetacloud.com:/tmp/lin_hardfill.py",
    ])
    ssh("/root/miniconda3/bin/python -u /tmp/lin_hardfill.py", timeout=7200)
    subprocess.check_call([
        "scp", "-i", key, "-P", "36250", "-o", "BatchMode=yes",
        "root@connect.bjb1.seetacloud.com:/root/autodl-tmp/fox-semantic-out/lin-qipao-nine-tail-nude.png",
        str(OUT / "lin-qipao-nine-tail-nude.png"),
    ])
    (OUT / "attempts/lin-qipao-nine-tail-nude-hardfill.png").write_bytes(
        (OUT / "lin-qipao-nine-tail-nude.png").read_bytes()
    )
    print("LOCAL_HARDFILL_READY", flush=True)


if __name__ == "__main__":
    main()
