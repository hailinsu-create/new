# ChatGPT web quota bridge (Cloud)

Spends **chatgpt.com web quota** via dedicated Chrome CDP — not OpenAI API, not Codex.

## One-time login

```bash
bash .cursor/chatgpt/launch-cdp-chrome.sh
bash .cursor/chatgpt/status.sh   # expect logged_in true after you sign in
```

In the Cloud desktop Chrome window, sign in to ChatGPT. Reply「已登录」in the agent chat when done. Then Save the Environment snapshot so the profile cookies persist.

## PLAN / REVIEW

```bash
bash .cursor/chatgpt/chatgpt-web.sh -Mode plan  -RequestFile /tmp/plan-req.md -OutFile /tmp/plan-out.md
bash .cursor/chatgpt/chatgpt-web.sh -Mode review -RequestFile /tmp/review-req.md -OutFile /tmp/review-out.md
```

Exit codes:
- `0` ok
- `2` CDP / chrome unavailable → treat as `chatgpt:unavailable` (fail-open)
- `4` not logged in → `chatgpt:not_logged_in`

## Layout

| Path | Role |
|------|------|
| `launch-cdp-chrome.sh` | Chrome CDP on `:9222`, profile `~/.chatgpt-web/profile` |
| `chatgpt-web.sh` | CLI (Windows `chatgpt-web.ps1` analogue) |
| `drive.py` | Playwright over CDP |
| `status.sh` | CDP + login heuristic |
| `.venv/` | local Playwright (gitignored) |
