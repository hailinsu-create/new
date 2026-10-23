# 小猫拟人 · 工作进度日志

> **约定（用户）**：每完成一段工作，同步写入 **GitHub**（本文件 + 必要代码/文档 commit/PR）与 **Notion**（题材页子页或追加）。

## 2026-10-23 17:03 Asia/Shanghai · 段1：ComfyUI 管线骨架落地

- **GitHub**：PR [#84](https://github.com/hailinsu-create/new/pull/84) · 分支 `cursor/cat-anthropomorph-comfy-pipeline-db82`
- **内容**：`README-PIPELINE.md`（P0–P3）、`workflow/`×3、`manifest.json`、`scripts/`、`prompts/`；与 `ai-realistic-comic/` 隔离；未声称租卡/充值/开机
- **Notion**：https://app.notion.com/p/402b407a692a813c95dfe8301f82573f

## 2026-10-23 17:03 Asia/Shanghai · 段2：社区方案调研 + 定妆路径结论

- **结论**：定妆主路径仍为 **Qwen-Image-Edit-2511 多图真猫参考**；Cursor 生图仅适合 mood 探索，**不能**当锁定包
- **视频**：仓库 Wan2.1 I2V+FLF2V 仍可用；社区倾向后续可试 **Wan2.2 I2V** 升级
- **文档**：见 `README-PIPELINE.md`「定妆分工」与「社区口径」小节

## 2026-10-24 Asia/Shanghai · 段3：双机实体 + 三猫定妆锁定 + 离线验收

- **双机实体**：母-Comfy定妆 **025机** `9b4c40bda6-dad38bb9` / 克隆-Wan **003机** `bb8c4f8e12-00c8bdac`（重庆A · RTX 4090D · 扩盘 100G · shutdown 留盘）；任意时刻只开一台；余额约 ¥17.25、未充值；开机需用户授权
- **三猫定妆锁定**：A **小橘**（橘白长毛）/ B **银宝**（银虎斑折耳）/ C **墨墨**（全黑折耳）；英文固定前缀锁毛色瞳色、露耳、少持枪，见 `prompts/look_cards.md`
- **管线对齐**：`scripts/restore.sh` 默认 dry-run，支持 `--apply` / `--group looklock|i2v|flf2v`；三份 workflow 的 UNET/CLIP/VAE/LoRA 与 `manifest.json`（4090 fp8）对齐；新增 `scripts/smoke_test.sh`
- **离线验收**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**（仅 dry-run；未开机真跑 GPU）
- **Notion**：https://app.notion.com/p/402b407a692a813c95dfe8301f82573f
- **边界**：禁止 grok CLI / 设备码；未触碰 `ai-realistic-comic/` 或任何 NSFW；未声称开机/计费试跑

## 2026-10-24 Asia/Shanghai · 段4：附件入库尝试 + CHARACTER-LOCK / refs/cats 落地

- **附件入库尝试**：按用户所列 `CHARACTER-LOCK-2026-10-24_64b7.md`、三张猫图、`DUAL-CREATE-RESULT-2026-10-24_d231.md` 全盘搜索（`/workspace` 与 `find / -xdev`），均**未找到**；未伪造、生成或下载猫照片
- **权威锁定**：由 `prompts/look_cards.md` + 用户权威字段重建 [`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md)：A 小橘 / B 银宝 / C 墨墨 角色表、三套固定英文前缀、`refs/cats/` 路径、双机 ID、SFW 隔离，并与 look_cards / refs / DUAL / 管线文档互链
- **参考图目录**：建立 `refs/cats/{A,B,C}/` + `README.md` + `.gitkeep`；三张 jpg **待重传**，记录于 [`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)
- **双机对齐**：`DUAL-CREATE-RESULT-2026-10-24.md` 对齐母 `9b4c40bda6-dad38bb9` / 克隆 `bb8c4f8e12-00c8bdac`，补链 CHARACTER-LOCK 与 refs/cats；`scripts/race_boot.md`、`README-PIPELINE.md`、`prompts/look_cards.md`、`SERIES-WW2.md`、`README.md` 引用同步
- **restore**：`mkdir` 增加 `refs/cats/{A,B,C}`；存在 `front.jpg` / `cat-*.jpg` 时**硬拷贝**到 `$INPUT_ROOT/cats/{cat}/raw/`，目标已存在则跳过；`ai-realistic-comic/` 路径仍拒绝
- **smoke**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**；三张 jpg 均缺失时打印 `[smoke][WARN] 参考图待重传`，文档锁定仍通过
- Notion 进度页已由本轮 Cursor 追加段5（CHARACTER-LOCK + refs/cats；jpg 待重传）。
- **边界**：未开机、未跑 GPU、未计费；禁止 grok；未触碰 `ai-realistic-comic/` 或任何 NSFW

## 约定落库

- Notion Memory：[工作同步：GitHub + Notion](https://app.notion.com/p/402b407a692a81ecb2ddcd6b35b29320)
