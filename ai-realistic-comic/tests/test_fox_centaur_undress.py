"""Fox/centaur still undress: clothes-only crop, not a full Scheme B redraw."""

from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
COMFY = ROOT / "workflows" / "comfyui"
STILL = ROOT / "library" / "stills" / "fox-centaur-embrace"


def _load(name: str):
    path = COMFY / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    # dataclasses need the module registered before @dataclass runs
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def test_inpaint_crop_uses_conditioning_not_full_frame_denoise_one():
    crop = _load("inpaint_crop")
    assert crop.INPAINT_DENOISE == 0.75
    graph = crop.inpaint_crop_graph(
        "RealVisXL_V5.0_fp16.safetensors",
        "crop.png",
        "mask.png",
        "bare skin",
        "cloth",
        1,
        "chest",
    )
    dumped = json.dumps(graph)
    assert "InpaintModelConditioning" in dumped
    assert "SetLatentNoiseMask" not in dumped
    assert graph["15"]["inputs"]["denoise"] == 0.75
    assert graph["40"]["inputs"]["noise_mask"] is True


def test_crop_and_stitch_leaves_unmasked_pixels():
    crop = _load("inpaint_crop")
    original = Image.new("RGB", (200, 200), (10, 20, 30))
    ImageDraw.Draw(original).rectangle((20, 20, 80, 80), fill=(200, 40, 40))
    mask = Image.new("L", (200, 200), 0)
    ImageDraw.Draw(mask).rectangle((40, 40, 70, 70), fill=255)
    job = crop.prepare_crop(original, mask, context=8, target=64)
    fake = Image.new("RGB", (64, 64), (0, 255, 0))
    out = crop.stitch(original, fake, job)
    assert out.getpixel((10, 10)) == (10, 20, 30)
    assert out.getpixel((25, 25)) == (200, 40, 40)


def test_fox_centaur_undress_keeps_tails_horse_and_faces():
    undress = _load("scheme_still_fox_centaur_undress")
    lin = Image.open(STILL / "lin-qipao-nine-tail.png")
    elena = Image.open(STILL / "elena-armor-centaur.png")
    lin_mask = undress.lin_clothes_mask(lin)
    elena_mask = undress.elena_clothes_mask(elena)
    assert lin_mask.getpixel((430, 200)) < 20
    assert lin_mask.getpixel((750, 450)) < 20
    assert lin_mask.getpixel((500, 1450)) < 20
    assert lin_mask.getpixel((430, 450)) > 200
    assert lin_mask.getpixel((400, 900)) > 200
    assert elena_mask.getpixel((430, 160)) < 20
    assert elena_mask.getpixel((700, 800)) < 20
    assert elena_mask.getpixel((400, 750)) < 20
    assert elena_mask.getpixel((430, 400)) > 200
    assert elena_mask.getpixel((250, 500)) > 200


def test_community_region_schedule_is_small_holes_then_edge():
    undress = _load("scheme_still_fox_centaur_undress")
    assert undress.CLOTH_DENOISE == 0.80
    assert undress.EDGE_DENOISE == 0.42
    assert undress.MAX_CONTENT_FRAC == 0.58
    lin = undress.lin_region_passes()
    elena = undress.elena_region_passes()
    assert [r.stem for r in lin] == ["lin-chest", "lin-midriff", "lin-skirt", "lin-edge"]
    assert [r.stem for r in elena] == [
        "elena-breastplate",
        "elena-collar",
        "elena-arm",
        "elena-hip",
        "elena-edge",
    ]
    assert all(r.denoise == undress.CLOTH_DENOISE for r in lin[:-1])
    assert lin[-1].denoise == undress.EDGE_DENOISE
    assert lin[-1].grow > 0
    assert all(r.denoise == undress.CLOTH_DENOISE for r in elena[:-1])
    assert elena[-1].denoise == undress.EDGE_DENOISE
    assert elena[-1].grow > 0


def test_prepare_crop_community_downscales_large_holes():
    undress = _load("scheme_still_fox_centaur_undress")
    image = Image.new("RGB", (1024, 1536), (20, 20, 24))
    mask = Image.new("L", (1024, 1536), 0)
    ImageDraw.Draw(mask).rectangle((200, 200, 800, 1300), fill=255)
    job = undress.prepare_crop_community(image, mask, target=1024, max_content_frac=0.58)
    content_w = job.inner[2] - job.inner[0]
    content_h = job.inner[3] - job.inner[1]
    assert max(content_w, content_h) / 1024 <= 0.58 + 1e-6


