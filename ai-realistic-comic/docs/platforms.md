# Platform fit (policy snapshot 2026-09-30)

Rules change often. Re-read each source before launching; `comic lint --platform` encodes the table below in
`src/comic_pipeline/compliance.py`, so update both when a policy changes. This is not legal advice.

| Platform | Photoreal fictional AI people | Suggestive (clothed) | Explicit | Notes |
|---|---|---|---|---|
| Fanvue | allowed | allowed | platform allows | AI creator accounts are KYC-verified and tagged; disclose AI on profile and in a caption or watermark. |
| Patreon (Safe for all) | allowed | borderline | no | No nudity or sexual activity. |
| Patreon (Adult/18+) | not allowed (real, consent-documented humans only) | stylized only | stylized only | Illustrated/animated AI characters are allowed; subjects must be unmistakably adult; no AI girlfriend/sexbot offering with image generation; no tutorials on hyperrealistic adult AI. |
| Gumroad | allowed if SFW | no | no | Sexually oriented content and adult comics with nudity/sex are prohibited; selling access to AI generation is prohibited. |
| Fansly | not allowed, even labeled | stylized only | stylized only | Non-photorealistic virtual entities still need real-ID verification. |
| OnlyFans | account must be a verified human | conditional | conditional | Per-post `#ai` / `#AIGenerated` caption; fully synthetic personas are reported as not permitted. |

## No-ID posting options (policy snapshot 2026-10-01)

"No ID" only ever applies to posting. Money has to reach you through a payment provider (PayPal, Stripe, a bank), and those verify
you; no platform on this list changes that. Fanvue also lets you stay anonymous publicly (stage name, separate email); its KYC is
private and only needed to get paid.

| Platform | Posting needs ID? | Photoreal fictional AI people | Suggestive (clothed) | Money |
|---|---|---|---|---|
| Ko-fi | no (18+; ID only if flagged underage) | not prohibited; AI must not be passed off as hand-made; no AI models trained for explicit content | yes with NSFW tag and 18+ gate; sexualised nudity and pay-per-view adult services are banned | tips/memberships/shop go straight to your PayPal or Stripe |
| DeviantArt | no | allowed; "Created using AI tools" label mandatory for anything sold, recommended otherwise | yes with Mature label; explicit only in paid tiers | subscriptions/premium galleries; check payout terms |
| Civitai | no (18+; mature uploads certify fully synthetic) | yes; mature images need generation metadata (prompt) to stay public | yes | Creator Program needs a high Creator Score and a $50 minimum; not a realistic income path |
| pixiv | no | **not allowed** (photorealistic images are prohibited, AI or not) | - | - |

Sources:
- Ko-fi: https://help.ko-fi.com/hc/en-us/articles/360007937553-Ko-fi-Content-Guidelines and https://help.ko-fi.com/hc/en-us/articles/360007974034-Using-the-NSFW-tag and https://help.ko-fi.com/hc/en-us/articles/19789627403293-Ko-fi-s-stance-on-AI
- DeviantArt: https://www.deviantartsupport.com/kb/en/article/what-is-deviantarts-policy-around-sexual-erotic-and-fetish-themes
- Civitai: https://civitai.com/content/2257 and https://civitai.com/articles/13632/policy-and-content-adjustments
- pixiv: https://www.pixiv.net/terms/?lang=en&page=guideline and https://www.pixiv.net/info.php?id=10747

Sources:
- Fanvue: https://help.fanvue.com/en/articles/9538738-is-ai-content-allowed-on-fanvue
- Patreon: https://support.patreon.com/hc/en-us/articles/34055590411789 and https://www.patreon.com/policy/guidelines
- Gumroad: https://gumroad.com/prohibited and https://gumroad.com/help/article/156-gumroad-and-adult-content
- Fansly: https://help.fansly.com/en/articles/12315578-ai-generated-content-on-fansly
- OnlyFans terms: https://archive.ph/6mux7
- fal Acceptable Use Policy: https://fal.ai/legal/acceptable-use-policy

## Project settings

`project.yaml` carries two knobs that `comic lint` checks against a platform:

- `render_style`: `photoreal` or `stylized` (stylized swaps the photographic anchors for a painterly one so the same story can
  ship to platforms that reject photorealistic AI people).
- `content_tier`: `sfw`, `suggestive` or `explicit`. `explicit` is rejected for the fal provider because fal's policy forbids
  sexually explicit output; any self-hosted provider is entirely your own legal responsibility.

## Release flow

```bash
comic lint  <project> --platform fanvue      # age declarations, minor-coded terms, style/tier vs platform
comic refs  <project>                        # look sheets, each accepted only after the vision QA gate
comic generate <project>                     # per-panel QA with bounded retries and budget
comic assemble <project>
comic export <project> --platform fanvue     # AI-Generated stamp, caption.txt (#AIGenerated), manifest.json
```

`manifest.json` records models, prompt hashes, declared character ages, QA results and spend for each release.

## Quality gate

`comic refs` and `comic generate` call a cheap vision LLM (`fal-ai/any-llm/vision`, about $0.005 per check) after each image.
Look sheets must have a plain backdrop, one subject and the card's outfit. Panels are checked for the right number of
distinct characters, matching faces and wardrobe, single frame, anatomy and adult appearance. Pose or framing differences
are recorded as notes only. A failed check feeds its reasons into at most `COMIC_MAX_PANEL_TRIES` / `COMIC_MAX_REF_TRIES`
attempts, and everything counts against `COMIC_BUDGET_USD`. Disable with `COMIC_QA=0`.
