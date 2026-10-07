"""Semantic undress pipeline: mask math, graphs, and the Codex-only scorer."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
COMFY = ROOT / "workflows" / "comfyui"
sys.path.insert(0, str(COMFY))


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, COMFY / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


sem = _load("semantic_undress")
score = _load("codex_still_score")
run = _load("run_fox_centaur_semantic")

SHAPE = (1536, 1024)


def _rect(x0, y0, x1, y1):
    arr = np.zeros(SHAPE, dtype=bool)
    arr[y0:y1, x0:x1] = True
    return arr


def test_garment_mask_subtracts_face_tails_and_stays_in_roi():
    garment = _rect(330, 300, 560, 900)
    tails = _rect(520, 300, 700, 900)
    outside_roi = _rect(0, 0, 100, 100)
    mask = sem.build_garment_mask(
        sem.LIN,
        SHAPE,
        segformer=garment | outside_roi,
        dino_garment={"qipao": garment},
        dino_protect={"fox tail": tails},
    )
    assert mask[500, 400]
    assert not mask[500, 560]
    assert not mask[50, 50]
    assert not mask[100, 400]


def test_horse_guard_does_not_eat_armor_that_dino_names():
    armor = _rect(300, 600, 540, 780)
    horse = _rect(150, 700, 800, 1100)
    kept = sem.build_garment_mask(
        sem.ELENA,
        SHAPE,
        segformer=None,
        dino_garment={"fauld": armor},
        dino_protect={},
        dino_horse={"horse body": horse},
    )
    assert kept[740, 420]
    plain = sem.build_garment_mask(
        sem.ELENA,
        SHAPE,
        segformer=armor,
        dino_garment={"gorget": _rect(300, 600, 540, 640)},
        dino_protect={},
        dino_horse={"horse body": horse},
    )
    assert not plain[760, 420]
    assert plain[630, 420]


def test_segformer_horse_false_positive_is_dropped_without_dino_support():
    coat = _rect(300, 700, 500, 800)
    breastplate = _rect(300, 300, 500, 500)
    mask = sem.build_garment_mask(
        sem.ELENA,
        SHAPE,
        segformer=coat | breastplate,
        dino_garment={"breastplate": breastplate},
        dino_protect={},
    )
    assert mask[400, 400]
    assert not mask[750, 400]


def test_tear_mask_leaves_remnants_and_keeps_bands():
    garment = _rect(330, 300, 560, 1100)
    torn = sem.tear_mask(garment, seed=7, fraction=0.6, keep_top_frac=0.07, keep_bottom_frac=0.18)
    share = torn.sum() / garment.sum()
    assert 0.25 < share < 0.95
    assert (torn & ~garment).sum() == 0
    assert not torn[300:350, :].any()
    assert not torn[960:1100, :].any()
    again = sem.tear_mask(garment, seed=7, fraction=0.6, keep_top_frac=0.07, keep_bottom_frac=0.18)
    assert (torn == again).all()
    other = sem.tear_mask(garment, seed=8, fraction=0.6, keep_top_frac=0.07, keep_bottom_frac=0.18)
    assert (torn != other).any()


def test_residual_ratio_and_bands():
    before = _rect(100, 100, 300, 1000)
    assert sem.residual_ratio(before, np.zeros_like(before)) == 0.0
    assert abs(sem.residual_ratio(before, _rect(100, 100, 200, 1000)) - 0.5) < 1e-6
    bands = run.split_bands(before)
    assert len(bands) == 3
    assert (np.logical_or.reduce(bands) == before).all()


def test_graphs_use_semantic_nodes_and_unique_save_ids():
    seg = sem.segformer_graph("plate.png")
    flags = seg["2"]["inputs"]
    assert flags["Dress"] and flags["Upper-clothes"] and not flags["Face"] and not flags["Hair"]
    prompts = ("qipao", "face", "fox tail")
    graph = sem.dino_masks_graph("plate.png", prompts)
    ids = sem.dino_save_ids(prompts)
    assert len(set(ids.values())) == 3
    for node in ids.values():
        assert graph[node]["class_type"] == "SaveImage"
    assert graph["10"]["class_type"] == sem.DINO_SAM_NODE


def test_inpaint_graph_is_fill_then_fooocus_without_diff_on_cloth_pass():
    legacy = sys.modules["scheme_still_fox_centaur_undress"]
    graph = legacy.inpaint_crop_graph(
        ckpt="RealVisXL_V5.0_fp16.safetensors",
        crop_name="c.png",
        mask_name="m.png",
        positive="skin",
        negative="cloth",
        seed=1,
        prefix="t",
        denoise=1.0,
        fooocus=True,
        differential=False,
        masked_fill=True,
        fill_mode="neutral",
    )
    assert graph["51"]["inputs"]["fill"] == "neutral"
    assert graph["71"]["class_type"] == "INPAINT_ApplyFooocusInpaint"
    assert "72" not in graph
    assert "Telea" not in json.dumps(graph) and "NS" not in graph["51"]["inputs"]["fill"]


def test_scorer_missing_cli_is_score_failed_and_never_grok(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(score, "codex_binary", lambda: None)
    image = tmp_path / "lin-qipao-nine-tail-nude.png"
    Image.new("RGB", (8, 8)).save(image)
    result = score.score_image("lin", "nude", image)
    assert result["score_failed"] and result["reason"] == "cli_missing"
    assert result["line"] == "SCORE_FAILED codex lin nude reason=cli_missing"
    assert "SCORE_FAILED codex lin nude reason=cli_missing" in capsys.readouterr().out
    assert json.loads(image.with_suffix(".json").read_text())["passed"] is False
    assert image.with_suffix(".score-fail.json").exists()
    source = (COMFY / "codex_still_score.py").read_text(encoding="utf-8")
    code = source.split('"""', 2)[2].lower()
    for banned in ("grok", "deepseek", "opencode", "kimi", "agy"):
        assert banned not in code


