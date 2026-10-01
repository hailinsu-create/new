import json

from PIL import Image

from comic_pipeline import qa
from comic_pipeline.config import Settings


def _img(tmp_path):
    p = tmp_path / "x.png"
    Image.effect_noise((200, 300), 40).convert("RGB").save(p)
    return p


def _run(monkeypatch, tmp_path, replies, nonhuman=""):
    it = iter(replies)
    monkeypatch.setattr(qa, "_enabled", lambda s: True)
    monkeypatch.setattr(qa, "_judge", lambda s, imgs, prompt, model=None, reasoning=False: json.dumps(next(it)))
    return qa.audit_anatomy(Settings(), _img(tmp_path), 2, None, tag="t", nonhuman=nonhuman)


FULL_OK = {"people": 2, "arms": 4, "hands": 4, "legs": 4, "feet": 4, "orphan_limbs": 0, "defects": []}
HANDS_OK = {"hands": [{"fingers": 5, "malformed": False}], "defects": []}


def test_clean_image_passes(monkeypatch, tmp_path):
    a = _run(monkeypatch, tmp_path, [FULL_OK, HANDS_OK, HANDS_OK])
    assert a.ok and not a.issues


def test_extra_hand_blocks(monkeypatch, tmp_path):
    a = _run(monkeypatch, tmp_path, [{**FULL_OK, "hands": 5}, HANDS_OK, HANDS_OK])
    assert not a.ok and any("5 visible hands" in i for i in a.issues)


def test_six_fingers_blocks_but_four_is_warning(monkeypatch, tmp_path):
    six = {"hands": [{"fingers": 6, "malformed": False}], "defects": []}
    four = {"hands": [{"fingers": 4, "malformed": False, "note": "short"}], "defects": []}
    a = _run(monkeypatch, tmp_path, [FULL_OK, six, four])
    assert not a.ok and any("6 fingers" in i for i in a.issues)
    assert any("4 fingers" in w for w in a.warnings)


def test_wrong_people_count_and_cropped_feet(monkeypatch, tmp_path):
    full = {**FULL_OK, "people": 3, "defects": ["missing feet"]}
    a = _run(monkeypatch, tmp_path, [full, HANDS_OK, HANDS_OK])
    assert any("3 people" in i for i in a.issues)
    assert not any("feet" in i for i in a.issues + a.warnings)


def test_strict_check_flags_extra_arm(monkeypatch, tmp_path):
    monkeypatch.setattr(qa, "_enabled", lambda s: True)
    reply = {"arms": [{}, {}, {}, {}, {}], "unattached_or_extra_limbs": 1, "malformed_hands": 0, "verdict": "x"}
    monkeypatch.setattr(qa, "_judge", lambda s, i, p, model=None, reasoning=False: json.dumps(reply))
    a = qa.strict_limb_check(Settings(comic_strict_audit=True), _img(tmp_path), 2, None)
    assert not a.ok and len(a.issues) == 2


def test_strict_check_passes_four_arms(monkeypatch, tmp_path):
    monkeypatch.setattr(qa, "_enabled", lambda s: True)
    reply = {"arms": [{}, {}, {}, {}], "unattached_or_extra_limbs": 0, "malformed_hands": 0}
    monkeypatch.setattr(qa, "_judge", lambda s, i, p, model=None, reasoning=False: json.dumps(reply))
    assert qa.strict_limb_check(Settings(comic_strict_audit=True), _img(tmp_path), 2, None).ok


def test_strict_check_empty_reply_is_skipped_not_crash(monkeypatch, tmp_path):
    monkeypatch.setattr(qa, "_enabled", lambda s: True)
    monkeypatch.setattr(qa, "_judge", lambda s, i, p, model=None, reasoning=False: "")
    a = qa.strict_limb_check(Settings(comic_strict_audit=True), _img(tmp_path), 2, None)
    assert a.ok and a.skipped


def test_crop_helpers(tmp_path):
    from comic_pipeline.models import Still
    from comic_pipeline.still import apply_crop, crop_refs

    img = tmp_path / "a.png"
    Image.new("RGB", (100, 200), "red").save(img)
    still = Still(id="s", ref_crop=0.5, crop_bottom=0.25)
    ref = crop_refs([img], still, tmp_path)[0]
    assert Image.open(ref).size == (100, 100)
    apply_crop(img, still)
    assert Image.open(img).size == (100, 150)
