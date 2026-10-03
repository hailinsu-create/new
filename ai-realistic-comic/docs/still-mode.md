# Single refined still (two characters)

**Cast lock:** any future Asian woman / Asian man / Western woman / Western man shots must use the four standing actors in `library/cast/CAST.md` (林晚棠 / 顾承安 / 伊莲·沃斯 / 阿德里安·凯恩) so identity does not drift.

破限静帧是另一条本地 Qwen 模式，见 `explicit-still-mode.md`。不要把这类图送进下面的 fal nano-banana 流程。

**Approved recipe (locked in by the user after review):** `fal-ai/nano-banana-pro/edit` is the default model for stills
(`FAL_STILL_MODEL`, 2K output at about $0.15 per image, so `COMIC_STILL_BUDGET_USD` defaults to $0.80 and at most
`COMIC_STILL_MAX_CANDIDATES`=3 candidates are generated). In the capped four-model test on the Hades x Persephone lap pose it
produced the cleanest anatomy and best look; sample: `docs/samples/approved-nano-banana-pro-hades-persephone.jpg`.
Start every new still from the template:

```bash
comic still-new <project> <still-id> <char_a> <char_b>   # copies templates/still.template.yaml
comic still <project> <still-id> --platform fanvue
```

Template rules that made the approved sample: alias-only descriptions (no famous names), camera framed from the hips up
(legs/feet out of frame), full look sheets as references, touch/hand poses that rest on fabric or props, covered wardrobe.
Per-still `edit_model`, `ref_crop`, `crop_top`/`crop_bottom` remain available as safety nets. aura-sr upscaling is skipped
when the model output is already at least `COMIC_UPSCALE_MIN_WIDTH` (1600) px wide.

```bash
comic refs  <project>                    # look sheets must exist and pass QA
comic still <project> <still-id> --platform fanvue
```

A still is `projects/<project>/stills/<id>.yaml` (see `demo-spider-wukong-v3/stills/silk-bind.yaml`): the two characters,
camera, lighting, blocking (who is where, gaze, touch), wardrobe state, and `motif` (the specific dynamic the image is about).

Pipeline, all counted against `COMIC_STILL_BUDGET_USD` (default $0.80):

1. `COMIC_STILL_CANDIDATES` candidates (default 2) from the multi-reference edit model with both look sheets.
2. A vision judge scores each 0-10 on identity, distinction, interaction, aesthetics, anatomy, wardrobe and motif, and lists
   deal-breakers (collage, merged faces, broken hands, wrong head count, minor-looking figure).
3. If the best candidate has a deal-breaker or averages below `COMIC_STILL_MIN_SCORE` (default 7.5), one targeted edit pass
   applies the judge's concrete fixes while keeping composition and identities; the better of the two is kept.
4. `fal-ai/aura-sr` super-resolution, resized to exactly 2x the base size.

Output: `output/<project>/stills/<id>/final.png`, `still.json` (scores, prompt, spend) and `budget.json`.

## Anatomy gate (extra hands, fingers, limbs)

Cost note: the count-based audit (`COMIC_ANATOMY_AUDIT=1`, about $0.015 per candidate) and the strict second opinion (`COMIC_STRICT_AUDIT=1`, about
$0.03 per still) are **off by default** because they missed real defects (see the reality check below). Default per still is now
2 candidates x $0.15 + two $0.005 judge calls, about $0.31; set `COMIC_STILL_CANDIDATES=1` for about $0.155.


Multi-person contact poses (embraces, laps, coils) are still the hardest case for diffusion/edit models: arms overlap, so the
model can lose track of which limb belongs to whom. A single 0-10 "anatomy" score averaged with seven other scores hides
this, so the still pipeline now counts instead of scoring:

1. Per candidate, a flash VLM counts people/arms/hands/legs on the full frame and the fingers on each visible hand on two
   overlapping crops. More than 2 arms/hands/legs per person, a wrong head count, unattached limbs, 6+ fingers, <=3 fingers,
   fused or duplicated parts are blocking. A hand showing 4 fingers, or "missing"/occluded items, are repair hints only
   (occlusion and cropping cause false alarms). Non-human forms (serpent tail) are declared from `Character.form`.
2. The judge's anatomy score below 6 also blocks.
3. If no candidate passes, up to `COMIC_STILL_MAX_CANDIDATES` (default 3) are generated; each repair pass feeds the concrete
   anatomy findings into the edit prompt ("Repair: ...").
4. The shortlisted winner gets one strict second opinion from a reasoning model (`FAL_STRICT_MODEL`, default
   `google/gemini-2.5-pro`, `COMIC_STRICT_AUDIT=1`) that must enumerate every arm back to its shoulder. If it fails, one repair
   pass runs when `COMIC_STRICT_BLOCKING=1`; by default it is advisory (`strict_warnings` in `still.json`) because it both missed real
   defects and flagged fine images. An empty reply is retried once, then recorded as skipped.
5. Unresolved blockers are never upscaled; `still.json` has `needs_review: true` and the CLI prints a warning.

The prompt carries an explicit anatomy rule and an anatomy negative list. Poses that hide hands (hand on fabric, behind a
neck, resting on a throne arm) are less error-prone than fingers-to-lips close-ups.

**Reality check (measured, not assumed):** on the Hades x Persephone lap pose, the count-based checks (flash and the reasoning
model) reported "4 arms, 5 fingers each" on images a human reviewer saw with an extra hand and six fingers/toes on every
person. Vision models are poor at counting digits, so these checks are a weak filter, not a guarantee. What actually
removed the errors was *not showing the parts*:

- `ref_crop` (e.g. 0.5): feed head-to-waist crops of the look sheets. Full-body refs make edit models reproduce legs and
  bare feet regardless of the camera text.
- `crop_top` / `crop_bottom`: deterministic reframing after generation. Models ignore "legs and feet out of frame".
- `edit_model: fal-ai/gpt-image-1.5/edit`: follows framing and pose text (chest-up, seed passed mouth to mouth) far better
  than seedream/nano-banana-pro/flux-2-pro, which all drew full-body laps with extra hands in the same test.
- Prefer poses where hands/feet are not the subject (close two-shots, faces, shoulders, hands hidden by hair).

Limits: the checker is itself a vision model; it can miss errors or raise false alarms. Eyeball the final image.

## Content limits enforced by `comic still`

- Both characters must declare an explicit adult age; minor-coded terms are rejected.
- Motifs must be consensual adult dynamics; terms implying non-consent, coercion, gore or incest are rejected.
- Nudity/explicit terms are rejected for the fal provider: fal's policy forbids sexually explicit output and its safety checker
  blanks nude images. Describe covered or implied states (sheer, slipping, wet fabric) instead.
