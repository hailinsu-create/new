# Cursor 静帧包 · v0.4 · 2026-10-28

> **用途**：B0-01 诺曼底 **H3 Phase6** 五镜 FL2VA 首末帧（**M04 / M05 / M08 / M09 / M10** · 各 start+end = **十张**）。
> **定妆锁**：延续 **looklock-v0.3.1**（semi-chibi ≈3.5 头身 · A 小橘）。
> **道具旗**：**同道具旗** — 五镜首末帧持同一面美国旗/旗杆语义，避免步枪↔旗瞬变。
> **来源口径**：Cursor GenerateImage 静帧包（docs 同步）；**非**漫监 NSFW；本窗**不执行** AutoDL 开机。
> **分支**：`cursor/cat-anthropomorph-comfy-pipeline-db82` · PR [#84](https://github.com/hailinsu-create/new/pull/84)。
> **边界**：仅 SFW；禁 grok.com CLI / 设备码；未触碰 `ai-realistic-comic/`；大二进制可留本机/机上，本文件为清单与闸门说明。

## §0 结论

1. **v0.4 静帧齐**：十张 M04/05/08/09/10 start+end 齐套，供 **H3 Phase6** 五镜 race。
2. **looklock-v0.3.1** 角色锁不变；本包只扩镜位与统一道具旗。
3. **同道具旗**：冲锋/爆破前后/插旗链路均持旗，禁止枪械入画作主道具。
4. **授权**：用户 **t97u** 已授权调试管线+开机；本 docs 窗只同步清单，不代跑开机脚本。

## §1 十张清单（M04/05/08/09/10 · start+end）

| # | 镜位 | 文件（约定相对本目录） | 用途 | 道具旗 |
| ---: | --- | --- | --- | --- |
| 1 | M04 | `boat_ramp/M04_boat_ramp_start.jpg` | 门落 **首帧** · 艇甲板扶栏蓄势 | 同道具旗可见或贴身可辨 |
| 2 | M04 | `boat_ramp/M04_boat_ramp_end.jpg` | 门落 **末帧** · 坡道入水落地 | 同道具旗 |
| 3 | M05 | `wade/M05_wade_start.jpg` | 涉水 **首帧** · 浪中前冲起势 | 同道具旗 |
| 4 | M05 | `wade/M05_wade_end.jpg` | 涉水 **末帧** · 近岸推进 | 同道具旗 |
| 5 | M08 | `charge/M08_charge_start.jpg` | 冲锋 **首帧** · 滩头起跑 | 同道具旗（**禁步枪主道具**） |
| 6 | M08 | `charge/M08_charge_end.jpg` | 冲锋 **末帧** · 冲刺峰值前 | 同道具旗 |
| 7 | M09 | `blast/M09_blast_start.jpg` | 爆破前 **首帧** · 掩护/蓄爆 | 同道具旗 |
| 8 | M09 | `blast/M09_blast_end.jpg` | 爆破后 **末帧** · 烟尘开路后持旗可读 | 同道具旗 |
| 9 | M10 | `flag/M10_flag_start.jpg` | 插旗 **首帧** · 双手握杆准备 | 同道具旗 |
| 10 | M10 | `flag/M10_flag_end.jpg` | 插旗 **末帧** · 高举到位 | 同道具旗 |

> 历史别名兼容：若本机仍用 `S04_*` / `S05_*` / `S08_*` / `S10_*` 文件名，语义等同上表 M 镜位；**M09** 为 Phase6 新增爆破镜，无 Phase4 旧名。

## §2 looklock-v0.3.1 锁项（继承）

| 锁项 | 要求 |
| --- | --- |
| 角色 | A **小橘**（橘白长毛拟人） |
| 体型 | semi-chibi ≈ **3.5 头身**（3–4） |
| 识别 | 钢盔**耳洞/露耳**、宽松军装圆肩 |
| 画幅 | 竖屏优先（720×1280 或 H3 入模 768×1344 前处理） |
| 负向 | 禁 NSFW / 去衣 / 未成年性化；禁细高条写实军人替换锁 |

对照：`outputs/cursor-stills-looklock-v0.3.1/`（若本仓仅有 docs 指针，以本机完整包为准）与 `reviews/COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md`。

## §3 供 H3 Phase6

| 项 | 钉死 |
| --- | --- |
| 阶段 | **H3 Phase6** · 五镜 race（M04+M05+M08+M09+M10） |
| 模板 | 本地 MiniMax H3 **FL2VA**（首末帧） |
| 双机 | 克隆003 / 母025 · race 谁抢到谁全干 · shutdown 留盘 |
| 前置余额 | 开跑前约 **39040** 分（见 `PROGRESS.md` t97u） |
| 产出期望 | 五段 mp4 + 日后 v0.4 拼装（本文件不声称已出片） |

## §4 人眼闸（进 Phase6 前）

- 十张均露耳、头身≈3.5、军装可读。
- **同道具旗**：M08↔M09↔M10 旗面/旗杆连续，无步枪主道具。
- 每对 start→end 位移意图可读（门落 / 涉水 / 冲刺 / 爆破开路 / 插旗）。
- 不合格先重出静帧，不带病帧进 GPU。

## §5 边界

- **禁** grok.com CLI / x.ai 设备码 / grok agent CLI。
- **不碰** 漫监 NSFW / `ai-realistic-comic/`。
- **本 docs 窗不执行** AutoDL 开机（开机由已授权执行器按 t97u 跑；此处只同步文档）。
- 大 jpg/mp4 **不强制入库**；清单与闸门以本 md 为准。

## 互链

- 进度：[`../../PROGRESS.md`](../../PROGRESS.md)（2026-10-28 t97u）
- 前序静帧短评：[`../../reviews/CURSOR-STILLS-2026-10-27.md`](../../reviews/CURSOR-STILLS-2026-10-27.md)
- H3 主路：[`../../reviews/LOCAL-H3-PLAN-v0.3-2026-10-27.md`](../../reviews/LOCAL-H3-PLAN-v0.3-2026-10-27.md)
- PR：[#84](https://github.com/hailinsu-create/new/pull/84)

