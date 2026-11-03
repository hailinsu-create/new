# Cursor 静帧包 · 2026-10-27（t71u/t72u）

> **用途**：v0.3 定妆 / S04 / S10 首末帧候选；供下一窗口本地 H3 图生视频使用。  
> **来源**：**Cursor GenerateImage**（漫监老方案；t71u 出图、t72u 入库）。**非** AutoDL / Qwen looklock 产物。  
> **口径**：semi-chibi ≈ **3.5 头身**（目标 3–4 头身，军装可读）；对照 [`../../reviews/COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md`](../../reviews/COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md)。  
> **入库说明**：Cloud Agent `uploads/` 路径**未同步**，本包**自 bot-store attachments 入库**（`ATT=/cursor/stores/bot/grok-bot/agents/237da812-ff52-40d5-884e-dbae97b87d30/attachments`）。  
> **边界**：仅 SFW；未开机、未跑 GPU、未 merge；禁 grok CLI；未触碰 `ai-realistic-comic/` / NSFW。  
> **授权**：下一窗用这些首末帧跑本地 H3 **S04+S10 仍须用户授权开机**（见 [`../../reviews/LOCAL-H3-PLAN-v0.3-2026-10-27.md`](../../reviews/LOCAL-H3-PLAN-v0.3-2026-10-27.md)）。

## 入库清单（5 张）

| # | 目标文件 | 源 hash 文件（bot-store attachments） | 用途 | 尺寸 | 字节 | 源 sha256（= 目标 sha256） |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `portrait/looklock_portrait_semi_chibi_A.jpg` | `a442f873b4daed91e336228bc5fa935c9541499ac80fb3a33179a23e2afe37d0.jpg` | **比例锚** · 灰底全身定妆（A 小橘） | 720×1280 | 263438 | `a442f873b4daed91e336228bc5fa935c9541499ac80fb3a33179a23e2afe37d0` |
| 2 | `boat_ramp/S04_boat_ramp_start.jpg` | `c05653c9061bc6dbcc668c527c5d402499a3019ef476fd309ddfd3bedeaf77bf.jpg` | **S04 首帧** · 艇甲板扶栏（画面有 `START` 字样） | 720×1280 | 356818 | `c05653c9061bc6dbcc668c527c5d402499a3019ef476fd309ddfd3bedeaf77bf` |
| 3 | `boat_ramp/S04_boat_ramp_end.jpg` | `5573a2a4591963b7247a35ec6193c75b8bcb6022e2d3d2d60bf11927c752aa3b.jpg` | **S04 末帧** · 冲下坡道入水 | 720×1280 | 353898 | `5573a2a4591963b7247a35ec6193c75b8bcb6022e2d3d2d60bf11927c752aa3b` |
| 4 | `flag/S10_flag_start.jpg` | `9129a822890ad01ccfa122495764f9684dbb0d24032dc024fe80d4f6be3100ae.jpg` | **S10 首帧** · 双手握旗杆准备插旗 | 720×1280 | 344940 | `9129a822890ad01ccfa122495764f9684dbb0d24032dc024fe80d4f6be3100ae` |
| 5 | `flag/S10_flag_end.jpg` | `8d84f9a3fcd8129133a1da70345daae0cae6d5d684498912cce75b26a93ef7e9.jpg` | **S10 末帧** · 高举美国旗滩头 | 720×1280 | 359256 | `8d84f9a3fcd8129133a1da70345daae0cae6d5d684498912cce75b26a93ef7e9` |

**校验**：以上目标文件与源文件**逐字节一致**；sha256 即源 hash（`cp` 未转码）。

## 用途与门禁

| 用途 | 怎么用 | 验收 |
| --- | --- | --- |
| 比例锚 | 作为 A 小橘 semi-chibi 全身基准；派生 S04/S10 时保持头身比、耳洞、军装松量 | 人眼闸：3–4 头身、耳洞干净、军装可读 |
| S04 首/末 | 本地 H3 **FL2VA** 首尾帧，跑门落坡道入水 | 人眼可见门落/入水位移，非静帧 |
| S10 首/末 | 本地 H3 **FL2VA** 首尾帧，跑准备插旗→高举 | 人眼可见插旗动作成立 |

- **不默认开机**：本包只是静帧入库；GPU 侧 H3 试点须用户明确授权。
- **不靠 H3 风格 LoRA 改比例**：可爱/头身比在静帧解决；H3 只负责运动。
- **不碰**：NSFW / 去衣 / `ai-realistic-comic/`；禁 grok CLI。

## 互链

- 短评：[`../../reviews/CURSOR-STILLS-2026-10-27.md`](../../reviews/CURSOR-STILLS-2026-10-27.md)
- 比例社区检索：[`../../reviews/COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md`](../../reviews/COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md)
- H3 方案：[`../../reviews/LOCAL-H3-PLAN-v0.3-2026-10-27.md`](../../reviews/LOCAL-H3-PLAN-v0.3-2026-10-27.md)
- 进度：[`../../PROGRESS.md`](../../PROGRESS.md) 段34
- PR：[#84](https://github.com/hailinsu-create/new/pull/84) · 分支 `cursor/cat-anthropomorph-comfy-pipeline-db82`
