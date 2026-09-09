---
name: grok
description: >-
  Spend the grok.com CLI account quota from Cursor on Grok 4.6 Extra High Fast.
  Use when the user types /grok, 用 grok, 用 grok 额度, 走 grok.com, 喊 grok, grok cli,
  用另一个 grok, or asks to run the task on the grok.com login instead of Cursor-billed
  Grok. Do not use for ordinary Cursor Grok work unless one of those triggers is present.
icon: terminal
color: cyan
metadata:
  surfaces:
    - ide
    - cloud
---

# Use grok.com quota from Cursor

Cursor's model picker Grok is billed to the current Cursor account. This skill does **not** change that picker. It forwards the user's task to the **Grok CLI** (`grok`) already logged into grok.com, so the real inference uses that grok.com quota.

You are the router. **Do not implement the user's task with Cursor tools.**

## Pinned profile

Every `/grok` run is locked to the highest grok.com CLI model at Extra High Fast:

| Setting | Value |
| --- | --- |
| Model | `grok-4.6` (highest catalog model; there is no `grok-4.6-fast` slug) |
| Effort | `xhigh` (Extra High) |
| Fast | xAI priority processing via `x-grok-service-tier: priority` |

Do not pass a weaker model, a lower `--effort`, or skip Fast. The wrapper already pins these; do not override with `GROK_CLI_MODEL`.

## 口令

Treat any of these as an explicit trigger:

- `/grok`
- `用 grok` / `用grok` / `grok一下`
- `用 grok 额度` / `走 grok.com`
- `喊 grok` / `grok cli`
- `用另一个 grok` / `用另一个账号的 grok`

The rest of the message is the task to send to Grok CLI.

## Steps

1. Run the doctor from the workspace root:

   ```bash
   bash .cursor/skills/grok/scripts/run.sh status
   ```

   If it exits `2` (not logged in), start device auth and give the user the URL and code:

   ```bash
   bash .cursor/skills/grok/scripts/run.sh login
   ```

   Do not continue until `status` shows a grok.com session. Confirm the printed profile is `grok-4.6 extra-high fast`.

2. Write the user's task (plus only the repo context they already named) to a prompt file. Do not solve it yourself first.

3. Run Grok CLI. Give the shell a long budget (several minutes); Extra High Fast is still a full agent turn on grok.com:

   ```bash
   bash .cursor/skills/grok/scripts/run.sh run --file /tmp/grok-prompt.txt
   ```

4. Return Grok's stdout to the user. Prefix one short line that the work ran on **grok.com CLI quota** as **Grok 4.6 Extra High Fast**, not Cursor Grok. If Grok edited files, summarize those paths from the output or `git status`; do not redo the edits.

## Rules

- `--always-approve` is already in the wrapper so headless grok does not hang on tool permission prompts.
- Do not print `~/.grok/auth.json` or tokens.
- Do not fall back to doing the task with Cursor Grok because it would be faster. If grok CLI fails, report the error and stop.
- A `/grok` turn still uses a little Cursor quota for routing. The coding/inference work must go through `run.sh`.
