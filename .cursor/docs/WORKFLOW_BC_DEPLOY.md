# Workflow deploy note (2026-09-20)

## Done

- Cleared `.cursor/hooks.json` (no force-grok hooks). Backups under `.cursor/hooks/*.bak`.
- `always-use-grok-cli.mdc` → `alwaysApply: false` (paused stub).
- `force-grok-cli.py` → always-allow noop (original `.bak`).
- Added `AGENTS.md`, `.cursor/rules/opencode-routing.mdc`, `.cursor/skills/chatgpt-ds-workflow/SKILL.md`.
- Installed `opencode` **1.18.31** at `~/.opencode/bin/opencode` (VM-local; not in git).

## Auth still needed (user)

Add Dashboard Secrets (requested this turn):

- `DEEPSEEK_API_KEY` (required for DeepSeek WORK)
- `OPENCODE_API_KEY` (optional, OpenCode Go)

Then either re-snapshot the environment or run `opencode` `/connect` deepseek once on a keeper/bootstrap VM and Save.

## Not on this VM yet

- ChatGPT web bridge (expected `chatgpt:unavailable` fail-open)
- Pre-baked opencode in environment build (install was runtime-only)
