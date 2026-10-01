from __future__ import annotations

import json
import re
from pathlib import Path

import httpx

from comic_pipeline.config import Settings
from comic_pipeline.models import Episode, Panel, Project
from comic_pipeline.prompts.genres import GENRE_STYLE


PLAN_SYSTEM = """You are a live-action comic storyboard director.
Return ONLY valid JSON matching:
{
  "title": string,
  "genre": "xianxia"|"fantasy"|"scifi",
  "logline": string,
  "panels": [
    {
      "id": "p01",
      "page": 1,
      "shot": "wide|medium|close-up|over-shoulder|...",
      "characters": ["char_id"],
      "emotion": string,
      "dialogue": string,
      "action": string,
      "setting": string,
      "negative": string
    }
  ]
}
Rules: 6-12 panels; keep wardrobe locked; photorealistic live-action framing; Chinese dialogue OK.
"""


def _mock_episode(project: Project, story: str) -> Episode:
    chars = [c.id for c in project.characters] or ["hero"]
    hero = chars[0]
    panels = [
        Panel(
            id="p01",
            page=1,
            shot="wide establishing",
            characters=[hero],
            emotion="awe",
            dialogue="",
            action="stands at the threshold of a vast realm",
            setting="misty mountain pass at dawn",
        ),
        Panel(
            id="p02",
            page=1,
            shot="medium",
            characters=[hero],
            emotion="resolve",
            dialogue="此劫，我渡。",
            action="tightens grip on signature prop",
            setting="stone path lined with ancient runes",
        ),
        Panel(
            id="p03",
            page=1,
            shot="close-up",
            characters=[hero],
            emotion="tension",
            dialogue="",
            action="eyes reflect distant stormlight",
            setting="wind-swept cliff",
        ),
        Panel(
            id="p04",
            page=1,
            shot="over-shoulder",
            characters=chars[:2],
            emotion="confrontation",
            dialogue="你不该来。",
            action="faces an opposing silhouette",
            setting="broken bridge over cloud sea",
        ),
        Panel(
            id="p05",
            page=1,
            shot="dynamic medium",
            characters=[hero],
            emotion="surge",
            dialogue="",
            action="unleashes controlled energy burst",
            setting="bridge stones cracking",
        ),
        Panel(
            id="p06",
            page=1,
            shot="wide coda",
            characters=[hero],
            emotion="quiet triumph",
            dialogue="路还长。",
            action="walks into clearing light",
            setting="sun breaking through storm clouds",
        ),
    ]
    return Episode(
        title=project.title or project.name,
        genre=project.genre,
        logline=story.strip().splitlines()[0][:160] if story.strip() else "A short live-action tale.",
        panels=panels,
    )


def plan_episode(project: Project, story_path: Path, settings: Settings) -> Episode:
    story = story_path.read_text(encoding="utf-8")
    if settings.comic_mock or not settings.openai_api_key:
        return _mock_episode(project, story)

    cast = "\n".join(c.prompt_block() for c in project.characters)
    user = (
        f"Genre: {project.genre}\nStyle anchor: {GENRE_STYLE[project.genre]}\n"
        f"Cast:\n{cast}\n\nStory:\n{story}\n"
    )
    payload = {
        "model": settings.openai_model,
        "temperature": 0.4,
        "response_format": {"type": "json_object"},
        "messages": [
            {"role": "system", "content": PLAN_SYSTEM},
            {"role": "user", "content": user},
        ],
    }
    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }
    url = settings.openai_base_url.rstrip("/") + "/chat/completions"
    with httpx.Client(timeout=120.0) as client:
        resp = client.post(url, headers=headers, json=payload)
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"]["content"]
    data = json.loads(_extract_json(content))
    data.setdefault("genre", project.genre)
    data.setdefault("title", project.title or project.name)
    return Episode.model_validate(data)


def _extract_json(text: str) -> str:
    text = text.strip()
    if text.startswith("{"):
        return text
    match = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not match:
        raise ValueError("LLM did not return JSON")
    return match.group(0)
