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
    raw = match.group(0)
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        repaired = re.sub(r",\s*([}\]])", r"\1", raw)
        try:
            return json.loads(repaired)
        except json.JSONDecodeError as exc:
            raise ValueError(f"unparseable JSON in judge reply: {exc}") from exc


def _judge(settings: Settings, images: list[Path], prompt: str, model: str | None = None, reasoning: bool = False) -> str:
    import fal_client

    os.environ["FAL_KEY"] = settings.fal_key.strip()
    urls = [fal_client.upload_file(str(p)) for p in images]
    result = fal_client.subscribe(
        settings.fal_vlm_endpoint,
        arguments={
            "model": model or settings.fal_vlm_model,
            "prompt": prompt,
            "image_urls": urls,
            "temperature": 0,
            "reasoning": reasoning,
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
    render_style: str = "photoreal",
    full_body: bool = False,
) -> QAResult:
    blank = blank_image_issue(image)
    if blank:
        return QAResult(ok=False, issues=[blank])
    if not _enabled(settings):
        return QAResult(ok=True, skipped=True)
    if ledger is not None:
        ledger.ensure_can_afford(settings.fal_vlm_endpoint)
    style_rule = (
        "painterly stylized illustration"
        if render_style == "stylized"
        else "photographic live-action look, NOT a 3D render, animation, game CG or illustration"
    )
    prompt = (
        "You are a strict QA reviewer for a character look sheet used as an identity reference. "
        f"Character card: name={character.name}; look={character.age_look}; face={character.face}; "
        f"hair={character.hair}; wardrobe={character.wardrobe}; props={character.signature_props}. "
        "Reply with ONLY a JSON object with boolean fields: single_subject (exactly one person/creature), "
        "clean_background (plain or softly blurred neutral backdrop, no busy scenery, no studio split), "
        "face_matches_card, wardrobe_matches_card (major garments, colors and silhouette match; ignore tiny accessory "
        "differences, but flag extra capes/armor/large items not in the card), "
        "species_matches_card, adult_appearance (clearly an adult), no_artifacts (no extra limbs/fingers, "
        "no text or watermark), full_outfit_visible (the entire body from head to feet and the footwear are inside the frame, nothing cropped), "
        f"style_matches ({style_rule}); plus 'issues' (short strings, ONLY for failed boolean checks) "
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
            "style_matches",
            *(["full_outfit_visible"] if full_body else []),
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
    anatomy_warnings: list[str] = field(default_factory=list)
    anatomy_counts: dict = field(default_factory=dict)

    @property
    def ok(self) -> bool:
        return not self.blocking


@dataclass
class AnatomyAudit:
    ok: bool
    issues: list[str] = field(default_factory=list)
    counts: dict = field(default_factory=dict)
    skipped: bool = False
    warnings: list[str] = field(default_factory=list)


def _soft(defect: str) -> bool:
    """Occlusion/cropping often makes a finger or foot look 'missing'; keep those as repair hints, not blockers."""
    d = defect.lower()
    if "extra" in d or "fused" in d or "duplicate" in d or "merged" in d or "impossible" in d:
        return False
    return "missing" in d or "short" in d or "cropped" in d or "occlu" in d or "hidden" in d


def _int(v) -> int | None:
    try:
        return int(v)
    except (TypeError, ValueError):
        return None


def audit_anatomy(
    settings: Settings,
    image: Path,
    expected_people: int,
    ledger: BudgetLedger | None = None,
    tag: str = "audit",
    nonhuman: str = "",
) -> AnatomyAudit:
    """Counting-based anatomy gate: people, arms, hands, legs on the full frame, then fingers per hand on
    overlapping crops. A holistic 0-10 score lets extra hands slip through; counts do not."""
    if not _enabled(settings):
        return AnatomyAudit(True, skipped=True)
    full_prompt = (
        "You are a forensic anatomy checker for a generated image. Do NOT judge beauty. COUNT what is literally visible, "
        "trace every limb back to a torso, and prefer reporting a defect over assuming it is fine. "
        'Reply with ONLY JSON: {"people": int, "arms": int, "hands": int, "legs": int, "feet": int, '
        '"orphan_limbs": int (arms, hands or legs that connect to no body or to the wrong body), '
        '"defects": [short strings: extra/fused/missing limbs, hand merged into fabric or hair, impossible joint bends, '
        'limbs passing through each other, duplicated body parts, wrong head count]}. '
        "Count only parts that are visible; do not count hidden ones."
        + (f" Intended non-human anatomy that is NOT a defect: {nonhuman}." if nonhuman else "")
    )
    h_prompt = (
        "Count the fingers on EVERY visible hand in this crop of a generated image, one by one, thumb included. "
        'Reply with ONLY JSON: {"hands": [{"fingers": int, "malformed": bool, "note": "short"}], '
        '"defects": [short strings for extra/missing/fused/bent-wrong fingers or extra hands]}. '
        "If no hand is visible reply {\"hands\": [], \"defects\": []}."
    )
    with Image.open(image) as im:
        im = im.convert("RGB")
        w, h = im.size
        tiles = []
        for name, box in (("top", (0, 0, w, int(h * 0.58))), ("bottom", (0, int(h * 0.42), w, h))):
            tp = image.with_name(f"_tile_{tag}_{name}.png")
            im.crop(box).save(tp)
            tiles.append(tp)
    issues: list[str] = []
    warnings: list[str] = []
    counts: dict = {}
    try:
        if ledger is not None:
            ledger.ensure_can_afford(settings.fal_vlm_endpoint)
        try:
            data = _parse_json(_judge(settings, [image], full_prompt))
        except ValueError:
            data = {}
        if ledger is not None:
            ledger.charge(model=settings.fal_vlm_endpoint, panel_id=f"{tag}_anatomy_full")
        counts = {k: _int(data.get(k)) for k in ("people", "arms", "hands", "legs", "feet", "orphan_limbs")}
        people = counts["people"]
        if people is not None and people != expected_people:
            issues.append(f"anatomy: {people} people visible, expected {expected_people}")
        for key, per in (("arms", 2), ("hands", 2), ("legs", 2), ("feet", 2)):
            val = counts.get(key)
            if val is not None and val > per * expected_people:
                issues.append(f"anatomy: {val} visible {key} for {expected_people} people (max {per * expected_people})")
        if counts.get("orphan_limbs"):
            issues.append(f"anatomy: {counts['orphan_limbs']} limb(s) not attached to the right body")
        for d in data.get("defects", []):
            d = str(d)
            if not d:
                continue
            low = d.lower()
            if any(w in low for w in ("leg", "feet", "foot")) and ("missing" in low or "cropped" in low):
                continue
            (warnings if _soft(d) else issues).append(f"anatomy: {d}")
        total_hands = 0
        for tp in tiles:
            if ledger is not None:
                ledger.ensure_can_afford(settings.fal_vlm_endpoint)
            try:
                hd = _parse_json(_judge(settings, [tp], h_prompt))
            except ValueError:
                hd = {}
            if ledger is not None:
                ledger.charge(model=settings.fal_vlm_endpoint, panel_id=f"{tag}_anatomy_{tp.stem[-6:]}")
            for hand in hd.get("hands", []):
                f = _int(hand.get("fingers"))
                total_hands += 1
                note = f"anatomy: a hand with {f} fingers ({hand.get('note', '')})".replace(" ()", "")
                if hand.get("malformed") or (f is not None and (f > 5 or f <= 3)):
                    issues.append(note)
                elif f == 4:
                    warnings.append(note)
            for d in hd.get("defects", []):
                if d:
                    (warnings if _soft(str(d)) else issues).append(f"anatomy: {d}")
        counts["hand_checks"] = total_hands
    finally:
        for tp in tiles:
            tp.unlink(missing_ok=True)
    def dedupe(items: list[str]) -> list[str]:
        out: list[str] = []
        for i in items:
            if i not in out:
                out.append(i)
        return out

    issues = dedupe(issues)
    return AnatomyAudit(not issues, issues, counts, warnings=[w for w in dedupe(warnings) if w not in issues])


def strict_limb_check(
    settings: Settings,
    image: Path,
    expected_people: int,
    ledger: BudgetLedger | None = None,
    tag: str = "strict",
    nonhuman: str = "",
) -> AnatomyAudit:
    """Second opinion by a stronger reasoning model that must enumerate each arm back to its shoulder.
    Run once on the shortlisted image only (it costs about 6x a flash call)."""
    if not _enabled(settings) or not settings.comic_strict_audit:
        return AnatomyAudit(True, skipped=True)
    prompt = (
        "Enumerate EVERY arm visible in this image, one list entry per arm, tracing each from its shoulder to its hand. "
        "Ignore what the scene is supposed to depict; report only what is actually drawn. Be suspicious: arms that "
        "emerge from the wrong place, hands with no arm, doubled hands and merged fingers are common generation errors. "
        'Reply ONLY JSON: {"arms": [{"belongs_to": "which person", "shoulder_visible": bool, "hand_position": "short", '
        '"fingers_visible": int}], "unattached_or_extra_limbs": int, "malformed_hands": int, "verdict": "short"}.'
        + (f" Intended non-human anatomy that is NOT a defect: {nonhuman}." if nonhuman else "")
    )
    if ledger is not None:
        ledger.ensure_can_afford(settings.fal_strict_model)
    data = None
    for attempt in (1, 2):
        try:
            data = _parse_json(_judge(settings, [image], prompt, model=settings.fal_strict_model, reasoning=True))
        except ValueError:
            data = None
        if ledger is not None:
            ledger.charge(model=settings.fal_strict_model, panel_id=f"{tag}_strict{attempt}")
        if data is not None:
            break
        if ledger is not None:
            try:
                ledger.ensure_can_afford(settings.fal_strict_model)
            except RuntimeError:
                break
    if data is None:
        return AnatomyAudit(True, skipped=True, counts={"strict_error": "reasoning model returned no JSON twice"})
    arms = data.get("arms") or []
    issues = []
    if len(arms) > 2 * expected_people:
        issues.append(f"anatomy: strict check enumerated {len(arms)} arms for {expected_people} people")
    if _int(data.get("unattached_or_extra_limbs")):
        issues.append(f"anatomy: strict check found {data['unattached_or_extra_limbs']} unattached/extra limb(s)")
    if _int(data.get("malformed_hands")):
        issues.append(f"anatomy: strict check found {data['malformed_hands']} malformed hand(s)")
    return AnatomyAudit(not issues, issues, {"strict_arms": len(arms), "verdict": data.get("verdict", "")})


STILL_KEYS = ("identity", "distinction", "interaction", "aesthetics", "anatomy", "wardrobe", "motif", "photoreal")


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
        "motif = the intended dynamic is clearly expressed; photoreal = looks like a live-action photograph, 0 if it looks "
        "like an illustration, painting, 3D render or game CG), "
        "\"blocking\": [short strings for deal-breakers: collage/split frame, merged or duplicated faces, "
        "wrong character count, broken hands or limbs, minor-looking figure, text/watermark, "
        "illustration/3D look instead of photographic, skin/hair/eye colors or held props contradicting the references], "
        "\"fixes\": [up to 4 short, concrete edit instructions to improve the image]}."
    )
    data, raw = {}, ""
    for attempt in (1, 2):
        raw = _judge(settings, [image, *refs], prompt)
        if ledger is not None:
            ledger.charge(model=settings.fal_vlm_endpoint, panel_id=f"{still.id}_judge{attempt}")
        try:
            data = _parse_json(raw)
            break
        except ValueError:
            if attempt == 2:
                return StillJudgement({}, 5.0, [], [], raw=raw)
    scores = {k: float(v) for k, v in (data.get("scores") or {}).items() if k in STILL_KEYS}
    total = sum(scores.values()) / max(1, len(scores)) if scores else 0.0
    return StillJudgement(
        scores=scores,
        total=round(total, 2),
        blocking=[str(b) for b in data.get("blocking", []) if b],
        fixes=[str(f) for f in data.get("fixes", []) if f],
        raw=raw,
    )