def test_parse_and_normalise_score():
    text = 'noise {"identity":9,"distinction":9,"interaction":9,"aesthetics":9,"anatomy":9,"wardrobe":9,"motif":9,"photoreal":8,"gates":[],"notes":"x"} tail'
    item = score.normalise(score.parse_score(text))
    assert item["mean"] == 8.875 and item["below"] == ["photoreal"] and item["passed"] is False
    gated = score.normalise({**score.parse_score(text), "photoreal": 9, "gates": ["armor_remain"]})
    assert gated["mean"] == 9.0 and gated["passed"] is False


def test_forbidden_hosts_and_install_script_never_name_f34_or_g09():
    try:
        run.check_host("http://connect.weste.seetacloud.com:8188")
    except SystemExit as exc:
        assert "FORBIDDEN_HOST" in str(exc)
    else:
        raise AssertionError("F34 host accepted")
    script = (COMFY / "install_undress_stack.sh").read_text(encoding="utf-8")
    assert "xaxna66hqt" not in script and "sa4eaxgcuq" not in script


def test_emitted_examples_match_the_runner(tmp_path):
    run.emit_examples(tmp_path)
    names = sorted(p.name for p in tmp_path.glob("scheme-semantic-*.api.json"))
    assert len(names) == 8
    nude = json.loads((tmp_path / "scheme-semantic-inpaint-lin-nude.api.json").read_text())
    assert nude["prompt"]["15"]["inputs"]["denoise"] == 1.0
    assert nude["prompt"]["51"]["inputs"]["fill"] == "neutral"
    assert "72" not in nude["prompt"]
    edge = json.loads((tmp_path / "scheme-semantic-edge.api.json").read_text())
    assert edge["prompt"]["72"]["class_type"] == "DifferentialDiffusion" and "51" not in edge["prompt"]
    committed = json.loads((COMFY / "scheme-semantic-inpaint-lin-nude.api.json").read_text())
    assert committed == nude


def test_segformer_graph_can_read_an_image_output():
    graph = sem.segformer_graph("plate.png", kind="IMAGE", slot=0)
    assert graph["4"]["inputs"]["images"] == ["2", 0]
    assert "3" not in graph
    default = sem.segformer_graph("plate.png")
    assert default["3"]["inputs"]["mask"] == ["2", 1]


def test_dino_batch_failure_falls_back_per_prompt(tmp_path, monkeypatch):
    calls = []

    def fake_run_graph(host, graph, outputs, work, tag):
        calls.append(tag)
        if len(outputs) > 1:
            raise SystemExit("RUN_FAILED batch")
        if "dino1" in tag:
            raise SystemExit("RUN_FAILED no hit")
        path = tmp_path / f"{tag}.png"
        Image.new("L", (16, 16), 255).save(path)
        return {"p": path}

    monkeypatch.setattr(run, "run_graph", fake_run_graph)
    got = run.dino_by_prompt("http://127.0.0.1:8188", "x.png", ("a", "b", "c"), 1, tmp_path, "t", (16, 16))
    assert got["a"].all() and got["c"].all() and not got["b"].any()
    assert len(calls) == 4


