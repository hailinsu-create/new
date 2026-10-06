"""v3 mood boards are the Lin/Elena identity source; lock faces are board-center crops."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAST = ROOT / "library" / "cast"
MOOD = CAST / "mood"


def test_v3_mood_boards_are_tracked_for_lin_and_elena():
    asia = MOOD / "2026-10-06-asia-aesthetic-board-v3.jpg"
    europe = MOOD / "2026-10-06-eu-aesthetic-board-v3.jpg"
    assert asia.is_file() and asia.stat().st_size > 50_000
    assert europe.is_file() and europe.stat().st_size > 50_000
    look = (MOOD / "LOOK.md").read_text(encoding="utf-8")
    cast = (CAST / "CAST.md").read_text(encoding="utf-8")
    lin = (CAST / "lin_wantang" / "actor.md").read_text(encoding="utf-8")
    elena = (CAST / "elena_voss" / "actor.md").read_text(encoding="utf-8")
    for text in (look, cast, lin):
        assert "2026-10-06-asia-aesthetic-board-v3.jpg" in text
    for text in (look, cast, elena):
        assert "2026-10-06-eu-aesthetic-board-v3.jpg" in text
    assert "板心就是这张锁脸的来源" in lin
    assert "板心就是这张锁脸的来源" in elena
    assert "蓝灰眼不算她" in elena
    assert "褐眼" in elena
    face_section = elena.split("## Face")[1].split("## 眼镜")[0]
    assert "**Eyes:** brown" in face_section
    assert "not blue-grey" in face_section
    assert "clear blue-grey" not in face_section
    assert (MOOD / "tags" / "asia-lin.md").is_file()
    assert (MOOD / "tags" / "eu-elena.md").is_file()


def test_board_center_lock_faces_exist_and_notes_are_archived():
    lin_face = CAST / "lin_wantang" / "ref-face.png"
    elena_face = CAST / "elena_voss" / "ref-face.png"
    assert lin_face.is_file() and lin_face.stat().st_size > 20_000
    assert elena_face.is_file() and elena_face.stat().st_size > 20_000
    # Note frontals are not the live lock.
    assert not (CAST / "lin_wantang" / "ref.png").exists()
    assert not (CAST / "elena_voss" / "ref.png").exists()
    assert (CAST / "lin_wantang" / "archive" / "ref-face-retired-2026-10-06-note.png").is_file()
    assert (CAST / "elena_voss" / "archive" / "ref-retired-2026-10-06-note.png").is_file()
    score = (ROOT / "docs" / "still-score.md").read_text(encoding="utf-8")
    assert "蓝灰眼" in score
    assert "眼镜待定" in score
    assert "褐眼" in score
    elena_actor = (CAST / "elena_voss" / "actor.md").read_text(encoding="utf-8")
    assert "默认先保留板心原样" in elena_actor
    assert "备选（未启用）" in elena_actor
