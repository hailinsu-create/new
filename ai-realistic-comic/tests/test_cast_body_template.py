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
        "eyes_geometry": True,
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
    assert mod.clothed_passed("gu_chengan", "side")
    assert mod.clothed_passed("gu_chengan", "back")
    assert not mod.clothed_passed("elena_voss", "side")
    assert mod.clothed_passed("adrian_kane", "front")
    male = [pair for pair in mod.NUDE_VIEWS if pair[0] not in mod.FEMALE_ACTORS]
    assert male and all(mod.clothed_passed(*pair) for pair in male)


def test_nine_views_and_fixed_scale():
    mod = _load()
    assert len(mod.NUDE_VIEWS) == 12
    assert mod.NUDE_VIEWS[0] == ("lin_wantang", "front")
    assert ("gu_chengan", "side") in mod.NUDE_VIEWS
    assert ("gu_chengan", "back") in mod.NUDE_VIEWS
    assert ("elena_voss", "side") in mod.NUDE_VIEWS
    assert mod.FIXED_SCALE == 0.85
    assert mod.LIN_FRONT_SEED == 62
    assert 33 in mod.LIN_FRONT_SPENT and 61 in mod.LIN_FRONT_SPENT
    assert 62 in mod.LIN_FRONT_SPENT and 78 in mod.LIN_FRONT_SPENT
    assert 83 in mod.LIN_FRONT_SPENT
    assert 84 in mod.LIN_FRONT_SPENT and 85 in mod.LIN_FRONT_SPENT
    assert 98 in mod.LIN_FRONT_SPENT
    assert 99 not in mod.LIN_FRONT_SPENT
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
    assert mod.seed_for("lin_wantang", "front", 0) == 99
    assert mod.LIN_FRONT_A_CHECK == (62, 70, 78)
    assert mod.B_PASS1_STEPS == 16
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
    assert not mod.accept_pass1(
        _pass1_score(eyes_geometry=False, eyes_black_brown=True, identity=9),
        "lin_wantang",
        "front",
        0.85,
        34,
    )
    capped = mod.cap_identity_for_eyes(
        _pass1_score(eyes_geometry=False, identity=9, wardrobe=10)
    )
    assert capped["identity"] == 7
    assert capped["wardrobe"] == 10
    small = mod.resolve_eyes(
        _pass1_score(eyes_geometry=False, eyes_structure=True, eyes_detail=False, identity=9),
        137,
    )
    assert small["eyes_geometry"] is True
    assert small["identity"] == 9
    broken = mod.resolve_eyes(
        _pass1_score(eyes_structure=False, eyes_detail=True, identity=9),
        137,
    )
    assert broken["eyes_geometry"] is False
    assert broken["identity"] == 7
    large = mod.resolve_eyes(
        _pass1_score(eyes_structure=True, eyes_detail=False, identity=9),
        280,
    )
    assert large["eyes_geometry"] is False
    assert large["identity"] == 7
    assert "EYES_GEOMETRY" in mod.look_gates(
        "lin_wantang", "front", _pass1_score(eyes_geometry=False)
    )
    assert not mod.accept_pass1(_pass1_score(gates=["H7"]), "lin_wantang", "front", 0.85, 34)
    missing = _pass1_score()
    del missing["period_hair"]
    assert not mod.accept_pass1(missing, "lin_wantang", "front", 0.85, 34)


