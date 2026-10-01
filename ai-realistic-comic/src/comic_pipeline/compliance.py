from __future__ import annotations

import re
from dataclasses import dataclass, field

from comic_pipeline.config import Settings
from comic_pipeline.models import Episode, Project, Still

# Policy snapshot researched 2026-09-30. Platform rules change often: re-check each source before launch.
PLATFORMS: dict[str, dict] = {
    "fanvue": {
        "styles": {"photoreal", "stylized"},
        "tiers": {"sfw", "suggestive", "explicit"},
        "synthetic_persona": True,
        "label": "AI tag on profile and a disclosure (caption or watermark) on AI media",
        "source": "https://help.fanvue.com/en/articles/9538738-is-ai-content-allowed-on-fanvue",
        "notes": "Fully AI creators allowed after KYC; deepfakes/face-swaps need the real person verified.",
    },
    "patreon_sfw": {
        "styles": {"photoreal", "stylized"},
        "tiers": {"sfw"},
        "warn_tiers": {"suggestive"},
        "synthetic_persona": True,
        "label": "none mandated; follow Community Guidelines",
        "source": "https://support.patreon.com/hc/en-us/articles/34055590411789",
        "notes": "Safe-for-all pages: AI people allowed if no nudity or sexual material.",
    },
    "patreon_adult": {
        "styles": {"stylized"},
        "tiers": {"sfw", "suggestive", "explicit"},
        "synthetic_persona": True,
        "label": "none mandated; subjects must be unmistakably adult",
        "source": "https://support.patreon.com/hc/en-us/articles/34055590411789",
        "notes": "Adult/18+: hyperrealistic AI people only if real and consent-documented; "
        "illustrated/animated AI characters are allowed. No AI girlfriend/sexbot offering with image generation.",
    },
    "gumroad": {
        "styles": {"photoreal", "stylized"},
        "tiers": {"sfw"},
        "synthetic_persona": True,
        "label": "none mandated",
        "source": "https://gumroad.com/prohibited",
        "notes": "Sexually oriented content and adult comics with nudity/sex are prohibited; so is selling AI generation access.",
    },
    "fansly": {
        "styles": {"stylized"},
        "tiers": {"sfw", "suggestive", "explicit"},
        "synthetic_persona": True,
        "label": "must not be presented as authentic human content",
        "source": "https://help.fansly.com/en/articles/12315578-ai-generated-content-on-fansly",
        "notes": "Photorealistic AI content is not allowed even if labeled; non-photorealistic virtual entities need real-ID verification.",
    },
    "onlyfans": {
        "styles": {"photoreal", "stylized"},
        "tiers": {"sfw", "suggestive", "explicit"},
        "synthetic_persona": False,
        "label": "#ai or #AIGenerated in every post caption",
        "source": "https://archive.ph/6mux7",
        "notes": "Account must be a verified human; AI content is expected to resemble that creator (secondary sources).",
    },
}

MINOR_PATTERNS = re.compile(
    r"\b(minor|underage|child|children|kid|loli|lolita|shota|teen|teenager|schoolgirl|school ?uniform|"
    r"young[- ]?looking|childlike|baby[- ]?face|juvenile|preteen|tween)\b|未成年|幼女|萝莉|正太|少女|学生|中学生|小学生|幼齿",
    re.IGNORECASE,
)
ADULT_MARKER = re.compile(
    r"\badult\b|\b(2[1-9]|[3-9][0-9])\s*(?:years|yo|y/o)\b|\b(?:early|mid|late)[- ]?(?:2\d|3\d|4\d)s\b|\b[2-4]0s\b",
    re.IGNORECASE,
)


HARM_PATTERNS = re.compile(
    r"\b(rape|raped|non-?consensual|forced|coerced|drugged|unconscious|passed out|sleeping victim|"
    r"incest|bestiality|gore|mutilat\w*|torture|snuff|blood\w*|beaten|abuse[ds]?)\b|强奸|迷奸|强迫|昏迷|乱伦|兽交|血腥|虐待",
    re.IGNORECASE,
)
NUDITY_PATTERNS = re.compile(
    r"\b(nude|naked|topless|bottomless|nipples?|genitals?|pussy|penis|explicit|intercourse|sex act|orgasm|"
    r"cum|bare[- ]breasted|fully exposed)\b|裸体|全裸|半裸|露点|性交|做爱",
    re.IGNORECASE,
)


