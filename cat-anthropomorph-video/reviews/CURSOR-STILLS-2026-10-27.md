# Cursor 静帧包短评 · 2026-10-27（t71u/t72u）

> 用户 **t72u**：Cursor GenerateImage 出静帧并入库。  
> 分支 `cursor/cat-anthropomorph-comfy-pipeline-db82` · PR [#84](https://github.com/hailinsu-create/new/pull/84)。  
> 入库目录：[`../outputs/cursor-stills-2026-10-27/`](../outputs/cursor-stills-2026-10-27/)（清单见 [`MANIFEST.md`](../outputs/cursor-stills-2026-10-27/MANIFEST.md)）。  
> **边界**：未开机、未跑 GPU、未 merge；禁 grok CLI；未碰 `ai-realistic-comic/` 或任何 NSFW。

## §0 结论

1. **定妆静帧默认改走 Cursor GenerateImage（漫监老方案）**；不再默认开机跑 AutoDL Qwen looklock。Qwen looklock 保留为**可选对照**，历史 workflow / 文档不删。
2. **目标体型 = semi-chibi ≈ 3.5 头身**（3–4 头身区间）；继续对齐 [`COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md`](COMMUNITY-CUTE-PROPORTIONS-2026-10-27.md) 的「可爱靠首帧、不靠 H3 风格 LoRA」结论。
3. 本包 5 张 720×1280 静帧已**逐字节入库**（源 sha256 见 MANIFEST）；Cloud Agent `uploads/` 未同步，实际**自 bot-store attachments 入库**。
4. 下一窗用这些首末帧跑**本地 H3 S04+S10**，**仍须用户明确授权开机**；本包本身 ¥0、未动 GPU。

## §1 五张用途

| 文件 | 用途 | 观察 |
| --- | --- | --- |
| `portrait/looklock_portrait_semi_chibi_A.jpg` | **比例锚** · 灰底全身定妆 | A 小橘全套军装、钢盔露耳、红围巾；全身完整入画，可量头身比 |
| `boat_ramp/S04_boat_ramp_start.jpg` | **S04 首帧** · 艇甲板扶栏 | 双手扶梯、甲板水花、左侧可见 `START` 字样；首帧动作意图明确 |
| `boat_ramp/S04_boat_ramp_end.jpg` | **S04 末帧** · 冲下坡道入水 | 身体前冲、坡道没入海浪；与首帧构成门落/入水位移 |
| `flag/S10_flag_start.jpg` | **S10 首帧** · 双手握旗杆准备插旗 | 旗杆落地、双手握杆、滩头黄昏；准备发力姿态可读 |
| `flag/S10_flag_end.jpg` | **S10 末帧** · 高举美国旗滩头 | 单臂高举、旗帜展开、滩头背景；与首帧构成插旗动作 |

> 首末帧配对直接服务 v0.3 的 **H3 FL2VA**；比例锚用于检查 S04/S10 是否继续走「细高条」。

## §2 对照 COMMUNITY-CUTE-PROPORTIONS

| 社区结论 | 本包回应 | 仍需人眼闸 |
| --- | --- | --- |
| 可爱/体型是**首帧产品** | 静帧改由 Cursor GenerateImage 直出，先锁 semi-chibi 全身 | 逐张量 3–4 头身 |
| 目标 **≈3.5 头身** | 比例锚按此目标选片；S04/S10 沿用同一角色比例 | 头身比、四肢厚度、脸圆度 |
| 钢盔**耳洞/耳形**是猫感第一识别点 | 5 张均露耳、钢盔有耳洞 | 耳内粉色与耳形是否干净 |
| 军装要**宽松圆肩**、少持枪 | 夹克宽松、空手/持旗，无枪械 | 肩线、袖口、收腰 |
| **不靠 H3 LoRA 救细高条** | 先入库静帧，再谈 H3 运动；不在 I2V 侧硬拉比例 | — |
| **先首帧闸，再烧 GPU** | 本包未开机；人眼闸通过后才申请 H3 授权 | — |

## §3 下一步（须授权）

- **下一窗**：用 `boat_ramp/S04_*` 与 `flag/S10_*` 作首末帧，跑本地 **H3 S04+S10**（FL2VA / I2V），验收「门落 / 插旗」人眼可见。
- **前置**：用户**明确授权开机**（AutoDL 一台、软顶另核）；未授权不动 GPU、不下载权重。
- **落选处理**：若人眼闸认为比例或耳洞不达标，先在 Cursor 侧重出静帧，不带着不合格首帧进 H3。
- **文档联动**：[`LOCAL-H3-PLAN-v0.3-2026-10-27.md`](LOCAL-H3-PLAN-v0.3-2026-10-27.md) 已加「静帧默认 Cursor」旁注；[`../PROGRESS.md`](../PROGRESS.md) 段34 记录本包就绪。

## §4 边界

- **未开机**、未跑 GPU、未计费、未下载大权重、未 release 实例。
- **禁 grok / grok.com CLI**；未索要设备码。
- **未碰** `ai-realistic-comic/`；**未碰 NSFW / 去衣 / 未成年性化**。
- 未 merge、未 force-push；仅向 PR #84 同分支追加文档与静帧。
