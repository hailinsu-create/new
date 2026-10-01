from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass, field
from pathlib import Path

from PIL import Image, ImageStat

from comic_pipeline.budget import BudgetLedger
from comic_pipeline.config import Settings
from comic_pipeline.models import Character, Panel, Project


@dataclass
class QAResult:
    ok: bool
    issues: list[str] = field(default_factory=list)
    skipped: bool = False
    raw: str = ""

    def hint(self) -> str:
        return "; ".join(i for i in self.issues if not i.startswith("failed check:"))

    def as_dict(self) -> dict:
        return {"ok": self.ok, "issues": self.issues, "skipped": self.skipped}


def blank_image_issue(path: Path) -> str | None:
    """fal replaces NSFW-flagged outputs with a black image; catch that for free."""
    with Image.open(path) as im:
        gray = im.convert("L")
        stat = ImageStat.Stat(gray)
        if stat.mean[0] < 6 or stat.stddev[0] < 3:
            return "output is blank/black (likely safety-filtered)"
    return None


def _parse_json(text: str) -> dict:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise ValueError(f"no JSON in judge reply: {text[:200]}")
    return json.loads(match.group(0))


def _judge(settings: Settings, images: list[Path], prompt: str) -> str:
    import fal_client

    os.environ["FAL_KEY"] = settings.fal_key.strip()
    urls = [fal_client.upload_file(str(p)) for p in images]
    result = fal_client.subscribe(
        settings.fal_vlm_endpoint,
        arguments={
            "model": settings.fal_vlm_model,
            "prompt": prompt,
            "image_urls": urls,
            "temperature": 0,
        },
    )
    if result.get("error"):
        raise RuntimeError(str(result["error"]))
    return str(result.get("output", ""))


def _enabled(settings: Settings) -> bool:
    return (
        settings.comic_qa
        and not settings.comic_mock
        and settings.resolved_provider() == "fal"
        and bool(settings.fal_key.strip())
    )


def _result_from(data: dict, required: list[str], raw: str) -> QAResult:
    issues = [str(i) for i in data.get("issues", []) if i]
    for key in required:
        if data.get(key) is False:
            issues.append(f"failed check: {key}")
    return QAResult(ok=not issues, issues=issues, raw=raw)


def qa_reference(
    settings: Settings,
    character: Character,
    image: Path,
    ledger: BudgetLedger | None = None,
) -> QAResult:
    blank = blank_image_issue(image)
    if blank:
        return QAResult(ok=False, issues=[blank])
    if not _enabled(settings):
        return QAResult(ok=True, skipped=True)
    if ledger is not None:
        ledger.ensure_can_afford(settings.fal_vlm_endpoint)
    prompt = (
        "You are a strict QA reviewer for a character look sheet used as an identity reference. "
        f"Character card: name={character.name}; look={character.age_look}; face={character.face}; "
        f"hair={character.hair}; wardrobe={character.wardrobe}; props={character.signature_props}. "
        "Reply with ONLY a JSON object with boolean fields: single_subject (exactly one person/creature), "
        "clean_background (plain or softly blurred neutral backdrop, no busy scenery, no studio split), "
        "face_matches_card, wardrobe_matches_card (major garments, colors and silhouette match; ignore tiny accessory "
        "differences, but flag extra capes/armor/large items not in the card), "
        "species_matches_card, adult_appearance (clearly an adult), no_artifacts (no extra limbs/fingers, "
        "no text or watermark), full_outfit_visible; plus 'issues' (short strings, ONLY for failed boolean checks) "
        "and 'pass' (boolean)."
    )
    raw = _judge(settings, [image], prompt)
    if ledger is not None:
        ledger.charge(model=settings.fal_vlm_endpoint, panel_id=f"{character.id}_ref_qa")
    res = _result_from(
        _parse_json(raw),
        [
            "single_subject",
            "clean_background",
            "face_matches_card",
            "wardrobe_matches_card",
            "species_matches_card",
            "adult_appearance",
            "no_artifacts",
        ],
        raw,
    )
    return res


