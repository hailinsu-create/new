"""v3 mood boards for Lin and Elena must be in the repo, not only on disk."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOOD = ROOT / "library" / "cast" / "mood"


def test_v3_mood_boards_are_tracked_for_lin_and_elena():
    asia = MOOD / "2026-10-06-asia-aesthetic-board-v3.jpg"
    europe = MOOD / "2026-10-06-eu-aesthetic-board-v3.jpg"
    assert asia.is_file() and asia.stat().st_size > 50_000
    assert europe.is_file() and europe.stat().st_size > 50_000
    look = (MOOD / "LOOK.md").read_text(encoding="utf-8")
    cast = (ROOT / "library" / "cast" / "CAST.md").read_text(encoding="utf-8")
    lin = (ROOT / "library" / "cast" / "lin_wantang" / "actor.md").read_text(encoding="utf-8")
    elena = (ROOT / "library" / "cast" / "elena_voss" / "actor.md").read_text(encoding="utf-8")
    for text in (look, cast, lin):
        assert "2026-10-06-asia-aesthetic-board-v3.jpg" in text
    for text in (look, cast, elena):
        assert "2026-10-06-eu-aesthetic-board-v3.jpg" in text
    assert "板心不是这张锁脸" in lin
    assert "板心不是这张锁脸" in elena
    assert (MOOD / "tags" / "asia-lin.md").is_file()
    assert (MOOD / "tags" / "eu-elena.md").is_file()