def _fake_backend(monkeypatch, plan_name):
    """No ComfyUI: segmentation returns boxes, inpaint paints the masked crop pixels skin-coloured."""
    legacy = sys.modules["scheme_still_fox_centaur_undress"]
    plan = sem.PLANS[plan_name]
    shape = (1536, 1024)
    torso = {"lin": _rect(340, 320, 560, 1150), "elena": _rect(300, 260, 500, 560)}[plan_name]
    state = {"segments": 0}

    def fake_segment(host, image_path, plan_, work, tag, input_dir):
        state["segments"] += 1
        garment_left = torso if state["segments"] == 1 else np.zeros(shape, dtype=bool)
        garment = {plan_.garment_prompts[0]: garment_left}
        protect = {plan_.protect_prompts[0]: _rect(380, 40, 560, 280)}
        return sem.MaskEvidence(segformer=None, garment=garment, protect=protect, horse={})

    def fake_run_graph(host, graph, outputs, work, tag):
        crop = Image.open(Path(state["input_dir"]) / graph["1"]["inputs"]["image"]).convert("RGB")
        mask = Image.open(Path(state["input_dir"]) / graph["2"]["inputs"]["image"]).convert("L")
        skin = Image.new("RGB", crop.size, (214, 170, 150))
        if "51" not in graph:
            out = crop
        else:
            out = Image.composite(skin, crop, mask.point(lambda v: 255 if v > 40 else 0))
        dest = Path(work) / f"{tag}-crop.png"
        out.save(dest)
        return {"crop": dest}

    monkeypatch.setattr(run, "segment", fake_segment)
    monkeypatch.setattr(run, "run_graph", fake_run_graph)
    monkeypatch.setattr(run, "upload", lambda host, path: None)
    return state


def test_end_to_end_with_fake_comfy_keeps_face_and_clears_garment(tmp_path, monkeypatch):
    plate = sys.modules["scheme_still_fox_centaur_undress"].LIN_PLATE
    if not plate.exists():
        return
    state = _fake_backend(monkeypatch, "lin")
    state["input_dir"] = tmp_path / "in"
    out = tmp_path / "out"
    dest = run.undress_one("http://127.0.0.1:8188", {"ckpt": "x"}, "lin", "nude", out, tmp_path / "in", attempt=0)
    result = Image.open(dest).convert("RGB")
    source = Image.open(plate).convert("RGB")
    assert result.size == source.size == (1024, 1536)
    face = (380, 40, 560, 280)
    assert np.array_equal(np.asarray(result.crop(face)), np.asarray(source.crop(face)))
    cx, cy = 450, 700
    assert np.abs(np.asarray(result)[cy, cx].astype(int) - np.array([214, 170, 150])).max() < 40
    meta = json.loads((out / "lin-qipao-nine-tail-nude.run.json").read_text())
    kinds = [p["kind"] for p in meta["passes"]]
    assert kinds == ["nude", "edge"] and meta["passes"][0]["residual_ratio"] == 0.0
    assert (out / "debug" / "lin-qipao-nine-tail-nude-garment-overlay.png").exists()


def test_end_to_end_torn_leaves_remnants(tmp_path, monkeypatch):
    plate = sys.modules["scheme_still_fox_centaur_undress"].ELENA_PLATE
    if not plate.exists():
        return
    state = _fake_backend(monkeypatch, "elena")
    state["input_dir"] = tmp_path / "in"
    out = tmp_path / "out"
    dest = run.undress_one("http://127.0.0.1:8188", {"ckpt": "x"}, "elena", "torn", out, tmp_path / "in", attempt=0)
    result = np.asarray(Image.open(dest).convert("RGB")).astype(int)
    source = np.asarray(Image.open(plate).convert("RGB")).astype(int)
    region = (slice(260, 560), slice(300, 500))
    changed = (np.abs(result[region] - source[region]).sum(axis=2) > 30).mean()
    assert 0.15 < changed < 0.9


power = _load("autodl_power")