def test_background_eaten_skips_the_scorer():
    from PIL import Image

    mod = _load()
    gray = Image.new("RGB", (448, 592), (198, 198, 198))
    gray_path = "/tmp/cast-gray-body.png"
    gray.save(gray_path)
    assert mod.torso_eaten_by_background(gray_path)
    person = gray.copy()
    for x in range(160, 300):
        for y in range(30, 110):
            person.putpixel((x, y), (36, 28, 24))
        for y in range(180, 280):
            person.putpixel((x, y), (214, 170, 148))
    person_path = "/tmp/cast-person-body.png"
    person.save(person_path)
    assert not mod.torso_eaten_by_background(person_path)


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
    assert front.count("胸腹髋腿只留皮肤，不要背心短裤内衣。") == 2
    assert "身体不动" not in front
    assert "只锁五官和肤色" in front
    assert "第二张只有头" in front
    assert "不要从第二张带衣服" in front
    assert "第二张图是锁脸" not in front
    back = mod.pass1_prompt("lin_wantang", "back")
    assert "第二张" not in back
    assert "背面不喂锁脸" in back
    assert mod.feeds_face("front") and mod.feeds_face("side")
    assert not mod.feeds_face("back")
    assert mod.ref_face_rel("lin_wantang") == "library/cast/lin_wantang/ref-face.png"
    assert "站姿" not in mod.face_lock_line("lin_wantang")
    assert "脸型" not in mod.face_lock_line("lin_wantang")
    assert "无情节的成年全身站姿模板" in mod.SCORE_PREFIX
    assert "wardrobe 最高 6" in mod.SCORE_PREFIX
    assert "below 200" in mod.SCORE_PREFIX
    assert "胸腹髋腿还有布则 motif<9" in mod.SCORE_PREFIX
    assert "至少给 9" not in mod.SCORE_PREFIX
    assert mod.KEEP_MEAN == 9.0
    for ban in mod.STORY_BANS + ("接触", "情节"):
        assert ban not in text
    adrian = mod.pass1_prompt("adrian_kane", "front")
    assert adrian.startswith("构图：")
    assert adrian.count("胸腹髋腿只留皮肤，不要背心短裤内衣。") == 2
    assert "只锁五官和肤色" in adrian
    assert "身体不动" not in adrian
    assert "尖耳" in mod.look_line("adrian_kane")
    images = ["/tmp/lock.png", "/tmp/eyes.jpg", "/tmp/plate.png"]
    call = mod.score_call("lin_wantang", "front", "pass1", images)
    assert call.startswith(mod.SCORE_PREFIX)
    tail = call[len(mod.SCORE_PREFIX) :]
    assert "face was redrawn" in mod.SCORE_PREFIX
    assert "instructed hair or makeup" in mod.SCORE_PREFIX
    assert "every content score" in mod.SCORE_PREFIX
    assert "face was redrawn" not in tail
    assert "every content score" not in tail
    assert "/tmp/plate.png" in tail
    assert "opencode" not in call.lower()
    gu_look = mod.look_line("gu_chengan")
    assert "发套" in gu_look
    assert "发箍" in gu_look
    assert "发套" not in mod.look_line("adrian_kane")
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
    assert "not a nude" in mod.SCORE_PREFIX
    assert "Nudity is a wardrobe failure" in mod.SCORE_PREFIX
    clothed_call = mod.score_call("lin_wantang", "front", "clothed", images)
    clothed_tail = clothed_call[len(mod.SCORE_PREFIX) :]
    assert clothed_call.startswith(mod.SCORE_PREFIX)
    assert clothed_call[: len(mod.SCORE_PREFIX)] == call[: len(mod.SCORE_PREFIX)]
    assert "not a nude" not in clothed_tail
    assert "Nudity is a wardrobe failure" not in clothed_tail
    up = mod.pass2_prompt("lin_wantang")
    assert up == "只放大。不改脸、身体、衣着、发型、妆。头和双脚仍留在画面内。"
    assert "补上" not in up
    assert "light upscale" in mod.SCORE_PREFIX
    pass2_call = mod.score_call(
        "elena_voss",
        "back",
        "pass2",
        ["/tmp/elena-lock.png", "/tmp/elena-eyes.jpg", "/tmp/elena-plate.png"],
    )
    assert pass2_call.startswith(mod.SCORE_PREFIX)
    assert "light upscale" not in pass2_call[len(mod.SCORE_PREFIX) :]
    assert pass2_call[: len(mod.SCORE_PREFIX)] == mod.SCORE_PREFIX
    try:
        mod.score_exec_argv("/home/ubuntu/.local/bin/codex", logged_in=False, cwd="/tmp", images=images)
    except SystemExit as exc:
        assert "CODEX_CLI_LOGGED_OUT" in str(exc)
    else:
        raise AssertionError("logged-out score path must SystemExit")
    score_argv = mod.score_exec_argv("/home/ubuntu/.local/bin/codex", logged_in=True, cwd="/tmp", images=images)
    score_joined = " ".join(score_argv).lower()
    assert "opencode" not in score_joined
    assert "deepseek-v4-flash-vision" not in score_joined
    assert "agy" not in score_joined
    assert score_argv.count("-i") == 3
    grok_argv = mod.grok_score_argv(
        "/home/ubuntu/.opencode/bin/opencode",
        ["/tmp/lock.png", "/tmp/eyes.jpg", "/tmp/plate.png"],
        "score this",
    )
    assert grok_argv.index("score this") < grok_argv.index("-f")
    assert "opencode-go/grok-4.7" in grok_argv
    assert "xhigh" in grok_argv
    assert grok_argv.count("-f") == 3
    assert "deepseek" not in " ".join(grok_argv).lower()
    assert mod.codex_should_fallback(1, "usage limit")
    assert mod.codex_should_fallback(None, "codex missing or logged out")
    assert not mod.codex_should_fallback(0, "ok")
    local = mod.local_background_score()
    assert local["scorer"] == "local"
    assert local["wardrobe"] <= 6
    assert mod.f34_should_power_on(has_work=True, hold_off=False) is True
    assert mod.f34_should_power_on(has_work=False, hold_off=False) is False
    assert mod.f34_should_power_on(has_work=True, hold_off=True) is False
    assert mod.f34_should_power_off(finished=True, paused=False, keep_on=False) is True
    assert mod.f34_should_power_off(finished=False, paused=True, keep_on=False) is True
    assert mod.f34_should_power_off(finished=True, paused=False, keep_on=True) is False
    assert mod.f34_should_power_off(finished=False, paused=False, keep_on=False) is False
    assert "关机留盘" in mod.F34_POWER_RULE
    assert "空转" in mod.F34_POWER_RULE


