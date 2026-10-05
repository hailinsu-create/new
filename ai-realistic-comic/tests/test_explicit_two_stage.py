import importlib.util
from pathlib import Path


def _load():
    path = Path(__file__).resolve().parents[1] / "autodl" / "run_explicit_two_stage.py"
    spec = importlib.util.spec_from_file_location("run_explicit_two_stage", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_new_vm_checklist_stays_in_the_still_doc():
    text = (Path(__file__).resolve().parents[1] / "docs" / "explicit-still-two-stage.md").read_text(
        encoding="utf-8"
    )
    assert "/home/ubuntu/.local/bin/codex" in text
    assert "codex login status" in text
    assert "Logged in using ChatGPT" in text
    assert "codex login --device-auth" in text
    assert "一次性码" in text
    assert "禁止 agy" in text
    assert "失败退出" in text
    assert "不开 F34" in text


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
    assert missing and "缺 Codex CLI" in missing and "失败退出" in missing
    logged_out = mod.codex_block_reason("/home/ubuntu/.local/bin/codex", logged_in=False)
    assert logged_out and "未登录" in logged_out and "失败退出" in logged_out
    assert "agy" in logged_out
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


def test_agy_is_forbidden_even_when_logged_in():
    mod = _load()
    for binary, logged_in in (
        (None, False),
        ("/home/ubuntu/.local/bin/agy", False),
        ("/home/ubuntu/.local/bin/agy", True),
    ):
        reason = mod.agy_block_reason(binary, logged_in=logged_in)
        assert reason and "禁止 agy" in reason
    try:
        mod._ensure_agy()
    except SystemExit as exc:
        assert "禁止 agy" in str(exc)
    else:
        raise AssertionError("agy ensure must fail")
    try:
        mod._run_agy_stage({"id": "p01"}, Path("/tmp/out.png"))
    except SystemExit as exc:
        assert "禁止 agy" in str(exc)
    else:
        raise AssertionError("agy stage must fail")
    try:
        mod._render_until_kept(None, {"id": "p01"}, Path("/tmp/out.png"), 1)
    except SystemExit as exc:
        assert "禁止降级" in str(exc)
    else:
        raise AssertionError("local Qwen must not replace the Codex lock")
    try:
        mod.score_still(Path("/tmp/out.png"))
    except SystemExit as exc:
        assert "Codex CLI" in str(exc)
    else:
        raise AssertionError("opencode must not score the lock")
    source = Path(mod.__file__).read_text(encoding="utf-8")
    assert '["agy"' not in source
    assert "agy --print" not in source
    assert "opencode" not in source
    assert source.count("_score_with_codex(") >= 4
    retired = Path(mod.__file__).resolve().parent / "run_explicit8.py"
    spec = importlib.util.spec_from_file_location("run_explicit8", retired)
    old = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(old)
    try:
        old.main()
    except SystemExit as exc:
        assert "失败退出" in str(exc) and "Codex CLI" in str(exc)
    else:
        raise AssertionError("retired runner must fail closed")


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
