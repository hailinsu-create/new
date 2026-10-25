# 小猫拟人短视频 · 题材与管线文档

本目录归属「小猫拟人」短视频 Bot，存放题材系列与后续管线说明。

- 主文档：`SERIES-WW2.md`（二战卡点 MV 题材系列）
- **权威定妆锁定**：[`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md)（角色表 / 固定前缀 / 双机 ID / SFW 隔离）
- **参考图入口**：[`refs/cats/`](refs/cats/)（三张实拍 jpg 已入库，见 [`MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)）
- **ComfyUI 管线 SOP**：[`README-PIPELINE.md`](README-PIPELINE.md)（P0–P3、workflow/、manifest、双机互斥；Wan2.1 **fp16 默认**）
- **社区修正（2026-10-24）**：[`COMMUNITY-FIXES-2026-10-24.md`](COMMUNITY-FIXES-2026-10-24.md)（fp16 默认、禁 SageAttention、噪声门禁）
- **动作修正（2026-10-25）**：[`reviews/COMMUNITY-I2V-MOTION-2026-10-25.md`](reviews/COMMUNITY-I2V-MOTION-2026-10-25.md)（length=49、强动词、G2m）
- **社区优化（2026-10-25）**：[`reviews/COMMUNITY-OPTIMIZE-2026-10-25.md`](reviews/COMMUNITY-OPTIMIZE-2026-10-25.md)（Wan/Qwen/SSIM/BGM）；门禁与三态见 [`reviews/CLIP-STATUS.md`](reviews/CLIP-STATUS.md)
- **一键装配**：[`scripts/assemble_clip.py`](scripts/assemble_clip.py) · [`scripts/ASSEMBLE.md`](scripts/ASSEMBLE.md)（RENDER_DONE → G1/G2/G2m → AUTO_QC_PASS → candidates.jsonl；`--human` 才可用）
- **G2 校准**：[`reviews/SUBJECT-GATE-CALIBRATION.md`](reviews/SUBJECT-GATE-CALIBRATION.md)（SSIM 带宽 0.25–0.92；fixtures 与中心区读法）
- **有声/换轨**：[`scripts/stitch_audio.py`](scripts/stitch_audio.py) · [`scripts/AUDIO-SWAP.md`](scripts/AUDIO-SWAP.md)；QC 合成小样 [`fixtures/qc/`](fixtures/qc/)
- **Comfy 模板复用**：[`workflow/TEMPLATES.md`](workflow/TEMPLATES.md)（I2V 方案 A / looklock 填槽）
- **¥0 预备（B0-01）**：`reviews/BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md` · `STORYBOARD-…` · `MOTION-GATE-CALIBRATION.md` · `BOOT-AUTH-ASK-2026-10-25.md`
- **下次开机验证**：[`NEXT-BOOT-CHECKLIST.md`](NEXT-BOOT-CHECKLIST.md)
- **进度日志**：[`PROGRESS.md`](PROGRESS.md)（每段工作同步 GitHub + Notion）
- 修订说明：见 `SERIES-WW2.md` 文末变更记录（2026-10-23 Opus 5.5 Max 审核 v2：合并重排、一猫一阵营、定妆锁定包）
- **严禁**存放或引用漫画去衣 / NSFW 工作流与角色资产（与 `ai-realistic-comic` 隔离）

规划日：2026-10-23（Asia/Shanghai）
