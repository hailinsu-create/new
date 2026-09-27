# Ambush Loop 项目 — 交接文档（Cursor 云 Agent 停摆交接）

> 交接背景：Cursor 云会话「项目agent成果状态」（`bc-9ba1f0a1-96b9-4897-a799-897820830641`）额度用尽，停在 R44–R53 十轮计划的**中途**（R44 已提交，R45–R53 未提交）。本文件供接手 AI / 工具（opencode、WorkBuddy、新 Cursor 会话等）继续开发。
> 文档日期：2026-09-27。依据：GitHub 仓库 `hailinsu-create/new` 分支现状 + 仓库内 `.cursor/docs/` 与 `ambush_loop/docs/` 全部关键文档。
> 阅读顺序：本文件 → 仓库根 `AGENTS.md` → `.cursor/skills/paperroute-game-build/SKILL.md` → `.cursor/docs/AMBUSH_10_ROUNDS_R44.md` → `ambush_loop/docs/LAUNCH_BAR.md`。

---

## 1. 项目定位

- **Ambush Loop**：Godot **4.7.2** 2D 竖切（vertical slice），Commandos 风格夜袭战术小品——**侦察 → 搜刮 → 布置埋伏 → 拉警报多波 → 打扫 → 撤离**，共 6 夜（院子 / 仓道 / 泵站 / 信号楼 `railcut` / 油库 `depot` / 电台 `radio`）。
- 首发目标：**安卓 APK 侧载（朋友包）**，不是正式版。像素门槛加权 **9.0**，功能条自评 **7.7**（`docs/LAUNCH_BAR.md`）；**禁止对外写 9.5 / 正式版**。
- 仓库：`https://github.com/hailinsu-create/new`（public）。游戏在 **`ambush_loop/`** 目录。
- ⚠️ 该仓库还混放其它项目分支（旁窗 Live2D、mast 投资简报、omi、小说等），**不要串线、不要动其它目录**。
- 本地克隆：`C:\Users\23170\Desktop\new`（当前停在旁窗分支 `cursor/phone-roast-small-window-b0b5`；动游戏前先 `git fetch` 再切分支）。

---

## 2. 分支与 PR 现状（成果地图）

`main` 只有 travel 简报 + 早期合并（PR #4，2026-09-11），**游戏最新代码不在 main**。成果按分支/PR 分布：

| 分支 | 内容 | 版本 | PR |
|---|---|---|---|
| `cursor/commandos-ambush-0641` | R01–R20 十轮（0.6.0→0.6.11） | 0.6.11 / code 60 | （已并入早期 PR #4 线路） |
| `cursor/ambush-oil-drum-r21-0641` | R21–R33（含油桶、木桶、电台等 Look） | 0.6.13 → 0.6.20 | #61 Draft |
| `cursor/ambush-r34-ten-0641` | R34–R43 十轮 | **0.6.27 / 76** | #63 Draft |
| `cursor/ambush-play-r44-0641` | **R44 已完成**（R44–R53 十轮计划载体） | **0.6.28 / 77** | **#64 Draft** |

- **云会话挂靠分支**是 `cursor/ambush-oil-drum-r21-0641`（聊天 scope），但实际推进用上面后续分支。
- 仓库内三份「十轮表」+ 一份计划表是成果台账：
  - `.cursor/docs/AMBUSH_20_ROUNDS.md`（R01–R20，0.6.11）
  - `.cursor/docs/AMBUSH_10_ROUNDS_R23.md`（R23–R32，0.6.19）
  - `.cursor/docs/AMBUSH_10_ROUNDS_R34.md`（R34–R43，0.6.27）
  - `.cursor/docs/AMBUSH_10_ROUNDS_R44.md`（**R44–R53 计划 + 可执行验收标准 + ChatGPT 批注**）

---

## 3. 云会话停点（2026-09-21 15:01 UTC）

本地 Cursor 缓存（`conversation-search.db`）里该会话最后几条：