def test_power_on_uses_web_endpoint_gpu_payload_and_backs_off_on_no_gpu(monkeypatch):
    sent = []
    replies = iter(
        [
            (200, {"code": "InstanceError", "msg": "该主机空闲GPU不足，主机GPU空闲数量：0 卡"}),
            (200, {"code": "InstanceError", "msg": "该主机空闲GPU不足"}),
            (200, {"code": "Success", "msg": ""}),
        ]
    )

    def fake_post(url, headers, body, timeout=30):
        sent.append((url, headers, body))
        return next(replies)

    monkeypatch.setattr(power, "post", fake_post)
    waits = []
    code = power.power_on_loop("359a49a1c3-4cda10df", "JWT", max_minutes=60, sleep=waits.append, now=lambda: 0.0)
    assert code == 0 and waits == [20, 30]
    url, headers, body = sent[0]
    assert url == "https://www.autodl.com/api/v1/instance/power_on"
    assert headers == {"Authorization": "JWT"}
    assert body == {"instance_uuid": "359a49a1c3-4cda10df", "payload": "gpu"}


def test_power_on_stops_on_auth_failure_and_on_deadline(monkeypatch):
    monkeypatch.setattr(power, "post", lambda *a, **k: (401, {"code": "AuthorizeFailed", "msg": "token expired"}))
    assert power.power_on_loop("u", "JWT", max_minutes=60, sleep=lambda s: None, now=lambda: 0.0) == 2
    monkeypatch.setattr(power, "post", lambda *a, **k: (200, {"code": "X", "msg": "空闲GPU不足"}))
    clock = iter(range(0, 100000, 100))
    assert power.power_on_loop("u", "JWT", max_minutes=1, sleep=lambda s: None, now=lambda: float(next(clock))) == 3


def test_power_on_refuses_f34_g09_and_never_prints_the_secret(monkeypatch, capsys, tmp_path):
    for uuid in ("xaxna66hqt-c5c9c7fc", "sa4eaxgcuq-26e36fc9"):
        try:
            power.instance_uuid(uuid)
        except SystemExit as exc:
            assert "FORBIDDEN_INSTANCE" in str(exc)
        else:
            raise AssertionError(uuid)
    monkeypatch.setattr(power, "post", lambda *a, **k: (200, {"code": "Success"}))
    power.power_on_loop("359a49a1c3-4cda10df", "SECRET-JWT-VALUE", max_minutes=1)
    assert "SECRET-JWT-VALUE" not in capsys.readouterr().out
    env = tmp_path / "a.env"
    env.write_text("AUTODL_WEB_AUTHORIZATION=abc\n# c\nOTHER='x'\n")
    assert power.read_env_file(env) == {"AUTODL_WEB_AUTHORIZATION": "abc", "OTHER": "x"}


def test_balance_pending_without_token_and_uses_dev_endpoint(monkeypatch, capsys):
    monkeypatch.setattr(power, "dev_token", lambda: None)
    assert power.balance() == 1 and "BALANCE_PENDING" in capsys.readouterr().out
    seen = []
    monkeypatch.setattr(power, "dev_token", lambda: "TOKEN")
    monkeypatch.setattr(power, "post", lambda url, h, b, timeout=30: (seen.append(url) or (200, {"code": "Success", "data": {"assets": 4200}})))
    assert power.balance() == 0
    out = capsys.readouterr().out
    assert seen == ["https://api.autodl.com/api/v1/dev/wallet/balance"]
    assert "yuan=4.20" in out and "BALANCE_WARNING" in out and "TOKEN" not in out


bring = _load("bringup_and_run")


def test_ensure_on_layers_web_jwt_then_dev_token_then_need_token(monkeypatch, capsys):
    monkeypatch.setattr(power, "web_authorization", lambda: None)
    monkeypatch.setattr(power, "dev_token", lambda: None)
    assert power.ensure_on("359a49a1c3-4cda10df", max_minutes=1) == 4
    assert "NEED_AUTODL_TOKEN" in capsys.readouterr().out

    monkeypatch.setattr(power, "dev_token", lambda: "TOK")
    monkeypatch.setattr(power, "post", lambda url, h, b, timeout=30: (200, {"code": "RecordNotFoundError", "msg": "x"}))
    assert power.ensure_on("359a49a1c3-4cda10df", max_minutes=1) == 2
    out = capsys.readouterr().out
    assert "POWER_ON_STOP" in out and "TOK" not in out

    seen = []
    monkeypatch.setattr(power, "web_authorization", lambda: "JWT")
    monkeypatch.setattr(power, "post", lambda url, h, b, timeout=30: (seen.append(url) or (200, {"code": "Success"})))
    assert power.ensure_on("359a49a1c3-4cda10df", max_minutes=1) == 0
    assert seen == [power.WEB_POWER_ON]


