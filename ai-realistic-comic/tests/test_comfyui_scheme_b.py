"""Scheme B redraws nude plates in ComfyUI. Qwen seeds stay abandoned."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_scheme_b_keeps_qwen_seeds_abandoned_and_skips_adrian():
    script = (ROOT / "workflows" / "comfyui" / "scheme_b_from_plate.py").read_text(encoding="utf-8")
    front = (ROOT / "workflows" / "comfyui" / "scheme-b-front-side.api.json").read_text(encoding="utf-8")
    back = (ROOT / "workflows" / "comfyui" / "scheme-b-back.api.json").read_text(encoding="utf-8")
    setup = (ROOT / "docs" / "comfyui-setup.md").read_text(encoding="utf-8")
    history = (ROOT / "docs" / "cast-body-two-stage.md").read_text(encoding="utf-8")

    assert "SAMPLER_SEED = 20261006" in script
    assert "adrian" not in script.lower()
    jobs = script.split("JOBS = [", 1)[1].split("]", 1)[0]
    for actor in ("lin_wantang", "gu_chengan", "elena_voss"):
        for view in ("front", "side", "back"):
            assert f'("{actor}", "{view}")' in jobs
    assert "adrian" not in jobs
    assert '"scale_by": 0.86' in script
    assert '"x": 72' in script
    assert "127.0.0.1:8188" in setup
    assert "RealVisXL_V5.0_fp16" in setup
    assert "20261006" in front
    back_prompt = back.split('"prompt"', 1)[1]
    assert "ApplyInstantID" not in back_prompt
    assert "FaceDetailer" not in back_prompt
    assert "86`–`98`" in history
    assert "从 `99` 起" in history
