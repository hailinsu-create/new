---
name: chatgpt-ds-workflow
description: >-
  ChatGPT web PLAN/REVIEW + opencode/DeepSeek WORK pipeline for this repo.
  Use when planning, reviewing, or implementing under the B+C workflow
  (Grok CLI paused).
---

# ChatGPT + DeepSeek (opencode) workflow

## Cloud Agent (Ubuntu VM)

| Step | Action |
|------|--------|
| PLAN | `bash .cursor/chatgpt/chatgpt-web.sh -Mode plan -RequestFile <f> -OutFile <out>` |
| WORK | `bash .cursor/opencode/run-ds41.sh "<task>"` (**no** `--auto`) |
| REVIEW | `bash .cursor/chatgpt/chatgpt-web.sh -Mode review -RequestFile <f> -OutFile <out>` → need `VERDICT: approve\|revise\|block` |

If bridge returns `chatgpt:unavailable` / `chatgpt:not_logged_in`: label `chatgpt:unavailable` and **fail-open**. Never fake with Codex OAuth.

One-time: `bash .cursor/chatgpt/launch-cdp-chrome.sh` then sign in; `bash .cursor/chatgpt/status.sh`.

## Local Windows (reference)

- Plan/Review: `powershell -File ~/.cursor/scripts/chatgpt-web.ps1 -Mode plan|review -RequestFile <f> -Workspace <ws>`
- Work: `bash .cursor/opencode/run-ds41.sh` / `opencode run -m opencode-go/deepseek-v4.1-flash`
