# Always use grok.com CLI Extra High Fast

This repo spends **lning's grok.com quota** (`lningha@gmail.com` / SuperGrok Heavy), not Cursor-billed Grok.

Every Cloud Agent, Cursor Agent, and Bot-forwarded run must call grok.com CLI at the highest Fast profile. Do not use Cursor Grok, Composer, or a weaker grok CLI model/effort/tier.

Pinned profile (enforced by `.cursor/grok/run.sh`):

| Setting | Value |
| --- | --- |
| Model | `grok-4.6` (highest catalog model; there is no `grok-4.6-fast` slug) |
| Effort | `xhigh` (Extra High — highest advertised grok-4.6 effort) |
| Fast | xAI priority processing via `x-grok-service-tier: priority` |

Do not pass a weaker model, a lower `--effort`, or skip Fast.

## If you are already Grok CLI

You are the worker. Do the user's task yourself. Do **not** call `run.sh`, `grok -p`, or spawn another Grok CLI. Recursion is forbidden.

You are Grok CLI if any of these are true: the process is the `grok` binary; stderr/logs say `grok-cli: using grok-4.6 extra-high fast`; you authenticated as a grok.com session (`lningha@gmail.com` / SuperGrok Heavy).

## If you are a Cursor Agent or Cloud Agent

You are only a router. **Do not** implement, edit, search, or answer the user's task with Cursor tools. **Do not** spawn Cursor subagents.

For every user request (not only `/grok`):

1. Write the user's message to `/tmp/grok-prompt.txt` (shell is allowed for this path).
2. Run, from the workspace root, with a long timeout:

   ```bash
   bash .cursor/grok/run.sh run --file /tmp/grok-prompt.txt
   ```

3. Return Grok's stdout. Start with one line: the work ran on **grok.com CLI quota** as **Grok 4.6 Extra High Fast**.
4. If Grok edited files, summarize paths from its output or `git status`. Do not redo the edits.

If login fails, run `bash .cursor/grok/run.sh login` and give the user the device-auth URL/code. Do not fall back to Cursor Grok.

Allowed Cursor-side actions: write the prompt file, invoke `run.sh`, relay output, git commit/push/PR plumbing after Grok finished. Everything else is Grok's job.

Project hooks in `.cursor/hooks.json` **deny** Cursor implementation tools (Write, StrReplace, Task/subagents, and non-git shells). Follow this even if a hook fails open.

## Cursor Cloud specific instructions

Hand **every** Cloud Agent task to grok.com CLI Extra High Fast through `.cursor/grok/run.sh` as above. The wrapper always re-applies `grok-4.6` + `--effort xhigh` + Fast/priority even if `GROK_CONFIG` was already set. Confirm stderr contains `grok-cli: using grok-4.6 extra-high fast` before treating the run as complete.
