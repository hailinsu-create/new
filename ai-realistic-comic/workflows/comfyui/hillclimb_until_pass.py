"""DEPRECATED — numeric pass hillclimb is cancelled.

Scoring (mean>=9 / hard gates / SCORE_PENDING waits) is retired. Usability is
Cursor visual judgment of the PNGs after a generate pass.

Use bringup or the runner directly:

    python workflows/comfyui/bringup_and_run.py --mode both
    python workflows/comfyui/run_fox_centaur_semantic.py --only lin elena --mode both

This script exits non-zero so old automation does not silently wait on scores.
"""

from __future__ import annotations

import sys


def main() -> int:
    print(
        "HILLCLIMB_CANCELLED scoring retired; use bringup_and_run.py or "
        "run_fox_centaur_semantic.py and judge PNGs with Cursor visually "
        "(VISUAL_JUDGE lines).",
        flush=True,
    )
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
