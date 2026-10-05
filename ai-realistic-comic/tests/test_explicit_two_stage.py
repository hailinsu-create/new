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
    assert score.startswith(mod.SCORE_PREFIX)
    assert "待分图：/tmp/out.png\n只打这一张。\n" == score[len(mod.SCORE_PREFIX) :]
    other = mod._codex_score_prompt(Path("/var/tmp/other.png"))
    assert other.startswith(mod.SCORE_PREFIX)
    assert score[: len(mod.SCORE_PREFIX)] == other[: len(mod.SCORE_PREFIX)]
    assert "/tmp/out.png" not in mod.SCORE_PREFIX
    assert "/var/tmp/other.png" not in mod.SCORE_PREFIX
    for name in ("身份", "区分", "互动", "美感", "解剖", "服装", "动机", "摄影感"):
        assert name in mod.SCORE_PREFIX
    for gate in ("H1", "H2", "H3", "H4", "H5", "H6", "H7"):
        assert gate in mod.SCORE_PREFIX
    assert '"mean":0' in mod.SCORE_PREFIX
    assert "OpenCode Go vision" in mod.SCORE_PREFIX
    assert "deepseek-v4-flash-vision" in mod.SCORE_PREFIX
    assert "禁止 agy" in mod.SCORE_PREFIX
    assert str(mod.RUBRIC).endswith("docs/still-score-two-stage.md")
    rubric = mod.RUBRIC.read_text(encoding="utf-8")
    assert "由 Codex CLI" in rubric
    assert "固定前缀" in rubric
    assert "禁止 OpenCode" in rubric


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
    assert "opencode run" not in source
    assert '"opencode"' not in source
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


def test_f34_powers_on_only_for_work_and_shuts_down_when_stopped():
    import inspect

    mod = _load()
    text = (Path(__file__).resolve().parents[1] / "docs" / "explicit-still-two-stage.md").read_text(
        encoding="utf-8"
    )
    for phrase in (
        "干活才开机",
        "立刻关机留盘",
        "禁止空转",
        "等下一步",
        "别关",
        "先别开",
        "f34_shutdown_hook",
        "f34_begin_work",
        "f34_power_decision",
        "SCORE_PREFIX",
        "_codex_score_prompt",
        "待分图：",
        "只打这一张。",
        "不得只留在本地",
        "必须写说明文档并推到 GitHub",
        "107374182400",
        mod.F34_UUID,
    ):
        assert phrase in text
    assert "F34 保持开机" not in text
    assert "先不关机" not in text

    assert mod.f34_power_decision("work", "") == "power_on"
    assert mod.f34_power_decision("work", "别关") == "power_on"
    assert mod.f34_power_decision("work", "先别开") == "skip_power_on"
    for phase in ("done", "paused", "idle", "wait"):
        assert mod.f34_power_decision(phase, "") == "power_off_keep_disk"
        assert mod.f34_power_decision(phase, "先别开") == "power_off_keep_disk"
        assert mod.f34_power_decision(phase, "别关") == "skip_shutdown"
    try:
        mod.f34_power_decision("sleep", "")
    except SystemExit as exc:
        assert "未知" in str(exc)
    else:
        raise AssertionError("unknown phase must fail")

    calls = []

    def post(url, payload, token):
        calls.append((url, dict(payload), token))
        return {"code": "Success"}

    def get(url, token):
        calls.append((url, None, token))
        return {"data": {"assets": 51790, "blocked_asset": 0}}

    def list_post(url, payload, token):
        calls.append((url, dict(payload), token))
        return {
            "data": [
                {
                    "uuid": mod.F34_UUID,
                    "status": "shutdown",
                    "expand_data_disk_size": mod.F34_DISK_BYTES,
                }
            ]
        }

    result = mod.f34_shutdown_hook(
        "done", "", post=post, get=get, list_post=list_post, token="t"
    )
    assert result["action"] == "power_off_keep_disk"
    assert result["uuid"] == mod.F34_UUID
    assert result["disk_bytes"] == mod.F34_DISK_BYTES
    assert result["release"] is False
    assert result["assets_li"] == 51790
    urls = [item[0] for item in calls]
    assert urls[0] == mod.F34_POWER_OFF_URL
    assert calls[0][1] == {"instance_uuid": mod.F34_UUID}
    assert mod.F34_POWER_ON_URL not in urls
    assert mod.G09_UUID not in str(calls)
    assert "release" not in str(urls)

    calls.clear()
    skipped = mod.f34_shutdown_hook("paused", "别关", post=post, get=get, list_post=list_post)
    assert skipped["action"] == "skip_shutdown"
    assert calls == []

    calls.clear()
    mod.f34_shutdown_hook("idle", "先别开", post=post)
    assert calls[0][0] == mod.F34_POWER_OFF_URL
    assert mod.F34_POWER_ON_URL not in [item[0] for item in calls]

    calls.clear()
    held = mod.f34_begin_work("先别开", post=post)
    assert held["action"] == "skip_power_on"
    assert calls == []

    calls.clear()
    started = mod.f34_begin_work("", post=post, token="t")
    assert started["action"] == "power_on"
    assert calls == [(mod.F34_POWER_ON_URL, {"instance_uuid": mod.F34_UUID}, "t")]

    try:
        mod._f34_guard({"instance_uuid": mod.G09_UUID}, mod.F34_POWER_OFF_URL)
    except SystemExit as exc:
        assert "G09" in str(exc)
    else:
        raise AssertionError("G09 must be refused")
    try:
        mod._f34_guard(
            {"instance_uuid": mod.F34_UUID},
            "https://www.autodl.com/api/v1/instance/release",
        )
    except SystemExit as exc:
        assert "留盘" in str(exc)
    else:
        raise AssertionError("release must be refused")

    def bad_disk(url, payload, token):
        return {"data": [{"uuid": mod.F34_UUID, "expand_data_disk_size": 1}]}

    try:
        mod.f34_shutdown_hook("wait", "", post=post, list_post=bad_disk)
    except SystemExit as exc:
        assert "不要释放" in str(exc)
    else:
        raise AssertionError("wrong disk size must fail closed")

    source = Path(mod.__file__).read_text(encoding="utf-8")
    assert "/api/v1/dev/instance/pro/power_off" not in source
    hook = inspect.getsource(mod.f34_shutdown_hook)
    assert "F34_POWER_ON_URL" not in hook
    assert "power_on" not in hook
    main_src = inspect.getsource(mod.main)
    assert main_src.index("_run_codex_stage") < main_src.index("f34_begin_work")
    assert main_src.index("f34_begin_work") < main_src.index("_run_qwen_stage")
    assert "_f34_finish" in main_src
    request_src = inspect.getsource(mod._f34_website_request)
    assert "Bearer" not in request_src
    assert "Authorization" in request_src
