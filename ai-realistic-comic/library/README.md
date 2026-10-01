# Reusable character library

Each folder under `characters/` holds `card.yaml` (locked description, adult age declaration), `ref.png` (look sheet) and `ref.json`
(prompt, model, QA result). `index.yaml` lists versions and checksums.

```bash
comic library                               # list
comic archive <project> <id> --tags a,b     # snapshot (version bumps when the sheet or the card changes)
comic use <other-project> <id>              # import into another project
```

Known deviations of the current v2 sheets (documented, not hidden):
- 哈迪斯: pointed ears and orange soul-fire in the render; no weapon on the sheet (the bident is added in scene prompts).
- 珀耳塞福涅: eye color drifts orange; dress slit is high.
- 许仙: background/face flagged by QA as slightly off the card.
- 白素贞 (human form) and 白素贞 (蛇形): same face; the serpent form passed QA.