def test_dev_token_path_retries_no_gpu(monkeypatch):
    monkeypatch.setattr(power, "web_authorization", lambda: None)
    monkeypatch.setattr(power, "dev_token", lambda: "TOK")
    replies = iter([(200, {"code": "X", "msg": "空闲GPU不足"}), (200, {"code": "Success"})])
    monkeypatch.setattr(power, "post", lambda url, h, b, timeout=30: next(replies))
    waits = []
    assert power.ensure_on("359a49a1c3-4cda10df", max_minutes=30, sleep=waits.append, now=lambda: 0.0) == 0
    assert waits == [20]


def test_wait_ssh_stops_with_clear_message_on_repeated_publickey_denial():
    states = iter(["down", "denied", "denied", "denied"])
    try:
        bring.wait_ssh(10, sleep=lambda s: None, state=lambda: next(states))
    except SystemExit as exc:
        assert "NEED_SSH_KEY_AUTH" in str(exc) and "authorized_keys" in str(exc)
    else:
        raise AssertionError("no stop")


def _bringup_with_failure(monkeypatch, argv):
    log = []
    monkeypatch.setattr(sys, "argv", ["bringup_and_run.py", "--no-power-on", *argv])
    monkeypatch.setattr(bring, "wait_ssh", lambda minutes: None)
    monkeypatch.setattr(bring, "ship", lambda light=False: None)
    monkeypatch.setattr(bring, "ssh", lambda cmd, **k: None)
    monkeypatch.setattr(bring, "restart_comfy", lambda: (_ for _ in ()).throw(SystemExit("comfy never came up")))
    monkeypatch.setattr(bring, "shutdown_machine", lambda: log.append("shutdown"))
    monkeypatch.setattr(power, "balance", lambda: log.append("balance") or 0)
    try:
        bring.main()
    except SystemExit as exc:
        assert exc.code == 1
    return log


def test_failed_step_keeps_the_machine_on_unless_asked(monkeypatch, capsys):
    assert _bringup_with_failure(monkeypatch, []) == ["balance"]
    assert "MACHINE_STILL_ON" in capsys.readouterr().out
    assert _bringup_with_failure(monkeypatch, ["--shutdown-on-failure"]) == ["shutdown", "balance"]


def test_restart_command_cannot_match_itself():
    source = (COMFY / "bringup_and_run.py").read_text(encoding="utf-8")
    assert "pgrep -f '[m]ain.py" in source


def test_bringup_ships_no_secrets_or_forbidden_machines():
    source = (COMFY / "bringup_and_run.py").read_text(encoding="utf-8")
    assert "xaxna66hqt" not in source and "sa4eaxgcuq" not in source
    assert "clone" not in source.lower().replace("never clones", "")
    for secret_name in ("autodl-token", "autodl-web-auth", "cast-ssh"):
        assert secret_name not in " ".join(bring.SHIP)
    assert all((ROOT / m).exists() for m in bring.SHIP)


keyinst = _load("install_ssh_key")


def test_key_install_command_is_idempotent_and_quotes_safely():
    cmd = keyinst.append_command("ssh-ed25519 AAAA test'key")
    assert "grep -qxF" in cmd and "chmod 600 /root/.ssh/authorized_keys" in cmd
    assert "test'\\''key" in cmd


def test_key_install_needs_a_password_and_never_prints_it(monkeypatch, capsys):
    monkeypatch.delenv("BJB_SSH_PASSWORD", raising=False)
    monkeypatch.setattr(keyinst, "PASSWORD_FILES", ())
    assert keyinst.read_password() is None
    assert keyinst.main() == 4
    assert "NEED_SSH_PASSWORD" in capsys.readouterr().out
    monkeypatch.setenv("BJB_SSH_PASSWORD", "hunter2")
    assert keyinst.read_password() == "hunter2"
    assert "hunter2" not in (COMFY / "install_ssh_key.py").read_text(encoding="utf-8")
