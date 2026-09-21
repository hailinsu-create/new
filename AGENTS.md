# AGENTS.md

## Active workflow (Grok CLI paused)

Cursor 编排 → ChatGPT 网页（最高思考）PLAN/REVIEW → opencode/ds4.1 WORK → Cursor 核验 → ChatGPT 再评。

- **Gate:** ChatGPT REVIEW `approve | revise | block` + Cursor 核验。`block` 必须停并告知用户。
- **不用** Jev / System One / `jev-decide` / Codex OAuth 冒充网页额度。
- **密钥**只用 Dashboard Secrets / VM profiles（勿提交仓库）。

Grok.com CLI Extra High Fast 已按用户要求**暂定**（见 `.cursor/rules/always-use-grok-cli.mdc` 与空 hooks）。

## Roles

| Role | Who | Cloud Agent behavior |
|------|-----|----------------------|
| PLAN / REVIEW | ChatGPT **网页额度** | `bash .cursor/chatgpt/chatgpt-web.sh -Mode plan\|review -RequestFile <f>`；若 `chatgpt:unavailable` / `not_logged_in` → fail-open 并标注 |
| WORK | `opencode-go/deepseek-v4.1-flash`（ds 4.1） | `bash .cursor/opencode/run-ds41.sh` → **`--variant max`**；**不要** `--auto` |
| VERIFY | Cursor | 跑测、证据、PR；不替代 REVIEW 裁决 |

## Cursor Cloud specific instructions

1. **不要**强制 `bash .cursor/grok/run.sh`。
2. PLAN/REVIEW：优先 `.cursor/chatgpt/chatgpt-web.sh`（CDP Chrome → chatgpt.com）。首次需在专用 Chrome 登录；`bash .cursor/chatgpt/status.sh` 检查。
3. WORK：`bash .cursor/opencode/run-ds41.sh "<task>"`（无 `--auto`）。
4. 禁止用 Codex OAuth 冒充网页额度。
5. Ambush / PaperRoute：`.cursor/skills/paperroute-game-build/SKILL.md`。

## Auth

- OpenCode Go：`OPENCODE_API_KEY` / `~/.local/share/opencode/auth.json`
- ChatGPT web：登录态在 `~/.chatgpt-web/profile`（Environment Save 固化）
- 恢复 Grok：还原 `.cursor/hooks/*.bak`

## Restore Grok CLI later

```bash
cp .cursor/hooks/hooks.json.grok-forced.bak .cursor/hooks.json
cp .cursor/hooks/force-grok-cli.py.bak .cursor/hooks/force-grok-cli.py
cp .cursor/hooks/always-use-grok-cli.mdc.paused.bak .cursor/rules/always-use-grok-cli.mdc
```