- “Cleaning the R53 phase gate and aligning R46–R47 version metadata while smoke finishes.”
- “Smoke for R46–R47 is still running; I'll inspect the mid-edits and assert coverage while it finishes.”
- “I'll pick up mid-pipeline: check smoke status and the R48–R53 edits, then drive the remaining play rounds through verify and review.”
- “Implementing R48–R53 while R46–R47 smoke runs.”

**结论**：R44 已 commit（`fix(play): R44 assert one-shot 0.18s CTA pulse`）；**R45–R53 只存在于云端未推送状态，极可能已随额度中断丢失**——按第 5 节计划表**重做**即可，不要去找残稿。
云端证据（PR 里的 `cursor.com/agents/.../artifacts/...` 链接）可能已失效；重要证据已部分进仓：`ambush_loop/docs/eval_0de4f1d/`、`eval_71ca4af/`（含 `EAR_LISTEN.md`、`PIXEL_VERDICT.md`、`STRANGER_FIRST.md`、`cues/*.wav`）。

---

## 4. 已达成成果（摘要）

- **玩法**：六夜可玩 + 标题/选关/简报/教学/Esc 设置/终局摘要/战役档案/致谢，全部可跑；headless 冒烟全绿（约 126s）。
- **APK 里程碑**（`ambush_loop/dist/`）：`v0.6.3-alert-chrome` / `v0.6.5-gun-case` / `v0.6.8-loot-chip` / `v0.6.11-yard-props`（最新侧载包，release tag `v0.6.11-yard-props`）。
- **Look 资产**（`ambush_loop/ArtSource/`，每个 = `build_<asset>.py` + GLB + turnaround/iso 接触纸）：枪匣、沙袋、灯柱、篱笆、口粮箱、木桶、野战电台、油桶、备胎、手推车、铁丝网圈等。
- **R21–R44 逐轮明细**：见第 2 节四份十轮表（每轮都注明版本、REVIEW=approve、冒烟结果）。
- 当前分支代码版本：`project.godot` = **0.6.28**（versionCode 77）。

---

## 5. 待办：R45–R53（照表执行，逐轮独立 commit）

来源：`.cursor/docs/AMBUSH_10_ROUNDS_R44.md`（含 ChatGPT REVIEW 批注：R44 pulse 改 0.18s、R52 改 0.18s、R50 禁止新增 route schema）。

| 轮 | 切片 | 可执行验收 | 版本 |
|---|---|---|---|
| R45 | SWEEP 首次进入显示 ≤16 字动作教学（如 `搜尸 · 准备下一波`） | Smoke 断言文案存在且 Unicode len≤16；离开 SWEEP 不残留 | 0.6.29 / 78 |
| R46 | 跟 portrait badge 可点击 rect 四边各 +4px（视觉不放大） | Smoke 比较 visual vs hit rect；不覆盖枪械切换/数字槽 | 0.6.30 / 79 |
| R47 | 绕背 hotspot 扩到约 88×42（只扩 hit area） | Smoke assert hit rect≥88×42；世界触发距离/目的地算法不变 | 0.6.31 / 80 |
| R48 | 开匣站定 0.4s 期间显示世界态 `开匣中…`，成功/离开/打断立即消失 | Smoke 覆盖 enter→progress→open 与 enter→leave→cancel | 0.6.32 / 81 |
| R49 | knives-only 拉警报先给 `漏网预警` | Smoke：无枪时出现、有枪不出现；不改 alarm gating/leak 判定 | 0.6.33 / 82 |
| R50 | ALERT wave chip 增强边框 + 已有 route name 时附路线名 | 有 route→显示；无 route→回退原 chip；禁止新增 schema | 0.6.34 / 83 |
| R51 | West follow-file ghost Line2D alpha +0.08 | Smoke assert 新 alpha 且≤1；destination/span/settle 不变 | 0.6.35 / 84 |
| R52 | long-press 跑触发瞬间显示约 0.18s `跑` mote（一次性） | 短按不出现；跨阈值只触发一次；不改 run threshold/speed | 0.6.36 / 85 |
| R53 | SWEEP 内靠近可搜 corpse 出现 `搜尸` context hotspot | 仅 SWEEP+范围内显示；沿用现有 corpse loot，不新增掉落逻辑 | 0.6.37 / 86 |