def test_parse_score_keeps_the_last_score_object():
    mod = _load()
    text = (
        'noise {"gates":[],"identity":0,"mean":0} '
        '{"gates":[],"identity":9,"distinction":9,"mean":9.1,"note":"ok"} tail'
    )
    item = mod.parse_score(text)
    assert item["identity"] == 9
    assert item["mean"] == 9.1
    single = mod.parse_score('noise {"gates": [], "mean": 9.2, "note": "ok"} tail')
    assert single["mean"] == 9.2


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
    assert mod.seed_for("lin_wantang", "front", 0) == 99
    assert mod.seed_for("lin_wantang", "front", 1) == 99
    assert mod.seed_for("lin_wantang", "front", 2) == 99
    assert mod.advance_seed(33, "lin_wantang", "front") == 99
    assert mod.advance_seed(62, "lin_wantang", "front") == 99
    assert mod.advance_seed(83, "lin_wantang", "front") == 99
    assert mod.advance_seed(98, "lin_wantang", "front") == 99
    assert mod.parse_specified_seeds("62,70,78") == [62, 70, 78]
    assert mod.require_specified_seed(84, "lin_wantang", "front") == 84
    assert mod.require_specified_seed(62, "lin_wantang", "front") == 62
    assert mod.require_specified_seed(70, "lin_wantang", "front") == 70
    assert mod.require_specified_seed(78, "lin_wantang", "front") == 78
    try:
        mod.require_specified_seed(None, "lin_wantang", "front")
    except SystemExit:
        pass
    else:
        raise AssertionError("a missing seed must stop")
    try:
        mod.require_specified_seed(33, "lin_wantang", "front")
    except SystemExit:
        pass
    else:
        raise AssertionError("void seed 33 must stop")
    assert all(mod.seed_for("lin_wantang", "front", n) not in mod.LIN_FRONT_SPENT for n in range(6))
    low = [{"passed": False, "wardrobe": 2} for _ in range(3)]
    assert mod.scheme_after_named_pass1(low) == "scheme_b"
    mixed = [
        {"passed": False, "wardrobe": 2},
        {"passed": False, "wardrobe": 7},
        {"passed": False, "wardrobe": 2},
    ]
    assert mod.scheme_after_named_pass1(mixed) == "stop_or_expand"
    middle = [{"passed": False, "wardrobe": 5} for _ in range(3)]
    assert mod.scheme_after_named_pass1(middle) == "stop"
    one_pass = [
        {"passed": True, "wardrobe": 9},
        {"passed": False, "wardrobe": 2},
        {"passed": False, "wardrobe": 2},
    ]
    assert mod.scheme_after_named_pass1(one_pass) == "stop_or_expand"


