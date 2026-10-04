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
    assert mod.VISION_MODEL == "opencode-go/deepseek-v4-flash-vision-exp"
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


def test_agy_stops_before_stage_one_without_login():
    mod = _load()
    missing = mod.agy_block_reason(None, logged_in=False)
    assert missing and "缺的是登录" in missing
    logged_out = mod.agy_block_reason("/home/ubuntu/.local/bin/agy", logged_in=False)
    assert logged_out and "缺的是登录" in logged_out
    assert mod.agy_block_reason("/home/ubuntu/.local/bin/agy", logged_in=True) is None


def test_face_drift_returns_to_stage_one():
    mod = _load()
    assert mod.stage2_action({"gates": [], "mean": 9.2, "face_drift": True}) == "back"
    assert mod.stage2_action({"gates": [], "mean": 9.2, "face_drift": False}) == "keep"
    assert mod.stage2_action({"gates": [], "mean": 8.9, "face_drift": False}) == "reshoot"


def test_parse_score_reads_one_object():
    mod = _load()
    item = mod.parse_score('noise {"gates": [], "mean": 9.2, "note": "ok"} tail')
    assert item["mean"] == 9.2
    assert item["gates"] == []