def qa_panel(
    settings: Settings,
    project: Project,
    panel: Panel,
    image: Path,
    refs: list[Path],
    ledger: BudgetLedger | None = None,
) -> QAResult:
    blank = blank_image_issue(image)
    if blank:
        return QAResult(ok=False, issues=[blank])
    if not _enabled(settings):
        return QAResult(ok=True, skipped=True)
    if ledger is not None:
        ledger.ensure_can_afford(settings.fal_vlm_endpoint)
    cmap = project.character_map()
    names = [cmap[c].name for c in panel.characters if c in cmap]
    prompt = (
        "You are a strict QA reviewer for one comic panel. Image 1 is the generated panel; "
        f"the remaining {len(refs)} image(s) are identity references for: {', '.join(names) or 'none'}, in order. "
        f"Intended shot: {panel.shot}; action: {panel.action}. "
        "Reply with ONLY a JSON object with boolean fields: character_count_correct, "
        "characters_distinct (different people/species, not twins or merged faces), "
        "faces_match_references, wardrobe_matches_references, single_frame (not a collage/split screen), "
        "anatomy_ok (hands, limbs, faces), adults_only (all figures clearly adult); "
        "plus 'issues' (short strings, ONLY for failed boolean checks; do NOT list differences in pose, framing, "
        "camera distance or minor action details), 'notes' (optional list for non-blocking pose/action differences) "
        "and 'pass' (boolean)."
    )
    raw = _judge(settings, [image, *refs], prompt)
    if ledger is not None:
        ledger.charge(model=settings.fal_vlm_endpoint, panel_id=f"{panel.id}_qa")
    required = ["character_count_correct", "single_frame", "anatomy_ok", "adults_only"]
    if len(names) > 1:
        required.append("characters_distinct")
    if names:
        required += ["faces_match_references", "wardrobe_matches_references"]
    return _result_from(_parse_json(raw), required, raw)


@dataclass
class StillJudgement:
    scores: dict[str, float]
    total: float
    blocking: list[str]
    fixes: list[str]
    raw: str = ""

    @property
    def ok(self) -> bool:
        return not self.blocking


STILL_KEYS = ("identity", "distinction", "interaction", "aesthetics", "anatomy", "wardrobe", "motif")


def judge_still(
    settings: Settings,
    project: Project,
    still,
    image: Path,
    refs: list[Path],
    ledger: BudgetLedger | None = None,
) -> StillJudgement:
    blank = blank_image_issue(image)
    if blank:
        return StillJudgement({}, 0.0, [blank], [])
    if not _enabled(settings):
        return StillJudgement({k: 10.0 for k in STILL_KEYS}, 10.0, [], [])
    if ledger is not None:
        ledger.ensure_can_afford(settings.fal_vlm_endpoint)
    cmap = project.character_map()
    names = [cmap[c].name for c in still.characters if c in cmap]
    prompt = (
        "You are a demanding art director scoring ONE finished hero image of two fictional adult characters. "
        f"Image 1 is the candidate. Images 2 and 3 are identity references for {' and '.join(names)} in order. "
        f"Intended motif: {still.motif}. Blocking: {still.blocking}. Wardrobe: {still.wardrobe_state}. "
        "Reply with ONLY JSON: {\"scores\": {identity, distinction, interaction, aesthetics, anatomy, wardrobe, motif} "
        "each 0-10 (identity = faces/species match the references; distinction = the two look clearly different; "
        "interaction = believable eye contact and touch, no stiff posing; aesthetics = lighting, composition, "
        "skin/fur/fabric realism; anatomy = hands, limbs, proportions; wardrobe = outfits match references; "
        "motif = the intended dynamic is clearly expressed), "
        "\"blocking\": [short strings for deal-breakers: collage/split frame, merged or duplicated faces, "
        "wrong character count, broken hands or limbs, minor-looking figure, text/watermark], "
        "\"fixes\": [up to 4 short, concrete edit instructions to improve the image]}."
    )
    raw = _judge(settings, [image, *refs], prompt)
    if ledger is not None:
        ledger.charge(model=settings.fal_vlm_endpoint, panel_id=f"{still.id}_judge")
    data = _parse_json(raw)
    scores = {k: float(v) for k, v in (data.get("scores") or {}).items() if k in STILL_KEYS}
    total = sum(scores.values()) / max(1, len(scores)) if scores else 0.0
    return StillJudgement(
        scores=scores,
        total=round(total, 2),
        blocking=[str(b) for b in data.get("blocking", []) if b],
        fixes=[str(f) for f in data.get("fixes", []) if f],
        raw=raw,
    )