def test_diagnosis_keeps_the_prompt_and_records_the_vae_roundoff():
    mod = _load()
    front = mod.pass1_prompt("lin_wantang", "front")
    assert front.count("胸腹髋腿只留皮肤，不要背心短裤内衣。") == 2
    assert "白色背心" not in front
    assert "(:" not in front
    assert mod.PASS1_STEPS == 8
    assert mod.ASSET_TRUE_CFG == 4.0
    assert mod.qwen_vae_frame(448, 592) == (448, 576)
    docs = (Path(__file__).resolve().parents[1] / "docs" / "cast-body-two-stage.md").read_text(
        encoding="utf-8"
    )
    assert "不是 worker 越跑越坏" in docs
    assert "胸腹髋腿只留皮肤" in docs
    assert "无情节的成年全身站姿模板" in docs
    assert "eyes_geometry" in docs
    assert "已撤" in docs
    assert "ref-face.png" in docs
    assert "grok-4.7-xhigh" in docs
    assert "背面不喂" in docs
    assert "wardrobe 最高 6" in docs or "最高 6" in docs
    assert "不扫" in docs
    assert "指定籽" in docs
    assert "已退役" in docs
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
    assert text.index("images = [src]") < text.index("images.append(face)")
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
    assert "指定籽" in docs
    assert "未过门不进二采" in docs
    assert "seed `62`" in docs
    assert "33`–`61`" in docs
    assert "33`–`83`" in docs
    assert "86`–`98`" in docs
    assert "从 `99` 起" in docs


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
    assert "power_on" in text
    assert "F34_UUID" in text or "tpl.F34_UUID" in text
    assert "body-clothed" in text
    assert "不拿定妆全身" in text
    assert "CLOTHED_TRY" in text
    assert "require_codex_cli" in text
    assert '"kind": "clothed"' not in text
    assert "agy" not in text.lower()
    assert "opencode-go/grok-4.7" not in text.lower() or "grok_score_argv" in text
    assert "deepseek-v4-flash-vision" not in text
    assert "grok_binary" in text
    assert "SCORER_FALLBACK" in text
    assert "score_call" in text
    assert "score_exec_argv" in text
    assert "SCORE_PREFIX" in text
    assert "f34_shutdown_hook" in text
    assert "f34_power_for_work" in text
    assert "power_off" in text
    assert "--keep-on" in text
    assert "--hold-off" in text
    assert "release" not in text.lower()
    assert "score_prompt" not in text
    template = (
        Path(__file__).resolve().parents[1] / "autodl" / "cast_body_template.py"
    ).read_text(encoding="utf-8")
    assert "SCORE_PREFIX" in template
    assert "score_call" in template
    assert "score_prompt" not in template
    assert "face was redrawn" in template
    assert "Eight equal scores" in template
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
    score_entry = (docs / "codex-cast-score.md").read_text(encoding="utf-8")
    cast_doc = (docs / "cast-body-two-stage.md").read_text(encoding="utf-8")
    assert "Codex CLI" in score_entry
    assert "SCORE_PREFIX" in score_entry
    assert "固定标准前缀" in cast_doc
    assert "关机留盘" in cast_doc
    assert "空转" in cast_doc
    assert "不得只留在本机" in cast_doc
    assert "推到 GitHub" in cast_doc
    assert "发套" in cast_doc
    assert "发箍" in cast_doc
    assert "改脚本" in cast_doc
    assert "文档与代码不一致算漂移" in cast_doc
    assert "不得只留在本机" in score_entry
    assert "文档与代码不一致算漂移" in score_entry
    template_text = (
        Path(__file__).resolve().parents[1] / "autodl" / "cast_body_template.py"
    ).read_text(encoding="utf-8")
    for banned in ("face was redrawn", "Nudity is a wardrobe failure", "light upscale"):
        assert banned not in text
        assert banned in template_text
    assert "2026-10-06-front" in text
    assert "donor_remote" in text
    assert "/root/miniconda3/bin/python" in text
    assert "nohup python -u" not in text
    assert "指定籽不递增" in text
    assert "SCHEME_AFTER_A" in text
    assert "--research" in text
    assert "PROBE_ONCE" in text
    assert "RESEARCH_DONE" in text
    assert "ref.png" in text
    assert "ref_face_rel" in text
    assert "feeds_face" in text
    assert "torso_eaten_by_background" in text
    assert "grok_score_argv" in text
    assert "SCORER_FALLBACK" in text
    assert "eye_crop" in text
    assert "SCORE_DEFERRED" in text
    assert "PASS1_NEW_SEED" not in text
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
    assert "fetch failed" in text
    until = text.split("def run_until_pass2", 1)[1].split("\ndef parse_only", 1)[0]
    assert "SCORE_FAILED" in until
    assert "SCORE_DEFERRED" in until
    assert "TimeoutExpired" in text


def test_fetch_retries_transient_oserror(tmp_path):
    import sys

    autodl = Path(__file__).resolve().parents[1] / "autodl"
    sys.path.insert(0, str(autodl))
    import run_cast_body_two_stage as runner

    calls = {"n": 0}

    class FakeSftp:
        def get(self, remote, local):
            calls["n"] += 1
            if calls["n"] < 3:
                raise OSError("input/output error")
            Path(local).write_bytes(b"ok")

        def close(self):
            return None

    class FakeClient:
        def open_sftp(self):
            return FakeSftp()

    remote = runner.Remote(FakeClient())
    original = runner.time.sleep
    runner.time.sleep = lambda *_a, **_k: None
    try:
        dest = tmp_path / "out.png"
        remote.fetch("/root/autodl-tmp/out.png", dest)
        assert calls["n"] == 3
        assert dest.read_bytes() == b"ok"
        calls["n"] = 0

        class AlwaysFail:
            def get(self, remote, local):
                calls["n"] += 1
                raise OSError("input/output error")

            def close(self):
                return None

        remote.client = type("C", (), {"open_sftp": lambda self: AlwaysFail()})()
        try:
            remote.fetch("/root/autodl-tmp/missing.png", tmp_path / "missing.png")
        except OSError as exc:
            assert "fetch failed" in str(exc)
        else:
            raise AssertionError("expected fetch failure")
        assert calls["n"] == 3
    finally:
        runner.time.sleep = original
