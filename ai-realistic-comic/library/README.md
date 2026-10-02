# Reusable character library

Each folder under `characters/` holds `card.yaml` (locked description, adult age declaration), `ref.png` (look sheet) and `ref.json`
(prompt, model, QA result). `index.yaml` lists versions and checksums.

```bash
comic library                               # list
comic archive <project> <id> --tags a,b     # snapshot (version bumps when the sheet or the card changes)
comic use <other-project> <id>              # import into another project
```

Primary look sheets for the two approved stills are the fal two-person pose samples (`ref.png`). The old solo costume sheets are `legacy/costume-ref.png` (faces only):

- persephone ← `stills/hades-persephone-throne/approved.jpg`
- hades ← `stills/hades-persephone-throne/pose-fal-b.jpg`
- baisuzhen_snake ← `stills/baisuzhen-xuxian-coil/approved.jpg`
- xuxian ← `stills/baisuzhen-xuxian-coil/pose-fal-b.jpg`

Known deviations of the legacy costume sheets (documented, not hidden):
- 哈迪斯: pointed ears and orange soul-fire in the render; no weapon on the sheet (the bident is added in scene prompts).
- 珀耳塞福涅: eye color drifts orange; dress slit is high.
- 许仙: background/face flagged by QA as slightly off the card.
- 白素贞 (human form) and 白素贞 (蛇形): same face; the serpent form passed QA. The human-form sheet is still the solo costume card.

## Approved scene templates (`library/stills/`)

`still.yaml` + `approved.jpg` for each user-approved two-character still (recipe: nano-banana-pro, see `docs/still-mode.md`).
Copy a `still.yaml` into a project's `stills/` folder and adjust it, or start from `templates/still.template.yaml`.

Library state: hades v4, persephone v3, baisuzhen v2, baisuzhen_snake v3, xuxian v3. v4/v3 on the four pose sheets are the fal stills; baisuzhen human form stays v2.
