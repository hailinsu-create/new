"""Crop-and-stitch inpaint and cubiq Multi-ID still graph."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
COMFY = ROOT / "workflows" / "comfyui"


def _load(name: str):
    path = COMFY / f"{name}.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
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


def test_scheme_b_chest_cleanup_is_crop_and_stitch():
    script = (COMFY / "scheme_b_from_plate.py").read_text(encoding="utf-8")
    setup = (ROOT / "docs" / "comfyui-setup.md").read_text(encoding="utf-8")
    assert "SetLatentNoiseMask" not in script
    assert "inpaint_crop_graph" in script
    assert "ref-face.png" in script
    assert "0.75" in setup
    assert "InpaintModelConditioning" in setup


def test_still_multi_id_is_one_sampler_two_instantid():
    still = _load("scheme_still_multi_id")
    models = {
        "ckpt": "RealVisXL_V5.0_fp16.safetensors",
        "instant_cn": "instantid/x.safetensors",
        "instant_ip": "ip-adapter.bin",
        "face_det": "bbox/face_yolov8m.pt",
    }
    graph = still.build_multi_id_graph(
        models,
        "p01-pose.png",
        "p01-lin-face.png",
        "p01-gu-face.png",
        "p01-lin-mask.png",
        "p01-gu-mask.png",
        "p01-lin-kps.png",
        "p01-gu-kps.png",
        "p01-face-union.png",
    )
    dumped = json.dumps(graph)
    apply = [node for node in graph.values() if node.get("class_type") == "ApplyInstantID"]
    samplers = [node for node in graph.values() if node.get("class_type") == "KSampler"]
    assert len(apply) == 2
    assert len(samplers) == 1
    for node in apply:
        assert "mask" in node["inputs"]
        assert "image_kps" in node["inputs"]
    assert graph["11"]["inputs"]["model"] == ["10", 0]
    assert "ConditioningCombine" in dumped
    assert "InpaintModelConditioning" in dumped
    assert "SetLatentNoiseMask" not in dumped
    assert samplers[0]["inputs"]["denoise"] == still.FACE_DENOISE
    assert 0.6 <= still.FACE_DENOISE <= 0.85
    example = (COMFY / "scheme-still-p01.api.json").read_text(encoding="utf-8")
    assert "ApplyInstantID" in example
    assert "ConditioningCombine" in example
    cloth = (COMFY / "scheme-still-p01-cloth.api.json").read_text(encoding="utf-8")
    assert "InpaintModelConditioning" in cloth
    assert "0.75" in cloth


def test_p01_boxes_keep_her_left_bandeau_below_face():
    still = _load("scheme_still_multi_id")
    her = still.P01_HER_FACE
    his = still.P01_HIS_FACE
    band = still.P01_BANDEAU
    assert (her[0] + her[2]) / 2 < (his[0] + his[2]) / 2
    assert band[1] >= her[3] - 0.02
    pose = Image.open(ROOT / "library/cast/body-boards/p01.png")
    boxes = still.prepare_p01_inputs(pose, Path("/tmp/p01-prep-test"))
    assert boxes["her"][2] > boxes["her"][0]
    assert boxes["his"][0] > boxes["her"][0]
    lin_mask = Image.open("/tmp/p01-prep-test/p01-lin-mask.png")
    gu_mask = Image.open("/tmp/p01-prep-test/p01-gu-mask.png")
    overlap = 0
    lin_l = lin_mask.convert("L")
    gu_l = gu_mask.convert("L")
    for y in range(0, lin_l.height, 4):
        for x in range(0, lin_l.width, 4):
            if lin_l.getpixel((x, y)) > 40 and gu_l.getpixel((x, y)) > 40:
                overlap += 1
    assert overlap == 0


def test_gu_lock_face_is_a_crop_of_the_standing_sheet():
    face = ROOT / "library/cast/gu_chengan/ref-face.png"
    sheet = ROOT / "library/cast/gu_chengan/ref.png"
    actor = (ROOT / "library/cast/gu_chengan/actor.md").read_text(encoding="utf-8")
    assert face.is_file()
    image = Image.open(face)
    assert image.width >= 200 and image.height >= 200
    assert image.width < Image.open(sheet).width
    assert "ref-face.png" in actor
    assert "InstantID" in actor
