# Single refined still (two characters)

```bash
comic refs  <project>                    # look sheets must exist and pass QA
comic still <project> <still-id> --platform fanvue
```

A still is `projects/<project>/stills/<id>.yaml` (see `demo-spider-wukong-v3/stills/silk-bind.yaml`): the two characters,
camera, lighting, blocking (who is where, gaze, touch), wardrobe state, and `motif` (the specific dynamic the image is about).

Pipeline, all counted against `COMIC_STILL_BUDGET_USD` (default $0.40):

1. `COMIC_STILL_CANDIDATES` candidates (default 2) from the multi-reference edit model with both look sheets.
2. A vision judge scores each 0-10 on identity, distinction, interaction, aesthetics, anatomy, wardrobe and motif, and lists
   deal-breakers (collage, merged faces, broken hands, wrong head count, minor-looking figure).
3. If the best candidate has a deal-breaker or averages below `COMIC_STILL_MIN_SCORE` (default 7.5), one targeted edit pass
   applies the judge's concrete fixes while keeping composition and identities; the better of the two is kept.
4. `fal-ai/aura-sr` super-resolution, resized to exactly 2x the base size.

Output: `output/<project>/stills/<id>/final.png`, `still.json` (scores, prompt, spend) and `budget.json`.

## Content limits enforced by `comic still`

- Both characters must declare an explicit adult age; minor-coded terms are rejected.
- Motifs must be consensual adult dynamics; terms implying non-consent, coercion, gore or incest are rejected.
- Nudity/explicit terms are rejected for the fal provider: fal's policy forbids sexually explicit output and its safety checker
  blanks nude images. Describe covered or implied states (sheer, slipping, wet fabric) instead.
