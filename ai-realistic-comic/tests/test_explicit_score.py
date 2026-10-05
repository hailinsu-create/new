import importlib.util
from pathlib import Path


def _load():
    path = Path(__file__).resolve().parents[1] / "autodl" / "run_explicit8.py"
    spec = importlib.util.spec_from_file_location("run_explicit8", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_keep_line_is_nine_and_gates_block():
    mod = _load()
    assert mod.KEEP_MEAN == 9.0
    try:
        mod.score_still(Path("/tmp/out.png"))
    except SystemExit as exc:
        assert "Codex CLI" in str(exc) and "OpenCode" in str(exc)
    else:
        raise AssertionError("retired scorer must fail closed")
    assert "opencode" not in Path(mod.__file__).read_text(encoding="utf-8")
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


def test_parse_score_reads_one_object():
    mod = _load()
    item = mod.parse_score('noise {"gates": [], "mean": 9.2, "note": "ok"} tail')
    assert item["mean"] == 9.2
    assert item["gates"] == []