**优先级**：R45/R48/R53（首局卡顿收益最高）→ R46/R47（手机容错）→ R49（失败前反馈）→ R50–R52（二层可读性）。

**R44–R53 之后的路线**（`ambush_loop/docs/Ambush_Loop_下一步开发规划.md`）：
- **P0**：重截 31 张窗口 dump（新目录）+ 至少 1 次陌生人第一局 → 把自评 ~9.0 变成像素分；
- **P1**：耳听闸门（`cues/*.wav`）+ 剪影辨识；
- **P2**：六夜内部手感/文案（不扩系统、不加第 7 夜）；
- **P3**：本机导真机 APK + 包装；**合 main 放在清单全勾之后**（PR 保持 Draft）。

**LAUNCH_BAR 明确延期项**：FOW、真人平衡记录、sprite 管线、真 VO、商店发布（Play AAB）、本地化管线。

---

## 6. 每轮工作流（PaperRoute 循环，必须遵守）

1. **一轮 = 一个切片**：Engine **或** Look，只改一件可玩/可看的事，独立 commit（Engine/Look 不混 commit）。
2. **闸门管线**：ChatGPT 网页（最高思考）**PLAN** → ds4.1 **WORK** → Cursor **VERIFY**（冒烟/证据）→ ChatGPT **REVIEW**（`approve|revise|block`，block 必停并告知用户）。
3. **Engine 轮**：`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd`，须打印 `SMOKE_SLICE_COMPLETE` 并 exit 0；关键轮跑 force-touch dump。Engine 里程碑 bump `versionName 0.6.x` / `versionCode +1`。
4. **Look 轮**：`blender-headless --python ambush_loop/ArtSource/build_<asset>.py` → GLB + 接触纸（front/side/rear，clay+shaded）；先做 art study，**进院子另开一轮**。不 bump 版本。
5. **指向一帧**，不写「看起来好一点」；没有图片证据不算过。
6. 合入门槛 = `SMOKE_SLICE_COMPLETE`；PR 保持 Draft。

**云 VM 命令**（原环境）：
```bash
bash .cursor/chatgpt/chatgpt-web.sh -Mode plan|review -RequestFile <f> -OutFile <out>
bash .cursor/opencode/run-ds41.sh "<task>"      # opencode-go/deepseek-v4.1-flash --variant max，禁止 --auto
bash .cursor/chatgpt/status.sh                   # 桥接可用性；unavailable 就 fail-open 标注，不得伪造
```
**本机 Windows 等效**（`~/.cursor/scripts/chatgpt-web.ps1 -Mode plan|review -RequestFile <f> -Workspace <ws>`；opencode CLI 直接可用，本机惯例 `opencode run -m opencode-go/deepseek-v4.1-flash --variant max --auto`）。
**纪律**：Grok CLI 已暂停（勿调 `.cursor/grok/run.sh`）；禁用 Jev/System One；不得用 Codex OAuth 冒充网页额度；密钥只走 Dashboard Secrets，**任何 key 不进仓库**。

---

## 7. 环境与工具链

| 环境 | 现状 |
|---|---|
| 云端 VM（原） | Godot **4.7.2**（`/usr/local/bin/godot`）、Blender **5.2.2 LTS**（`blender-headless`）、`gltf-transform`、`meshy`（**无 MESHY_API_KEY**，人脸资产暂缓）、opencode CLI |
| 本机 Windows（2026-09-27 核查） | **未装 godot / blender**（PATH 与常见目录均无）→ 继续开发需先装 Godot 4.7.2（标准版，非 .NET）；Look 轮需 Blender。Android SDK 在 `C:\Users\23170\Desktop\new\.tools\android-sdk`（旁窗项目装的，可复用导 APK） |
| 本机已有 | opencode CLI（本会话即 opencode）、Python/Node 等见其它交接文档；`~/.cursor/scripts/chatgpt-web.ps1` 桥接脚本 |

