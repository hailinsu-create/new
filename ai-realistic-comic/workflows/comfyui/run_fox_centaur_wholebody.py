"""Fox/centaur whole-garment undress (方案 A) — scaffold only.

One garment hole + high denoise Fooocus + InstantID (+ optional OpenPose).
No banded LaMa residual / pixelfill loops.

Does NOT power on AutoDL. Refuses remote generate unless --i-know-authorized.
See docs/fox-centaur-semantic-undress.md §前提复盘.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

# Reuse plate InstantID graph builders when authorized later.
try:
    import scheme_b_from_plate as scheme_b  # noqa: F401
except Exception:  # noqa: BLE001
    scheme_b = None  # type: ignore

PLAN = {
    "name": "wholebody_garment_A",
    "denoise": 0.95,
    "cfg": 5.5,
    "use_instantid": True,
    "use_openpose": True,
    "forbid": ["lama_residual_loop", "hip_pixelfill", "banded_residual"],
    "actors": ["lin", "elena"],
    "modes": ["nude", "torn"],
    "torn": "composite_from_nude_plus_rim_0.55",  # run7/run9 path
    "cost_hint_cny": {"pilot_one_nude": "0.4-0.6", "four_stills": "1.5-2.5", "cap": "5"},
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--emit-plan", action="store_true", help="Print JSON plan and exit.")
    parser.add_argument(
        "--i-know-authorized",
        action="store_true",
        help="Required to attempt remote generate (still no autodl power_on in this scaffold).",
    )
    parser.add_argument("--host", default="http://127.0.0.1:8188")
    args = parser.parse_args()
    if args.emit_plan or not args.i_know_authorized:
        print(json.dumps(PLAN, ensure_ascii=False, indent=2))
        if not args.i_know_authorized:
            print(
                "WHOLEBODY_SCAFFOLD: no generate. Authorize explicitly, then implement "
                "single-mask InstantID+OpenPose path (reuse scheme_b_from_plate).",
                flush=True,
            )
            raise SystemExit(0)
    print(
        "WHOLEBODY_NOT_IMPLEMENTED: scaffold only — wire semantic mask → one Fooocus pass "
        f"on {args.host} after user authorization.",
        flush=True,
    )
    raise SystemExit(2)


if __name__ == "__main__":
    main()
