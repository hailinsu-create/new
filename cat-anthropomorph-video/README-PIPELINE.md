# 小猫拟人 · ComfyUI 管线 SOP（SFW）

- **项目**：真猫拟人二战卡点 MV（约 15s 竖屏，抖音/小红书）
- **目录**：本文件与全部脚本/工作流仅在 `cat-anthropomorph-video/`
- **隔离**：与 `ai-realistic-comic/` **物理隔离**——禁止引用、复制、链接其去衣/NSFW 工作流、LoRA、角色资产、提示词
- **算力**：默认 AutoDL **RTX 4090 24GB**；充值/开机/租卡均 **需用户授权**；本文档 **不** 声称已租卡、已充值、已开机
- **双机**：母机+克隆互斥同抢口径见 [`scripts/race_boot.md`](scripts/race_boot.md)（任意时刻只开一台，关机留盘）

规划日：2026-10-23（Asia/Shanghai）

---

## 默认管线（端到端）

```
真猫照
  → 定妆静帧（Qwen-Image-Edit-2511 多图；备选 Flux+HuMeow SFW LoRA）
  → OpenPose / Depth 竖屏首帧（构图锁，可选）
  → Wan2.1 I2V-14B-480P fp8（连击草稿段）
  → 高潮段 Wan2.1 FLF2V（首尾帧锁死）
  → 剪映：补帧/卡点对齐 + 导出 1080×1920@30fps
```

一猫一阵营：**A 美军** / **B 苏军** / **C 飞行员**；钢盔/帽 **露耳**；**少持枪**（旗、望远镜、奔跑、抬头优先）。

| 文件 | 阶段 |
| --- | --- |
| [`workflow/01_looklock_qwen_edit.json`](workflow/01_looklock_qwen_edit.json) | 定妆锁毛色（基于官方 Qwen-Image-Edit-2511 模板改编） |
| [`workflow/02_i2v_wan21_480p.json`](workflow/02_i2v_wan21_480p.json) | 图生视频草稿（Wan2.1 I2V 480P **fp8**） |
| [`workflow/03_flf2v_wan21.json`](workflow/03_flf2v_wan21.json) | 首尾帧高潮（Wan2.1 FLF2V **fp8**） |

权重清单：[`manifest.json`](manifest.json)。提示词：[`prompts/`](prompts/)。

---

## P0 · 无卡装环境（可离线准备）

1. 复制 [`env.example`](env.example) → `.env`（勿提交密钥）；填 `COMFYUI_ROOT`、`MODELS_ROOT`、`SPEND_CAP_CNY`。
2. 安装/更新 **ComfyUI 最新版**（需原生 Wan2.1 与 Qwen-Image-Edit-2511 模板/子图）。
3. 按 `manifest.json` → `custom_nodes` 补齐（ControlNet aux 等）；**不要**装 NSFW 专用节点。
4. `bash scripts/restore.sh`（默认 **dry-run**）核对 URL 与落盘路径。
5. 准备输入目录：`$INPUT_ROOT/cats/{A,B,C}/raw/`、`looklock/`、`$INPUT_ROOT/shots/`、`$OUTPUT_ROOT/{i2v,flf2v,exports}/`。

**完成标准**：三份 workflow 能在 ComfyUI 打开（缺权重视为节点标红可接受）；路径不指向 comic 树。

---

## P1 · I2V smoke（需用户授权开机）

1. 按 [`scripts/race_boot.md`](scripts/race_boot.md) **互斥**开机（母/克隆只开一台）。
2. `bash scripts/restore.sh --apply --group i2v`。
3. 打开 `workflow/02_i2v_wan21_480p.json`：任意竖屏图 → 负向用 [`prompts/negative.txt`](prompts/negative.txt)。
4. Smoke：`480×832`、`length≈33`、`steps≈20`；记录耗时与磁盘增量后 **关机留盘**。

**完成标准**：可播短视频；**未**声称量产。

---

## P2 · 定妆（Look-lock）

1. 填 [`prompts/look_cards.md`](prompts/look_cards.md)；仍为 [待补] 则停在文档态。
2. `bash scripts/restore.sh --apply --group looklock`。
3. 打开 `workflow/01_looklock_qwen_edit.json`：多图真猫参考 + 外观前缀 + [`prompts/positive_fragments.md`](prompts/positive_fragments.md) 露耳/少持枪片段。
4. 备选：Flux + HuMeow 等 **SFW** LoRA——manifest 仅列 Civitai 检索说明，**需人工确认许可**。
5. 每猫主装出正脸/侧面/3/4；盲测 ≥80%（见 `SERIES-WW2.md`）。

---

## P3 · 单段样片

1. 定妆/分镜首帧 → `02_i2v_wan21_480p.json`（连击可多段）。
2. 高潮首尾帧 → `03_flf2v_wan21.json`（720×1280 fp8）。
3. 剪映：按主曲 **120–140 BPM** 对齐；补帧 30fps；导出 **1080×1920**；标 AI。
4. 单条 GPU 硬上限约定约 **3h ≈ ¥6**（需用户授权）；对照系列发布检查清单。

---

## AutoDL 4090 实务

| 项 | 建议 |
| --- | --- |
| 磁盘 | I2V fp8 ≈15.3GiB + FLF2V ≈15.3GiB + umt5 ≈6.3GiB + 定妆 Qwen fp8mixed ≈19.1GiB 等；绑持久盘 |
| 互斥双机 | 见 `race_boot.md` |
| 花费帽 | `SPEND_CAP_CNY` 提醒 + 人工停机 |
| 隔离 | `COMFYUI_ROOT` / `MODELS_ROOT` 禁止指向 comic/NSFW 树 |

---

## 自定义节点补齐（若 JSON 标红）

| 用途 | 需补 |
| --- | --- |
| Wan I2V / FLF2V | 升级 ComfyUI；原生 `WanImageToVideo` / `WanFirstLastFrameToVideo` |
| Qwen-Image-Edit-2511 | 官方模板子图；缺子图时从 ComfyUI **Workflow Templates** 拉 `image_qwen_image_edit_2511` 再换本仓库提示词/输入 |
| OpenPose/Depth | `comfyui_controlnet_aux` |
| 视频保存 | 内置 `CreateVideo`/`SaveVideo`（本仓库已用）或 Video Helper Suite |

---

## 相关文档

- 题材系列：[`SERIES-WW2.md`](SERIES-WW2.md)
- 目录索引：[`README.md`](README.md)