**关键文件体积（并行约束）**：`scripts/main.gd` 6887 行（**多 agent 最大撞车点**，同一时刻只许一个 agent 改）；`scripts/smoke_test.gd` 4182 行（回归网，改契约必须同步改它）；`map_draw.gd` 1270；`level/level_def.gd` 755；`sfx/sfx_bus.gd` 733。

---

## 8. 硬约束（口径，不得违反）

- **RAID 契约**：`SCOUT → ALERT → SWEEP`；ALERT 锁走位；自动火力/手雷；10 枪 kit（`docs/COMMANDOS_RAID.md`、`COMMANDOS2_KIT.md`）。alarm 冻结计划、无 mid-fight 微操、作者路线、逃逸/全灭失败、情报+计划跨世。
- **数值锁**：west dest `(6,6)/(5,16)`、`span==6` 不动；body≥1.0；west zoom≥0.85；obs fill 可淡但不得靠缩 body 遮盖。
- **不扩系统**：不加第 7 夜、FOW、sprite 管线；不拆 `combat_sim.gd`/外置 `.tres`（除非撞车被迫，且带既有冒烟门）。
- **不混项目**：旁窗/Live2D/墨汐不进 `ambush_loop/`。
- **不写正式版口径**：朋友包文案=「程序多边形 + 合成音的夜间战术小品」。
- `build/` 已 gitignore；APK 只在里程碑打（历史节奏：R05/R10/R15/R20）。

---

## 9. 接手第一步（建议顺序）

1. `git fetch origin` → `git checkout cursor/ambush-play-r44-0641`（本机克隆 `C:\Users\23170\Desktop\new`；注意现有未跟踪的 `.tools/`、`android/android/` 是旁窗产物，别删）。
2. 通读：`AGENTS.md` → `.cursor/skills/paperroute-game-build/SKILL.md` → `.cursor/docs/AMBUSH_10_ROUNDS_R44.md` → `ambush_loop/README.md`。
3. 装 Godot 4.7.2，跑一次冒烟确认基线：`godot --headless --path ambush_loop -s res://scripts/smoke_test.gd`（应见 `SMOKE_SLICE_COMPLETE` / `SMOKE_OK_RAID_LOOP`，exit 0）。
4. 从 **R45** 起按第 5 节表逐轮做（每轮独立 commit，更新 PR #64）。
5. 全部做完后走 P0（重截 dump + 陌生人第一局）再谈合 main。

---

## 10. 对话与来源

- 主云会话：Cursor 云 Agent「项目agent成果状态」，ID `bc-9ba1f0a1-96b9-4897-a799-897820830641`（scope `cursor/ambush-oil-drum-r21-0641`），最后活动 2026-09-21 15:01 UTC；打开：`cursor.com/agents/bc-9ba1f0a1-96b9-4897-a799-897820830641`。
- 相关会话（同仓库）：「Ambush 最新版覆盖」「Ambush 合并状态」「游戏进度复核」（9/11）、「Agent grok fast模式」（9/18）等。
- 本地缓存：`%APPDATA%\Cursor\User\globalStorage\conversation-search.db`（**只有摘要**，全文在 cursor.com，额度断后建议尽快导出）。
- 本交接文档由 opencode 于 2026-09-27 依据 `hailinsu-create/new` 分支/PR/文档现状整理，已提交进本分支（`.cursor/docs/AMBUSH_HANDOVER_20260927.md`，随 PR #64），供后续接手者直接阅读。

---

*接手第一步建议：先装 Godot 4.7.2 并冒烟确认基线，然后直接从 R45 开始；R45–R53 的验收标准已全部写在 `.cursor/docs/AMBUSH_10_ROUNDS_R44.md`，照表执行即可。*
