# Quota / coding CLIs in Cursor云开发

**Bot共享电脑** = shared Linux box for Grok Bot agents.
**Cursor云开发** = Cursor Environment / Cloud Agent VMs (this snapshot).

Install is idempotent via:

```bash
bash .cursor/quota-clis/install-all.sh
# also invoked from .cursor/grok/inject-from-snapshot.sh on Environment start
```

**Excluded by policy:** Codex / ChatGPT / OpenAI / GPT CLIs (`除了gpt之外`).

Binaries on PATH after inject:

| CLI | Binary | Typical install path |
| --- | --- | --- |
| Grok | `grok` | `~/.grok/bin/grok` |
| Antigravity | `agy` | `~/.local/bin/agy` |
| OpenCode | `opencode` | `~/.opencode/bin/opencode` |
| Kimi Code | `kimi` | `~/.kimi-code/bin/kimi` |

Do **not** print secrets. Prefer Environment secret mounts / one-time interactive login, then **Save** the Environment once so auth survives new Cloud Agent boots.

---

## Auth (none of these bake credentials into git)

### Grok (`grok`)

- Interactive: `bash .cursor/grok/run.sh login` → device auth in browser.
- Session file: `~/.grok/auth.json` (OIDC refresh supported by `run.sh`).
- Pin wrapper already uses grok.com Extra High Fast: `bash .cursor/grok/run.sh run --file /tmp/prompt.txt`

### Antigravity (`agy`)

- Google OAuth on first use — **cannot** bake secrets into the snapshot.
- On a fresh VM: run `agy` once (or `agy -p "ping"`) and complete Google login in the browser / device flow.
- After login succeeds once on the Environment desktop, **Save** the Environment so the credential store persists.

### OpenCode + OpenCode Go (`opencode`)

Preferred non-interactive patterns (pick one; never commit keys):

1. **Env var** (Environment secret): set `OPENCODE_API_KEY` to the Go/Zen key from the OpenCode console.
2. **Auth file mount**: place `~/.local/share/opencode/auth.json` on the VM (mode `600`). Provider entry for Go looks like `{"opencode-go":{"type":"api","key":"..."}}` — write it via secret mount, do not echo.
3. **Interactive**: `opencode auth login` or TUI `/connect` → select **OpenCode Go** → paste key.

Optional: `OPENCODE_AUTH_CONTENT` can supply auth JSON inline for ephemeral VMs (still a secret; do not log it).

### Kimi Code (`kimi`)

- Interactive: start `kimi`, then `/login` → **Kimi Code (OAuth)** device flow, or paste a Kimi Code / Platform API key.
- Config/home: `~/.kimi-code/` (override with `KIMI_CODE_HOME`).
- After first login on the Environment, **Save** so `~/.kimi-code` persists.

---

## Call recipes (non-interactive)

Assume workspace root is `$CURSOR_WORKSPACE` or `/workspace/<repo>`.

### Grok (default router target)

```bash
printf '%s\n' 'YOUR PROMPT' > /tmp/grok-prompt.txt
bash .cursor/grok/run.sh run --file /tmp/grok-prompt.txt
```

### Antigravity `agy`

```bash
agy -p "YOUR PROMPT" --dangerously-skip-permissions
# optional: pick model / effort
agy -p "YOUR PROMPT" --model MODEL_ID --effort high --dangerously-skip-permissions
# list models once logged in
agy models
```

### OpenCode Go (`opencode` with `opencode-go/...` models)

```bash
opencode run -m opencode-go/deepseek-v4.1-flash --variant max --auto --dir "$PWD" "YOUR PROMPT"
# other Go model ids (examples; list live with: opencode models opencode-go)
#   opencode-go/kimi-k2.7-code
#   opencode-go/kimi-k3
#   opencode-go/minimax-m2.7
#   opencode-go/glm-5.3-flash
```

### Kimi Code `kimi`

```bash
kimi -p "YOUR PROMPT"
# continue last session
kimi -c -p "follow-up"
```

---

## Cursor hooks note

`.cursor/hooks.json` still defaults the Cursor Agent to **route via Grok CLI** (spend grok.com quota, not Cursor-billed compute). Shell invocations of `agy`, `opencode`, and `kimi` are allowlisted so you can call them explicitly when you want those quotas instead.

Do **not** use Cloud Agents as free R&D compute; provision binaries via this Environment snapshot / install scripts, then Save once after auth.

---

## One-time Environment Save checklist

1. Scripts land in the repo that feeds the Environment (this tree).
2. Environment start hook runs `inject-from-snapshot.sh` (installs Grok + quota CLIs + PATH).
3. User completes: Grok device login, `agy` Google OAuth, OpenCode Go key (`OPENCODE_API_KEY` or auth.json), Kimi `/login`.
4. **Environment → Save** once so binaries + auth survive new Cloud Agent VMs.
5. Never commit `auth.json`, API keys, or OAuth tokens.