@dataclass
class LintReport:
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return not self.errors


def lint_project(
    project: Project,
    episode: Episode | None,
    settings: Settings,
    platform: str | None = None,
) -> LintReport:
    rep = LintReport()

    for char in project.characters:
        if not ADULT_MARKER.search(char.age_look or ""):
            rep.errors.append(
                f"character {char.id}: age_look must state an explicit adult age (e.g. 'adult', 'late 20s')"
            )
        card = " ".join(
            [char.name, char.age_look, char.face, char.hair, char.wardrobe, char.signature_props, char.notes]
        )
        hit = MINOR_PATTERNS.search(card)
        if hit:
            rep.errors.append(f"character {char.id}: minor-coded term {hit.group(0)!r} in character card")

    if episode is not None:
        for panel in episode.panels:
            text = " ".join([panel.shot, panel.emotion, panel.dialogue, panel.action, panel.setting])
            hit = MINOR_PATTERNS.search(text)
            if hit:
                rep.errors.append(f"panel {panel.id}: minor-coded term {hit.group(0)!r}")
            for cid in panel.characters:
                if cid not in project.character_map():
                    rep.errors.append(f"panel {panel.id}: unknown character {cid!r}")

    if project.content_tier == "explicit" and settings.resolved_provider() == "fal":
        rep.errors.append(
            "content_tier=explicit is blocked for the fal provider (fal Acceptable Use Policy forbids sexually "
            "explicit output); use suggestive, or a self-hosted provider under your own legal responsibility"
        )

    if platform:
        prof = PLATFORMS.get(platform)
        if prof is None:
            rep.errors.append(f"unknown platform {platform!r}; choose from {sorted(PLATFORMS)}")
        else:
            if project.render_style not in prof["styles"]:
                rep.errors.append(
                    f"{platform}: render_style={project.render_style} not accepted "
                    f"(allowed: {sorted(prof['styles'])}). {prof['notes']}"
                )
            if project.content_tier not in prof["tiers"]:
                if project.content_tier in prof.get("warn_tiers", set()):
                    rep.warnings.append(f"{platform}: content_tier={project.content_tier} is borderline. {prof['notes']}")
                else:
                    rep.errors.append(
                        f"{platform}: content_tier={project.content_tier} not accepted "
                        f"(allowed: {sorted(prof['tiers'])}). {prof['notes']}"
                    )
            if not prof["synthetic_persona"]:
                rep.warnings.append(f"{platform}: fully synthetic personas may be rejected. {prof['notes']}")
            rep.warnings.append(f"{platform}: labeling - {prof['label']}; verify at {prof['source']}")
    return rep


def format_report(rep: LintReport) -> str:
    lines = [f"ERROR  {e}" for e in rep.errors] + [f"WARN   {w}" for w in rep.warnings]
    lines.append("lint: OK" if rep.ok else "lint: FAILED")
    return "\n".join(lines)


def lint_still(still: Still, project: Project, settings: Settings, platform: str | None = None) -> LintReport:
    """Lint a single-image spec: consent/harm terms, minor-coded terms, nudity vs provider policy."""
    rep = lint_project(project, None, settings, platform)
    cmap = project.character_map()
    if len(still.characters) != 2:
        rep.errors.append(f"still {still.id}: exactly two characters required, got {still.characters}")
    for cid in still.characters:
        if cid not in cmap:
            rep.errors.append(f"still {still.id}: unknown character {cid!r}")
    text = " ".join(
        [still.title, still.setting, still.camera, still.lighting, still.blocking,
         still.wardrobe_state, still.motif, still.mood]
    )
    hit = MINOR_PATTERNS.search(text)
    if hit:
        rep.errors.append(f"still {still.id}: minor-coded term {hit.group(0)!r}")
    hit = HARM_PATTERNS.search(text)
    if hit:
        rep.errors.append(
            f"still {still.id}: term {hit.group(0)!r} implies non-consent or harm; "
            "motifs must be consensual, playful adult dynamics between fictional characters"
        )
    hit = NUDITY_PATTERNS.search(text)
    if hit and settings.resolved_provider() == "fal":
        rep.errors.append(
            f"still {still.id}: {hit.group(0)!r} asks for nudity/explicit content, which fal's policy and "
            "safety checker do not allow; describe covered or implied states instead"
        )
    return rep
