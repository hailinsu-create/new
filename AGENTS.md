# AGENTS.md

## Active workflow (Grok CLI paused)

Cursor 编排 → ChatGPT 网页（最高思考）PLAN/REVIEW → opencode/ds4.1 WORK → Cursor 核验 → ChatGPT 再评。

- **Gate:** ChatGPT REVIEW `approve | revise | block` + Cursor 核验。`block` 必须停并告知用户。
- **不用** Jev / System One / `jev-decide` / Codex OAuth 冒充网页额度。
- **密钥**只用 Dashboard Secrets / VM `auth.json`（勿提交仓库）。

Grok.com CLI Extra High Fast 已按用户要求**暂定**（见 `.cursor/rules/always-use-grok-cli.mdc` 与空 hooks）。恢复步骤在该文件与 `.cursor/hooks/*.bak`。

## Roles

| Role | Who | Cloud Agent behavior |
|------|-----|----------------------|
| PLAN / REVIEW | ChatGPT 网页（最高思考） | 若无网页桥：记 `chatgpt:unavailable` 并 **fail-open** 继续；禁止用 Codex 冒充 |
| WORK | `opencode-go/deepseek-v4.1-flash`（ds 4.1） | **不要**加 `--auto`（慢）。无 opencode 时 Cursor 自行实现，仍服从 PLAN/REVIEW |
| VERIFY | Cursor | 跑测、证据、PR；不替代 REVIEW 裁决 |

## Cursor Cloud specific instructions

1. **不要**再强制 `bash .cursor/grok/run.sh`（Grok 暂定 / auth 失效）。
2. PLAN：把任务写成简短 brief；能调 ChatGPT 桥则调，否则 `chatgpt:unavailable` 后自行做最小 PLAN 并标注。
3. WORK：用 ds 4.1，**不加** `--auto`：  
   `bash .cursor/opencode/run-ds41.sh "<task>"`  
   或 `opencode run -m opencode-go/deepseek-v4.1-flash "<task>"`
4. REVIEW：同样 fail-open；有 bridge 则送 diff+证据要 `approve|revise|block`。
5. Ambush / PaperRoute 游戏改动仍遵循 `.cursor/skills/paperroute-game-build/SKILL.md`。

## Auth

- `OPENCODE_API_KEY`（OpenCode Go）→ `~/.local/share/opencode/auth.json` 或 Dashboard Secret
- ChatGPT 网页桥在 Cloud 不可用时：`chatgpt:unavailable` fail-open
- 恢复 Grok：keeper Environment **Save** 后还原 `.cursor/hooks/*.bak`

## Restore Grok CLI later

```bash
cp .cursor/hooks/hooks.json.grok-forced.bak .cursor/hooks.json
cp .cursor/hooks/force-grok-cli.py.bak .cursor/hooks/force-grok-cli.py
cp .cursor/hooks/always-use-grok-cli.mdc.paused.bak .cursor/rules/always-use-grok-cli.mdc
```
