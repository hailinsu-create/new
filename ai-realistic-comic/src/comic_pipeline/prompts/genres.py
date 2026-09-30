from __future__ import annotations

GENRE_STYLE: dict[str, str] = {
    "xianxia": (
        "cinematic still photograph, photorealistic live-action xianxia fantasy, "
        "natural misty mountain light, intricate silk and jade textures, "
        "East Asian mythic atmosphere, shallow depth of field, 35mm film look, "
        "NOT anime, NOT cartoon, NOT illustration"
    ),
    "fantasy": (
        "cinematic still photograph, photorealistic high fantasy live-action, "
        "volumetric god rays, weathered armor and cloak fabrics, epic landscape, "
        "shallow depth of field, IMAX still frame, "
        "NOT anime, NOT cartoon, NOT illustration"
    ),
    "scifi": (
        "cinematic still photograph, photorealistic science-fiction live-action, "
        "practical and holographic UI glow, wet concrete and alloy materials, "
        "anamorphic lens flares restrained, Blade-Runner-adjacent mood without copying, "
        "NOT anime, NOT cartoon, NOT illustration"
    ),
}


def genre_negative(genre: str) -> str:
    base = (
        "anime, manga, cartoon, comic book ink, cel shading, chibi, deformed face, "
        "extra limbs, watermark, text overlay, logo"
    )
    extras = {
        "xianxia": "modern streetwear, western cowboy",
        "fantasy": "modern city street, smartphones",
        "scifi": "medieval castle, fantasy dragons",
    }
    return f"{base}, {extras.get(genre, '')}".strip(", ")
