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
    assert mod.clothed_passed("lin_wantang", "front")
    assert not mod.clothed_passed("gu_chengan", "side")
    assert not mod.clothed_passed("gu_chengan", "back")
    assert not mod.clothed_passed("elena_voss", "side")
    assert all(mod.clothed_passed(*pair) for pair in mod.NUDE_VIEWS)


def test_nine_views_and_fixed_scale():
    mod = _load()
    assert len(mod.NUDE_VIEWS) == 9
    assert ("gu_chengan", "side") not in mod.NUDE_VIEWS
    assert ("elena_voss", "side") not in mod.NUDE_VIEWS
    assert mod.FIXED_SCALE == 0.85
    assert mod.LIN_FRONT_SEED == 34
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
    assert mod.seed_for("lin_wantang", "front", 0) == 34
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
    assert front.startswith("锁脸、锁身体。只改衣着、发型、妆。")
    assert "黑褐色" in text
    assert "发髻" in text
    assert "背心和短裤" in front
    for ban in mod.STORY_BANS + ("接触", "情节"):
        assert ban not in text
    adrian = mod.pass1_prompt("adrian_kane", "front")
    assert adrian.startswith("锁脸、锁身体。只改衣着、发型、妆。")
    assert "尖耳" in adrian
    assert "黑褐色" not in adrian
    assert "浅蓝灰" in adrian
    guide = mod.score_prompt("lin_wantang", "front", "pass1")
    assert "face was redrawn" in guide
    assert "instructed hair or makeup" in guide
    assert "every content score" in guide
    up = mod.pass2_prompt("lin_wantang")
    assert up == "只放大。不改脸、身体、衣着、发型、妆。"
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
    assert mod.seed_for("lin_wantang", "front", 0) == 34
    assert mod.seed_for("lin_wantang", "front", 1) == 35
    assert mod.seed_for("lin_wantang", "front", 2) == 36


def test_worker_refuses_full_bf16_and_uses_cast_queue():
    path = Path(__file__).resolve().parents[1] / "autodl" / "cast_body_worker.py"
    text = path.read_text(encoding="utf-8")
    assert "refused full BF16" in text
    assert "load_in_8bit=True" in text
    assert 'job.get("true_cfg_scale")' in text
    assert 'pipe.vae.to("cpu")' in text
    assert "cast-asset-job.json" in text
    assert "lora-job.json" not in text


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


def test_runner_does_not_edit_explicit_still_files():
    path = Path(__file__).resolve().parents[1] / "autodl" / "run_cast_body_two_stage.py"
    text = path.read_text(encoding="utf-8")
    assert "run_explicit_two_stage" not in text
    assert "explicit-still-two-stage" not in text
    assert "sa4eaxgcuq" not in text or "G09" in text
    assert "power_on" not in text
    assert "body-clothed" in text
    assert "不拿定妆全身" in text
    assert "PASS1_NEW_SEED" in text
    assert "pass2_allowed" in text
    assert "禁止二采" in text
    assert "content=locked" in text
    assert "没有改内容" in text
