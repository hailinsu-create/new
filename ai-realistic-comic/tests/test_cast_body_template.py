import importlib.util
from pathlib import Path


def _load():
    path = Path(__file__).resolve().parents[1] / "autodl" / "cast_body_template.py"
    spec = importlib.util.spec_from_file_location("cast_body_template", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _pass1_score(**over):
    item = {
        "gates": [],
        "period_hair": False,
        "period_makeup": False,
        "eyes_black_brown": True,
        "identity": 9,
        "distinction": 9,
        "interaction": 9,
        "aesthetics": 9,
        "anatomy": 9,
        "wardrobe": 10,
        "motif": 9,
        "photoreal": 9,
        "mean": 9.125,
    }
    item.update(over)
    return item


def test_twelve_clothed_plates_gate_nude():
    mod = _load()
    assert len(mod.CLOTHED_VIEWS) == 12
    assert not mod.clothed_passed("lin_wantang", "front")
    assert mod.clothed_passed("lin_wantang", "front", fresh_mean=9.2)
    assert not mod.clothed_passed("lin_wantang", "front", fresh_mean=8.9)
    assert not mod.clothed_passed("elena_voss", "front")
    assert not mod.clothed_passed("elena_voss", "back")
    assert mod.clothed_passed("gu_chengan", "front")
    assert not mod.clothed_passed("gu_chengan", "side")
    assert not mod.clothed_passed("gu_chengan", "back")
    assert not mod.clothed_passed("elena_voss", "side")
    assert mod.clothed_passed("adrian_kane", "front")
    male = [pair for pair in mod.NUDE_VIEWS if pair[0] not in mod.FEMALE_ACTORS]
    assert male and all(mod.clothed_passed(*pair) for pair in male)


def test_nine_views_and_fixed_scale():
    mod = _load()
    assert len(mod.NUDE_VIEWS) == 9
    assert ("gu_chengan", "side") not in mod.NUDE_VIEWS
    assert ("elena_voss", "side") not in mod.NUDE_VIEWS
    assert mod.FIXED_SCALE == 0.85
    assert mod.LIN_FRONT_SEED == 62
    assert 33 in mod.LIN_FRONT_SPENT and 61 in mod.LIN_FRONT_SPENT
    assert 62 not in mod.LIN_FRONT_SPENT
    assert mod.qwen_vae_frame(448, 592) == (448, 576)
    assert mod.PASS1_SIZE == (448, 592)
    assert mod.PASS1_STEPS == 8
    assert mod.ASSET_SCHEDULE["pass1"]["steps"] == 8
    assert mod.ASSET_SCHEDULE["pass2"]["denoise"] == 0.20
    assert mod.ASSET_SCHEDULE["pass2"]["steps"] == 12
    assert mod.PASS2_SCORE_TRIES[0] == (0.20, 12)
    assert all(denoise <= 0.20 and steps <= 12 for denoise, steps in mod.PASS2_SCORE_TRIES)
    assert all(denoise <= 0.20 and steps <= 8 for denoise, steps in mod.PASS2_OOM_TRIES)
    assert "cast-asset-job.json" in mod.JOB_REMOTE
    assert "lora-job" not in mod.JOB_REMOTE


def test_void_seed_33_never_passes():
    mod = _load()
    assert mod.is_void("lin_wantang", "front", 0.85, 33)
    assert mod.seed_for("lin_wantang", "front", 0) == 62
    score = _pass1_score()
    assert not mod.accept_pass1(score, "lin_wantang", "front", 0.85, 33)
    assert mod.accept_pass1(score, "lin_wantang", "front", 0.85, 34)


def test_pass1_requires_every_content_score_except_resolution():
    mod = _load()
    assert mod.PASS1_KEYS == mod.EIGHT
    assert mod.PASS1_SIZE == (448, 592)
    assert mod.accept_pass1(_pass1_score(), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(distinction=8.5), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(aesthetics=8), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(motif=8), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(photoreal=8), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(identity=8.9), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(period_hair=True), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(period_makeup=True), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(eyes_black_brown=False), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass1(_pass1_score(gates=["H7"]), "lin_wantang", "front", 0.85, 34)
    missing = _pass1_score()
    del missing["period_hair"]
    assert not mod.accept_pass1(missing, "lin_wantang", "front", 0.85, 34)


def test_pass2_uses_eight_way_mean_and_same_look_gate():
    mod = _load()
    assert mod.accept_pass2(_pass1_score(), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass2(_pass1_score(mean=8.9), "lin_wantang", "front", 0.85, 34)
    assert not mod.accept_pass2(_pass1_score(period_hair=True, mean=10), "lin_wantang", "front", 0.85, 34)


def test_prompts_only_change_look_and_clothes():
    mod = _load()
    front = mod.pass1_prompt("lin_wantang", "front")
    text = front + mod.pass2_prompt("lin_wantang")
    assert front.startswith("构图：")
    assert "头和双脚都留在画面内" in front
    assert "不要裁成头肩" in front
    assert mod.FRAME_HARD in front
    assert front.count(mod.FRAME_HARD) == 1
    assert mod.FRAME_HARD in mod.frame_clause()
    assert mod.FRAME_HARD not in mod.face_lock_line("lin_wantang")
    assert mod.FRAME_HARD not in mod.wardrobe_clause("lin_wantang", "front")
    assert "去衣：" in front
    assert front.index("构图：") < front.index(mod.FRAME_HARD) < front.index("锁脸：") < front.index("去衣：")
    assert front.count("去掉背心和短裤。") == 2
    assert "黑褐色" in text
    assert "发髻" in text
    for ban in mod.STORY_BANS + ("接触", "情节"):
        assert ban not in text
    adrian = mod.pass1_prompt("adrian_kane", "front")
    assert adrian.startswith("构图：")
    assert adrian.count("去掉T恤和短裤。") == 2
    assert "尖耳" in adrian
    assert "黑褐色" not in adrian
    assert "浅蓝灰" in adrian
    guide = mod.score_prompt("lin_wantang", "front", "pass1")
    assert "face was redrawn" in guide
    assert "instructed hair or makeup" in guide
    assert "every content score" in guide
    elena = mod.look_line("elena_voss")
    assert "蓝灰" in elena
    assert "琥珀" not in elena
    assert "赤褐" not in elena
    clothed = mod.clothed_prompt("lin_wantang", "front")
    assert clothed.startswith("第一张")
    assert "去衣" not in clothed
    assert "黑褐色" in clothed
    assert "发髻" in clothed
    assert "不要脱掉" in clothed
    assert mod.CLOTHED_SCALE == 0.0
    assert mod.CLOTHED_ENTRY == "codex"
    assert mod.UNDRESS_ENTRY == "f34"
    try:
        mod.require_codex_cli(None)
    except SystemExit as exc:
        assert "CODEX_CLI_MISSING" in str(exc)
    else:
        raise AssertionError("missing Codex CLI must SystemExit")
    try:
        mod.require_codex_cli("/home/ubuntu/.local/bin/codex", logged_in=False)
    except SystemExit as exc:
        assert "CODEX_CLI_LOGGED_OUT" in str(exc)
    else:
        raise AssertionError("logged-out Codex CLI must SystemExit")
    argv = mod.codex_exec_argv("/home/ubuntu/.local/bin/codex", "/tmp/out", ["/tmp/ref.png"])
    assert argv[:2] == ["/home/ubuntu/.local/bin/codex", "exec"]
    assert argv.count("-i") == 1
    assert "/tmp/ref.png" in argv
    assert argv[-1] == "-"
    joined = " ".join(argv).lower()
    assert "agy" not in joined
    assert mod.clothed_seed_for("lin_wantang", "front", 0) == 1
    plate = mod.score_prompt("lin_wantang", "front", "clothed")
    assert "not a nude" in plate
    assert "Nudity is a wardrobe failure" in plate
    up = mod.pass2_prompt("lin_wantang")
    assert up == "只放大。不改脸、身体、衣着、发型、妆。头和双脚仍留在画面内。"
    assert "补上" not in up
    assert "light upscale" in mod.score_prompt("lin_wantang", "front", "pass2")


def test_film_proxy_closes_after_the_one_run():
    mod = _load()
    assert mod.FILM_PROXY_REMAINING == 0
    assert mod.film_proxy_allowed() is False
    assert mod.self_run_line() == "资产自己跑。禁止再让出片代跑。"
    text = (Path(__file__).resolve().parents[1] / "autodl" / "run_cast_body_two_stage.py").read_text(
        encoding="utf-8"
    )
    assert "CAST_ASK_FILM_PROXY" in text
    assert "self_run_line" in text
    assert "run_explicit_two_stage" not in text
    import os
    import sys

    autodl = Path(__file__).resolve().parents[1] / "autodl"
    sys.path.insert(0, str(autodl))
    import run_cast_body_two_stage as runner

    old_argv = sys.argv
    os.environ["CAST_ASK_FILM_PROXY"] = "1"
    sys.argv = ["run_cast_body_two_stage.py", "--login-check"]
    try:
        try:
            runner.main()
        except SystemExit as exc:
            assert str(exc) == mod.self_run_line()
        else:
            raise AssertionError("film proxy request should exit")
    finally:
        sys.argv = old_argv
        os.environ.pop("CAST_ASK_FILM_PROXY", None)


def test_low_identity_or_anatomy_changes_seed_and_blocks_pass2():
    mod = _load()
    assert mod.identity_or_anatomy_below(_pass1_score(identity=8))
    assert mod.identity_or_anatomy_below(_pass1_score(anatomy=8.9))
    assert mod.identity_or_anatomy_below({})
    assert not mod.identity_or_anatomy_below(_pass1_score())
    assert mod.pass2_allowed(False) is False
    assert mod.pass2_allowed(True) is True
    assert mod.identity_or_wardrobe_below(_pass1_score(identity=8))
    assert mod.identity_or_wardrobe_below(_pass1_score(wardrobe=3))
    assert mod.identity_or_wardrobe_below({})
    assert not mod.identity_or_wardrobe_below(_pass1_score())
    assert mod.identity_anatomy_or_wardrobe_below(_pass1_score(anatomy=8))
    assert mod.identity_anatomy_or_wardrobe_below(_pass1_score(wardrobe=2))
    assert not mod.identity_anatomy_or_wardrobe_below(_pass1_score())
    assert mod.seed_for("lin_wantang", "front", 0) == 62
    assert mod.seed_for("lin_wantang", "front", 1) == 63
    assert mod.seed_for("lin_wantang", "front", 2) == 64
    assert mod.advance_seed(33, "lin_wantang", "front") == 62
    assert mod.advance_seed(56, "lin_wantang", "front") == 62
    assert mod.advance_seed(61, "lin_wantang", "front") == 62
    assert all(mod.seed_for("lin_wantang", "front", n) not in mod.LIN_FRONT_SPENT for n in range(6))


def test_diagnosis_keeps_the_prompt_and_records_the_vae_roundoff():
    mod = _load()
    front = mod.pass1_prompt("lin_wantang", "front")
    assert front.count("去掉背心和短裤。") == 2
    assert "白色背心" not in front
    assert "(:" not in front
    assert mod.PASS1_STEPS == 8
    assert mod.ASSET_TRUE_CFG == 4.0
    assert mod.qwen_vae_frame(448, 592) == (448, 576)
    docs = (Path(__file__).resolve().parents[1] / "docs" / "cast-body-two-stage.md").read_text(
        encoding="utf-8"
    )
    assert "不是 worker 越跑越坏" in docs
    assert "不要把去衣句再加长" in docs
    assert "0.7225" in docs


def test_worker_refuses_full_bf16_and_uses_cast_queue():
    path = Path(__file__).resolve().parents[1] / "autodl" / "cast_body_worker.py"
    text = path.read_text(encoding="utf-8")
    assert "refused full BF16" in text
    assert "load_in_8bit=True" in text
    assert 'job.get("true_cfg_scale")' in text
    assert 'pipe.vae.to("cpu")' in text
    assert "cast-asset-job.json" in text
    assert "lora-job.json" not in text
    assert "fuse_lora(lora_scale=scale)" not in text
    assert "fuse_lora(lora_scale=1.0)" in text
    assert "if _fused_scale == scale:" in text
    assert 'job.get("face")' in text
    assert "min(width / image.width, height / image.height)" in text
    assert "center_crop" not in text
    runner = (
        Path(__file__).resolve().parents[1] / "autodl" / "run_cast_body_two_stage.py"
    ).read_text(encoding="utf-8")
    assert "worker_reload" in runner
    assert "sha256sum" in runner


def test_reuse_env_parses_film_handoff():
    import sys

    autodl = Path(__file__).resolve().parents[1] / "autodl"
    sys.path.insert(0, str(autodl))
    import run_cast_body_two_stage as runner

    cfg = runner.parse_reuse_env(
        "\n".join(
            [
                "F34_INSTANCE_UUID=xaxna66hqt-c5c9c7fc",
                "F34_SSH_HOST=connect.weste.seetacloud.com",
                "F34_SSH_PORT=35239",
                "F34_SSH_USER=root",
                "F34_SSH_PASSWORD='abc def'",
                "F34_WEBSITE_TOKEN=eyJreuse",
            ]
        )
    )
    assert cfg["instance_uuid"] == "xaxna66hqt-c5c9c7fc"
    assert cfg["ssh_host"] == "connect.weste.seetacloud.com"
    assert cfg["ssh_port"] == "35239"
    assert cfg["ssh_password"] == "abc def"
    assert cfg["website_token"] == "eyJreuse"
    remote = runner.parse_cast_env(
        "\n".join(
            [
                "AUTODL_SSH_HOST=connect.weste.seetacloud.com",
                "AUTODL_SSH_PORT=35239",
                "AUTODL_SSH_USER=root",
                "AUTODL_SSH_PASSWORD=from-f34",
            ]
        )
    )
    assert remote["ssh_host"] == "connect.weste.seetacloud.com"
    assert remote["ssh_password"] == "from-f34"
    assert "--login-check" in (
        Path(__file__).resolve().parents[1] / "autodl" / "run_cast_body_two_stage.py"
    ).read_text(encoding="utf-8")


def test_shared_store_supplies_password_when_local_tmp_is_missing():
    import os
    import sys
    import tempfile

    autodl = Path(__file__).resolve().parents[1] / "autodl"
    sys.path.insert(0, str(autodl))
    import run_cast_body_two_stage as runner

    with tempfile.TemporaryDirectory() as raw:
        tmp_path = Path(raw)
        shared = tmp_path / "cast-ssh.env"
        shared.write_text(
            "\n".join(
                [
                    "AUTODL_SSH_HOST=connect.weste.seetacloud.com",
                    "AUTODL_SSH_PORT=35239",
                    "AUTODL_SSH_USER=root",
                    "AUTODL_SSH_PASSWORD=from-store",
                ]
            ),
            encoding="utf-8",
        )
        saved = {
            name: getattr(runner, name)
            for name in ("REUSE_JSON", "REUSE_ENV", "CAST_SSH_ENV", "SHARED_CAST_SSH")
        }
        old_pw = os.environ.pop("AUTODL_SSH_PASSWORD", None)
        try:
            runner.REUSE_JSON = tmp_path / "missing.json"
            runner.REUSE_ENV = tmp_path / "missing.env"
            runner.CAST_SSH_ENV = tmp_path / "missing-cast.env"
            runner.SHARED_CAST_SSH = shared
            assert runner.ssh_password_from_disk() == "from-store"
        finally:
            for name, value in saved.items():
                setattr(runner, name, value)
            if old_pw is not None:
                os.environ["AUTODL_SSH_PASSWORD"] = old_pw


def test_gpu_block_is_per_line():
    import sys

    autodl = Path(__file__).resolve().parents[1] / "autodl"
    sys.path.insert(0, str(autodl))
    import run_cast_body_two_stage as runner

    idle = "2 MiB, 0 %\n/usr/bin/python -m jupyter\n"
    assert runner.gpu_block_reason(idle) is None
    busy = "123, python3, 18000 MiB\n"
    assert runner.gpu_block_reason(busy) is not None
    film = "python /root/autodl-tmp/f34_lora_worker.py\n"
    assert "出片" in runner.gpu_block_reason(film)
    ours = "python -u /root/autodl-tmp/cast-asset/worker.py\n"
    assert runner.gpu_block_reason(ours) is None
    ours_gpu = "9231, python, 21892 MiB\n9231 python -u /root/autodl-tmp/cast-asset/worker.py\n"
    assert runner.gpu_block_reason(ours_gpu) is None
    other = "9231, python, 21892 MiB\n9231 python /tmp/other.py\n"
    assert runner.gpu_block_reason(other) is not None


def test_score_log_names_the_item_under_nine_when_mean_is_nine():
    mod = _load()
    item = _pass1_score(distinction=8, mean=9.0)
    look = []
    line = mod.score_log_line(
        "PASS1",
        "lin_wantang",
        "front",
        item,
        look,
        False,
        "scale=0.85 seed=50",
    )
    assert "passed=False" in line
    assert "mean=9.0" in line
    assert "period_hair=" in line and "period_makeup=" in line and "eyes_black_brown=" in line
    for key in mod.EIGHT:
        assert f"{key}=" in line
    assert line.endswith("below=['distinction']") or "below=['distinction']" in line
    record = mod.attempt_record(
        "lin_wantang",
        "front",
        "pass1",
        0.85,
        50,
        item,
        look,
        False,
    )
    assert record["eight"]["distinction"] == 8
    assert record["below"] == ["distinction"]
    assert record["passed"] is False
    assert "full body, head and both feet in frame, no bust/head crop" in (
        Path(__file__).resolve().parents[1] / "docs" / "cast-body-two-stage.md"
    ).read_text(encoding="utf-8")
    docs = (Path(__file__).resolve().parents[1] / "docs" / "cast-body-two-stage.md").read_text(encoding="utf-8")
    assert "没有「三颗就停」" in docs
    assert "seed `62`" in docs
    assert "33`–`61`" in docs


def test_fail_sidecar_json_lists_every_content_score():
    import json
    import sys
    import tempfile

    mod = _load()
    autodl = Path(__file__).resolve().parents[1] / "autodl"
    sys.path.insert(0, str(autodl))
    import run_cast_body_two_stage as runner

    item = _pass1_score(motif=7, mean=9.0)
    record = mod.attempt_record(
        "lin_wantang",
        "front",
        "pass1",
        0.85,
        50,
        item,
        [],
        False,
    )
    with tempfile.TemporaryDirectory() as raw:
        png = Path(raw) / "lin_wantang-front-pass1-seed50.png"
        png.write_bytes(b"png")
        dest = runner.write_attempt_json(png, record)
        assert dest.name == "lin_wantang-front-pass1-seed50.json"
        data = json.loads(dest.read_text(encoding="utf-8"))
    assert data["mean"] == 9.0
    assert data["passed"] is False
    assert data["below"] == ["motif"]
    assert set(data["eight"]) == set(mod.EIGHT)
    assert data["eight"]["motif"] == 7
    text = (Path(__file__).resolve().parents[1] / "autodl" / "run_cast_body_two_stage.py").read_text(
        encoding="utf-8"
    )
    assert text.count("emit_score(") >= 2


def test_runner_does_not_edit_explicit_still_files():
    path = Path(__file__).resolve().parents[1] / "autodl" / "run_cast_body_two_stage.py"
    text = path.read_text(encoding="utf-8")
    assert "run_explicit_two_stage" not in text
    assert "explicit-still-two-stage" not in text
    assert "sa4eaxgcuq" not in text or "G09" in text
    assert "power_on" not in text
    assert "body-clothed" in text
    assert "不拿定妆全身" in text
    assert "CLOTHED_TRY" in text
    assert "require_codex_cli" in text
    assert '"kind": "clothed"' not in text
    assert "agy" not in text.lower()
    worker = (
        Path(__file__).resolve().parents[1] / "autodl" / "cast_body_worker.py"
    ).read_text(encoding="utf-8")
    assert 'kind == "clothed"' in worker
    assert "CODEX_CLI_ONLY" in worker
    docs = Path(__file__).resolve().parents[1] / "docs"
    for name in (
        "cast-body-two-stage.md",
        "explicit-still-two-stage.md",
        "still-score-two-stage.md",
    ):
        page = (docs / name).read_text(encoding="utf-8")
        assert "agy" not in page.lower(), name
        assert "Codex CLI" in page
    assert "2026-10-06-front" in text
    assert "donor_remote" in text
    assert "/root/miniconda3/bin/python" in text
    assert "nohup python -u" not in text
    assert "PASS1_NEW_SEED" in text
    assert "identity_anatomy_or_wardrobe_below" in text
    assert "pass2_allowed" in text
    assert "禁止二采" in text
    assert "PASS1_SEED_TRIES" not in text
    assert "用户叫停" in text
    assert "write_attempt_json" in text
    assert "score_log_line" in text
    assert "while True:" in text
    assert "content=locked" in text
    assert "没有改内容" in text
