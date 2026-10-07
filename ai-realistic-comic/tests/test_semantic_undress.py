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
        dino_garment={},
        dino_protect={},
        dino_horse={"horse body": horse},
    )
    assert not plain[760, 420]
    assert plain[650, 420]


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
