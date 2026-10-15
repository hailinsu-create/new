#!/usr/bin/env python3
"""Hillclimb after residual denoise 0.88 retune."""
import json
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from bringup_and_run import ship, ssh  # noqa: E402

out = Path("/opt/cursor/artifacts/fox-centaur-semantic/run13")
arch = out / "attempts"
arch.mkdir(parents=True, exist_ok=True)
key = os.path.expanduser("~/.ssh/bjb791")


def scp_get(name: str, dest: Path) -> None:
    subprocess.check_call(
        [
            "scp", "-i", key, "-P", "36250", "-o", "BatchMode=yes",
            f"root@connect.bjb1.seetacloud.com:/root/autodl-tmp/fox-semantic-out/{name}",
            str(dest),
        ]
    )


ship(light=True)
for attempt in range(33, 51):
    print(f"=== ATTEMPT {attempt} ===", flush=True)
    ssh(
        "cd /root/autodl-tmp/arc/ai-realistic-comic && "
        "/root/miniconda3/bin/python -u workflows/comfyui/run_fox_centaur_semantic.py "
        f"--only lin elena --mode nude --attempt {attempt} --no-score "
        "--out /root/autodl-tmp/fox-semantic-out",
        timeout=14400,
    )
    for stem in ("lin-qipao-nine-tail-nude", "elena-armor-centaur-nude"):
        scp_get(f"{stem}.png", out / f"{stem}.png")
        scp_get(f"{stem}.run.json", out / f"{stem}.run.json")
        (arch / f"{stem}-a{attempt}.png").write_bytes((out / f"{stem}.png").read_bytes())
        (arch / f"{stem}-a{attempt}.run.json").write_bytes((out / f"{stem}.run.json").read_bytes())
        meta = json.loads((out / f"{stem}.run.json").read_text())
        print(f"META {stem} a{attempt} residual={meta.get('best_residual_ratio')}", flush=True)
    print(f"ATTEMPT{attempt}_READY", flush=True)
print("BATCH_33_50_DONE", flush=True)