def test_head_shoulder_from_plate_is_square():
    undress = _load("scheme_still_fox_centaur_undress")
    plate = Image.open(STILL / "lin-qipao-nine-tail.png")
    head = undress.head_shoulder_from_plate(plate, undress.LIN_HEAD, 768)
    assert head.size == (768, 768)


def test_pad_face_for_instantid_is_square_and_larger_than_lock():
    undress = _load("scheme_still_fox_centaur_undress")
    face = Image.open(ROOT / "library/cast/lin_wantang/ref-face.png")
    padded = undress.pad_face_for_instantid(face, 768)
    assert padded.size == (768, 768)
    assert padded.size[0] > face.size[0]


def test_fox_centaur_graph_is_crop_inpaint_plus_instantid_on_head_shoulder():
    undress = _load("scheme_still_fox_centaur_undress")
    models = {
        "ckpt": "RealVisXL_V5.0_fp16.safetensors",
        "instant_cn": "instantid/x.safetensors",
        "instant_ip": "ip-adapter.bin",
    }
    graph = undress.instantid_inpaint_graph(
        models,
        "lin-chest-crop.png",
        "lin-chest-crop-mask.png",
        "lin-head-shoulder.png",
        undress.LIN_POS,
        undress.LIN_NEG,
        undress.SAMPLER_SEED,
        "lin-chest",
        undress.CLOTH_DENOISE,
    )
    dumped = json.dumps(graph)
    assert graph["2"]["inputs"]["image"] == "lin-chest-crop-mask.png"
    assert graph["60"]["inputs"]["image"] == "lin-head-shoulder.png"
    assert graph["10"]["class_type"] == "ApplyInstantID"
    assert graph["10"]["inputs"]["image"] == ["60", 0]
    assert graph["40"]["class_type"] == "InpaintModelConditioning"
    assert graph["40"]["inputs"]["positive"] == ["10", 1]
    assert graph["15"]["inputs"]["denoise"] == undress.CLOTH_DENOISE
    assert graph["15"]["inputs"]["model"] == ["10", 0]
    assert "SetLatentNoiseMask" not in dumped
    assert "ReActor" not in dumped
    assert "blue-grey" in undress.ELENA_NEG
    assert "extra person" in undress.LIN_NEG
    assert "bare skin" in undress.LIN_POS
    assert "armor" in undress.ELENA_NEG
    assert "狐尾" in (STILL / "STILL.md").read_text(encoding="utf-8")
    assert undress.F34_UUID not in dumped
    script = (COMFY / "scheme_still_fox_centaur_undress.py").read_text(encoding="utf-8")
    assert "from scheme_b_from_plate" not in script
    assert "scheme_b_from_plate.py" in script
    assert undress.BJ_UUID in script
    assert undress.F34_UUID in script
    assert "head_shoulder_from_plate" in script
    assert "prepare_crop_community" in script
    try:
        undress.assert_not_forbidden_uuid(undress.F34_UUID)
        raise AssertionError("F34 must be forbidden")
    except SystemExit as exc:
        assert "FORBIDDEN_INSTANCE" in str(exc)


def test_fox_centaur_docs_say_crop_not_full_redraw():
    still = (STILL / "STILL.md").read_text(encoding="utf-8")
    setup = (ROOT / "docs" / "comfyui-setup.md").read_text(encoding="utf-8")
    compare = (STILL / "COMPARE.md").read_text(encoding="utf-8")
    assert "不用 ReActor" in still
    assert "crop-and-stitch" in still
    assert "scheme_still_fox_centaur_undress.py" in still
    assert "头肩" in still or "head-shoulder" in still
    assert "0.75" in still or "0.80" in still
    assert "scheme_still_fox_centaur_undress.py" in setup
    assert "359a49a1c3-4cda10df" in setup
    assert "InpaintModelConditioning" in setup
    assert "小洞" in compare or "head-shoulder" in compare
    assert "0.75–0.85" in compare or "0.80" in compare
