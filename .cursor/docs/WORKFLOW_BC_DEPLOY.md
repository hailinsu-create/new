# Workflow deploy note (2026-09-20)

## Done

- Cleared `.cursor/hooks.json` (no force-grok hooks). Backups under `.cursor/hooks/*.bak`.
- `always-use-grok-cli.mdc` → `alwaysApply: false` (paused stub).
- `force-grok-cli.py` → always-allow noop (original `.bak`).
- Added `AGENTS.md`, `.cursor/rules/opencode-routing.mdc`, `.cursor/skills/chatgpt-ds-workflow/SKILL.md`.
- Installed `opencode` **1.18.31** at `~/.opencode/bin/opencode` (VM-local; not in git).

## Auth

- OpenCode Go key on this VM (`~/.local/share/opencode/auth.json` + `~/.bashrc` `OPENCODE_API_KEY`). Prefer also Dashboard Secret for new pods.
- WORK model: `opencode-go/deepseek-v4.1-flash` (ds 4.1)
- **No `--auto`** (user: too slow).

```bash
bash .cursor/opencode/run-ds41.sh "<task>"
# or:
opencode run -m opencode-go/deepseek-v4.1-flash "<task>"
```

## Not on this VM yet

- ChatGPT web bridge (expected `chatgpt:unavailable` fail-open)
- Pre-baked opencode in environment build (install was runtime-only)
