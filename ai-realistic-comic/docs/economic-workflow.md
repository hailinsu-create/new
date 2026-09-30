# Economic fal workflow

Goal: beat draft-1 quality **without infinite rerolls**.

## Hard caps
- `COMIC_BUDGET_USD` default `0.80`
- `COMIC_MAX_REF_TRIES` default `3` per character
- `COMIC_MAX_PANEL_TRIES` default `2` per panel
- `COMIC_MAX_PAGE_REPAIR` default `2` (manual repair budget)
- `COMIC_FORBID_MULTI_FACE=true` — equal two-face shots rejected

## Strategy
1. Reuse look sheets when present (`cast` / generate will not regenerate unless `--force-ref`).
2. Prefer single-character PuLID cut shots.
3. Atmosphere plates use cheaper Flux Dev.
4. On retry, simplify composition — do not blind-roll the same prompt.
5. Stop when budget is exhausted; write `output/<project>/budget.json`.

## Cost cheat-sheet (approx)
- Flux Dev ≈ `$0.025` / image
- Flux PuLID ≈ `$0.033` / image
