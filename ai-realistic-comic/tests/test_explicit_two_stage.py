import importlib.util
from pathlib import Path


def _load():
    path = Path(__file__).resolve().parents[1] / "autodl" / "run_explicit_two_stage.py"
    spec = importlib.util.spec_from_file_location("run_explicit_two_stage", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_keep_line_is_nine_and_gates_block():
    mod = _load()
    assert mod.KEEP_MEAN == 9.0
    assert mod.local_explicit_allowed({"gates": [], "mean": 9})
    assert not mod.local_explicit_allowed({"gates": ["H2"], "mean": 10})
    assert not mod.local_explicit_allowed({"gates": [], "mean": 8.9})
    assert mod.accepted({"gates": [], "mean": 9})
    assert mod.accepted({"gates": [], "mean": 9.1})
    assert not mod.accepted({"gates": [], "mean": 8.9})
    assert not mod.accepted({"gates": ["H2"], "mean": 10})
    assert not mod.accepted({"gates": [], "mean": "nope"})


def test_unset_explicit_only_refuses_the_full_set():
    mod = _load()
    try:
        mod.require_subset("", {"p01", "m01"})
    except SystemExit as exc:
        assert "EXPLICIT_ONLY" in str(exc)
    else:
        raise AssertionError("empty EXPLICIT_ONLY should refuse")
    assert mod.require_subset("p01, m02", {"p01", "m02"}) == {"p01", "m02"}


def test_codex_stops_before_stage_one_without_login():
    mod = _load()
    missing = mod.codex_block_reason(None, logged_in=False)
    assert missing and "缺的是登录" in missing
    logged_out = mod.codex_block_reason("/home/ubuntu/.local/bin/codex", logged_in=False)
    assert logged_out and "缺的是登录" in logged_out
    assert mod.codex_block_reason("/home/ubuntu/.local/bin/codex", logged_in=True) is None
    prompt = mod._codex_prompt(
        {
            "prompt": "bare breasts sexual contact",
            "negative": "child",
            "refs": [Path("/tmp/board.png")],
        },
        Path("/tmp/out.png"),
    )
    assert "许仙" in prompt
    assert "non-explicit" in prompt
    assert "image generation tool exactly once" in prompt
    assert "bare breasts" not in prompt
    score = mod._codex_score_prompt(Path("/tmp/out.png"))
    assert "Do not generate an image" in score


def test_agy_stops_before_stage_one_without_login():
    mod = _load()
    missing = mod.agy_block_reason(None, logged_in=False)
    assert missing and "缺的是登录" in missing
    logged_out = mod.agy_block_reason("/home/ubuntu/.local/bin/agy", logged_in=False)
    assert logged_out and "缺的是登录" in logged_out
    assert mod.agy_block_reason("/home/ubuntu/.local/bin/agy", logged_in=True) is None


def test_pass2_miss_does_not_reopen_pass1():
    mod = _load()
    assert mod.stage2_action({"gates": [], "mean": 9.2, "face_drift": True}) == "reshoot"
    assert mod.stage2_action({"gates": [], "mean": 9.2, "face_drift": False}) == "keep"
    assert mod.stage2_action({"gates": [], "mean": 8.9, "face_drift": False}) == "reshoot"
    assert mod.QWEN_PASS2_DENOISE == (0.35, 0.30, 0.25)
    assert mod.QWEN_PASS2_STEPS == (40, 32, 24)


def test_parse_score_reads_one_object():
    mod = _load()
    item = mod.parse_score('noise {"gates": [], "mean": 9.2, "note": "ok"} tail')
    assert item["mean"] == 9.2
    assert item["gates"] == []
