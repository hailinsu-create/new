# Workflow deploy note (2026-09-20)

## Done

- Cleared `.cursor/hooks.json` (no force-grok hooks). Backups under `.cursor/hooks/*.bak`.
- `always-use-grok-cli.mdc` → `alwaysApply: false` (paused stub).
- `force-grok-cli.py` → always-allow noop (original `.bak`).
- Added `AGENTS.md`, `.cursor/rules/opencode-routing.mdc`, `.cursor/skills/chatgpt-ds-workflow/SKILL.md`.
- Installed `opencode` **1.18.31** at `~/.opencode/bin/opencode` (VM-local; not in git).

## Auth

- OpenCode Go key configured on this VM (`~/.local/share/opencode/auth.json` + `OPENCODE_API_KEY`).
- Prefer Dashboard Secret `OPENCODE_API_KEY` so new pods inherit it (do not commit the key).
- WORK model: `opencode-go/deepseek-v4.1-flash` (ds 4.1)

```bash
export PATH="$HOME/.opencode/bin:$PATH"
opencode run --auto -m opencode-go/deepseek-v4.1-flash "<task>"
```

## Not on this VM yet

- ChatGPT web bridge (expected `chatgpt:unavailable` fail-open)
- Pre-baked opencode in environment build (install was runtime-only)
