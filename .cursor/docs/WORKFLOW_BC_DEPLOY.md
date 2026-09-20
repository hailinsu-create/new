# Workflow deploy note (2026-09-20)

## Done

- Grok force-routing paused (hooks empty; backups under `.cursor/hooks/*.bak`)
- OpenCode Go WORK: `bash .cursor/opencode/run-ds41.sh` → `opencode-go/deepseek-v4.1-flash` (**no `--auto`**)
- ChatGPT **web quota** PLAN/REVIEW bridge:
  - `bash .cursor/chatgpt/chatgpt-web.sh -Mode plan|review -RequestFile <f>`
  - CDP Chrome `~/.chatgpt-web/profile` :9222
  - Smoke: `CHATGPT_WEB_OK`

## Auth (VM-local, not in git)

- OpenCode: `~/.local/share/opencode/auth.json` + `OPENCODE_API_KEY`
- ChatGPT: cookies in `~/.chatgpt-web/profile` — Environment **Save** after snapshot

## Invoke cheat-sheet

```bash
bash .cursor/chatgpt/status.sh
bash .cursor/chatgpt/chatgpt-web.sh -Mode plan  -RequestFile req.md -OutFile plan.md
bash .cursor/opencode/run-ds41.sh "<task>"
bash .cursor/chatgpt/chatgpt-web.sh -Mode review -RequestFile req.md -OutFile review.md
```
