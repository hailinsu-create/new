# Reusable character library

Each folder under `characters/` holds `card.yaml` (locked description, adult age declaration), `ref.png` (look sheet) and `ref.json`
(prompt, model, QA result). `index.yaml` lists versions and checksums.

```bash
comic library                               # list
comic archive <project> <id> --tags a,b     # snapshot (version bumps when the sheet or the card changes)
comic use <other-project> <id>              # import into another project
```

The only approved 样张 are the five files in `samples/approved/`. Fal two-person crops that were briefly copied onto `ref.png` are wrong and now live in `characters/<id>/legacy/fal_pose_mislabel/`. They are not canonical. Makeup prompts are `characters/{baisuzhen_snake,xuxian,persephone,hades}/makeup_prompt.md`. A new `ref.png` is written only after the local Qwen makeup run. Older solo costume sheets remain in `legacy/costume-ref.png`.

Known deviations of the legacy costume sheets (documented, not hidden):
- 哈迪斯: pointed ears and orange soul-fire in the render; no weapon on the sheet (the bident is added in scene prompts).
- 珀耳塞福涅: eye color drifts orange; dress slit is high.
- 许仙: background/face flagged by QA as slightly off the card.
- 白素贞 (human form) and 白素贞 (蛇形): same face; the serpent form passed QA. The human-form sheet is still the solo costume card.

## Approved scene templates (`library/stills/`)

`still.yaml` + `approved.jpg` for each user-approved two-character still (recipe: nano-banana-pro, see `docs/still-mode.md`).
Copy a `still.yaml` into a project's `stills/` folder and adjust it, or start from `templates/still.template.yaml`.

Library state: hades, persephone, baisuzhen_snake, and xuxian `ref.png` files are the F34 Qwen makeup sheets (896×1200, Bai composited 1792×1200). The fal-pose files previously indexed as those versions stay in `legacy/fal_pose_mislabel/`. baisuzhen human form stays v2.
