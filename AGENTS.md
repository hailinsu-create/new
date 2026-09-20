# AGENTS.md

## Active workflow (Grok CLI paused)

Cursor 编排 → ChatGPT 网页（最高思考）PLAN/REVIEW → opencode/ds4.1 WORK → Cursor 核验 → ChatGPT 再评。

- **Gate:** ChatGPT REVIEW `approve | revise | block` + Cursor 核验。`block` 必须停并告知用户。
- **不用** Jev / System One / `jev-decide` / Codex OAuth 冒充网页额度。
- **密钥**只用 Dashboard Secrets。

Grok.com CLI Extra High Fast 已按用户要求**暂定**（见 `.cursor/rules/always-use-grok-cli.mdc` 与空 hooks）。恢复步骤在该文件与 `.cursor/hooks/*.bak`。

## Roles

| Role | Who | Cloud Agent behavior |
|------|-----|----------------------|
| PLAN / REVIEW | ChatGPT 网页（最高思考） | 若无网页桥：记 `chatgpt:unavailable` 并 **fail-open** 继续；禁止用 Codex 冒充 |
| WORK | `opencode` + `opencode-go/deepseek-v4.1-flash`（`--variant max --auto`） | 若无 opencode/Go：Cloud Agent 自行实现，仍服从 PLAN/REVIEW |
| VERIFY | Cursor | 跑测、证据、PR；不替代 REVIEW 裁决 |

## Cursor Cloud specific instructions

1. **不要**再强制 `bash .cursor/grok/run.sh`（Grok 暂定 / auth 失效）。
2. PLAN：把任务写成简短 brief；能调 ChatGPT 桥则调，否则 `chatgpt:unavailable` 后自行做最小 PLAN 并标注。
3. WORK：优先  
   `opencode run --model opencode-go/deepseek-v4-flash --variant max --auto "<task>"`  
   （以本机 `opencode models` 实际 id 为准；旧称 ds4.1 / deepseek-v4.1-flash 等同 Flash 线。）
4. REVIEW：同样 fail-open；有 bridge 则送 diff+证据要 `approve|revise|block`。
5. Ambush / PaperRoute 游戏改动仍遵循 `.cursor/skills/paperroute-game-build/SKILL.md`。

## Auth the agent may request

- Dashboard Secret: `DEEPSEEK_API_KEY`（或 OpenCode Go 账号）→ 配置 `~/.config/opencode` / `opencode auth`
- 本机 Windows ChatGPT 网页桥不可用于此 VM；Cloud 一律 fail-open
- 恢复 Grok：keeper Environment **Save** 或 keeper 上 device-auth 后 Save

## Restore Grok CLI later

```bash
cp .cursor/hooks/hooks.json.grok-forced.bak .cursor/hooks.json
cp .cursor/hooks/force-grok-cli.py.bak .cursor/hooks/force-grok-cli.py
cp .cursor/hooks/always-use-grok-cli.mdc.paused.bak .cursor/rules/always-use-grok-cli.mdc
```
