---
name: chatgpt-ds-workflow
description: >-
  ChatGPT web PLAN/REVIEW + opencode/DeepSeek WORK pipeline for this repo.
  Use when planning, reviewing, or implementing under the B+C workflow
  (Grok CLI paused). Cloud Agents fail-open when the ChatGPT web bridge is unavailable.
---

# ChatGPT + DeepSeek (opencode) workflow

## When to use

Any non-trivial change while Grok CLI is paused: plan before large edits, review before merge claims, and prefer opencode for WORK when authenticated.

## Cloud Agent (Ubuntu VM)

Windows `chatgpt-web.ps1` / Edge CDP **do not exist** here.

| Step | Action |
|------|--------|
| PLAN | If no ChatGPT bridge: write a short PLAN in-agent, prefix with `chatgpt:unavailable`, continue |
| WORK | `export PATH="$HOME/.opencode/bin:$PATH"` then `opencode run --auto -m opencode-go/deepseek-v4.1-flash "<task>"`; else implement directly |
| REVIEW | Same fail-open; require explicit `approve\|revise\|block` only when bridge works |

Never call `jev-decide`. Never fake ChatGPT with Codex OAuth.

## Local Windows (reference)

- Plan/Review: `powershell -File ~/.cursor/scripts/chatgpt-web.ps1 -Mode plan|review -RequestFile <f> -Workspace <ws>`
- Work: `opencode-go/deepseek-v4.1-flash --variant max --auto` (or current opencode equivalent)

## Opencode smoke

```bash
export PATH="$HOME/.opencode/bin:$PATH"
opencode --version
# Expect >= 1.14.24
```

Auth: Dashboard Secret `DEEPSEEK_API_KEY`, then configure provider (`opencode auth` / `/connect` deepseek) once per environment snapshot.
