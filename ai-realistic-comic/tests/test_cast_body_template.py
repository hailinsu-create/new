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
        "distinction": 8.5,
        "interaction": 9,
        "aesthetics": 9,
        "anatomy": 9,
        "wardrobe": 10,
        "motif": 9,
        "photoreal": 9,
        "mean": 9.0625,
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
    assert mod.PASS1_STEPS == 16
    assert "cast-asset-job.json" in mod.JOB_REMOTE
    assert "lora-job" not in mod.JOB_REMOTE


def test_void_seed_33_never_passes():
    mod = _load()
    assert mod.is_void("lin_wantang", "front", 0.85, 33)
    assert mod.seed_for("lin_wantang", "front", 0) == 34
    score = _pass1_score()
    assert not mod.accept_pass1(score, "lin_wantang", "front", 0.85, 33)
    assert mod.accept_pass1(score, "lin_wantang", "front", 0.85, 34)


def test_pass1_ignores_low_distinction_but_blocks_hair():
    mod = _load()
    assert mod.accept_pass1(_pass1_score(), "lin_wantang", "front", 0.85, 34)
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
    text = mod.pass1_prompt("lin_wantang", "front") + mod.pass2_prompt("lin_wantang")
    assert "黑褐色" in text
    assert "发髻" in text
    assert "背心和短裤" in mod.pass1_prompt("lin_wantang", "front")
    for ban in mod.STORY_BANS:
        assert ban not in text
    adrian = mod.pass1_prompt("adrian_kane", "front")
    assert "尖耳" in adrian
    assert "黑褐色" not in adrian
    assert "浅蓝灰" in adrian


def test_worker_refuses_full_bf16_and_uses_cast_queue():
    path = Path(__file__).resolve().parents[1] / "autodl" / "cast_body_worker.py"
    text = path.read_text(encoding="utf-8")
    assert "refused full BF16" in text
    assert "load_in_8bit=True" in text
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
