# 小猫拟人 · ComfyUI 管线 SOP（SFW）

- **项目**：真猫拟人二战卡点 MV（约 15s 竖屏，抖音/小红书）
- **目录**：本文件与全部脚本/工作流仅在 `cat-anthropomorph-video/`
- **隔离**：与 `ai-realistic-comic/` **物理隔离**——禁止引用、复制、链接其去衣/NSFW 工作流、LoRA、角色资产、提示词
- **算力**：默认 AutoDL **RTX 4090 24GB**；充值/开机/租卡均 **需用户授权**；本文档 **不** 声称已租卡、已充值、已开机
- **双机**：母 **025机** `9b4c40bda6-dad38bb9` / 克隆 **003机** `bb8c4f8e12-00c8bdac`（重庆A · RTX 4090D · 扩盘 100G · shutdown 留盘）；双机 race、任意时刻只开一台；I2V 优先母 025，**克隆 003 可代跑 I2V**，looklock 优先克隆 003；口径见 [`scripts/race_boot.md`](scripts/race_boot.md)。余额只以控制台为准、不充值、开机需用户授权
- **定妆锁定**：[`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md)（权威角色表 / 固定前缀 / 双机 ID）；参考图入口 [`refs/cats/`](refs/cats/)，三张 jpg 已入库（首选名 + `front.jpg` 共六张）
- **离线验收**：`bash scripts/smoke_test.sh --dry-run`（默认 dry-run，exit 0 为通过；含 `assemble_clip.py --self-test`）；本仓库仍 **未开机真跑 GPU**
- **2026-10-24 社区修正**：[`COMMUNITY-FIXES-2026-10-24.md`](COMMUNITY-FIXES-2026-10-24.md)（fp16 默认、禁 SageAttention、噪声门禁）
- **2026-10-25 模板化**：[`workflow/TEMPLATES.md`](workflow/TEMPLATES.md) — I2V 方案 A / Qwen looklock 可复用；每镜只改槽位，勿另起 workflow
- **v0.1b / v0-lite 装配**：先用离线 `assemble_clip.py` 把 R1/R2/R4 现有片段过 G1/G2/G2m 并进 `candidates.jsonl`；15s 样片路径记在 **briefs / 本机 outputs**；**二进制 mp4 可不入库**（见 beat/storyboard；R4 场景漂移偏弱）
- **2026-10-25 动作修正**：[`reviews/COMMUNITY-I2V-MOTION-2026-10-25.md`](reviews/COMMUNITY-I2V-MOTION-2026-10-25.md)（强动词 + static 负向 + length=49 + **G2m motion_gate**）；下次开机按 [`NEXT-BOOT-CHECKLIST.md`](NEXT-BOOT-CHECKLIST.md) 验证
- **2026-10-25 社区优化**：[`reviews/COMMUNITY-OPTIMIZE-2026-10-25.md`](reviews/COMMUNITY-OPTIMIZE-2026-10-25.md)（Wan/Qwen/SSIM/BGM 四节 + 推荐默认）；门禁状态见 [`reviews/CLIP-STATUS.md`](reviews/CLIP-STATUS.md)；G2 校准见 [`reviews/SUBJECT-GATE-CALIBRATION.md`](reviews/SUBJECT-GATE-CALIBRATION.md)
- **一键装配**：[`scripts/assemble_clip.py`](scripts/assemble_clip.py) · [`scripts/ASSEMBLE.md`](scripts/ASSEMBLE.md)（RENDER_DONE → G1/G2/G2m → AUTO_QC_PASS → candidates.jsonl；`--human` 才可用）

规划日：2026-10-23（Asia/Shanghai）

---

## 默认管线（端到端）

```
真猫照
  → 定妆静帧（Qwen-Image-Edit-2511 多图；备选 Flux+HuMeow SFW LoRA）
  → OpenPose / Depth 竖屏首帧（构图锁，可选）
  → Wan2.1 I2V-14B-480P fp16（连击草稿段；fp8 仅 VRAM 回退，易噪）
  → 高潮段 Wan2.1 FLF2V（首尾帧锁死）
  → 剪映：补帧/卡点对齐 + 导出 1080×1920@30fps
```

一猫一阵营：**A 美军** / **B 苏军** / **C 飞行员**；钢盔/帽 **露耳**；**少持枪**（旗、望远镜、奔跑、抬头优先）。

| 文件 | 阶段 |
| --- | --- |
| [`workflow/01_looklock_qwen_edit.json`](workflow/01_looklock_qwen_edit.json) | **定妆图形模板**（Qwen-Image-Edit-2511）；槽位见 [`01_looklock_api_slots.json`](workflow/01_looklock_api_slots.json) |
| [`workflow/02_i2v_wan21_480p.json`](workflow/02_i2v_wan21_480p.json) | **I2V 方案 A 图形模板**（fp16 · length49）；槽位见 [`02_i2v_api_prompt_r1_r4.json`](workflow/02_i2v_api_prompt_r1_r4.json) |
| [`workflow/TEMPLATES.md`](workflow/TEMPLATES.md) | 填槽 / 复用 / 与 crop_check·motion_gate 衔接 |
| [`workflow/03_flf2v_wan21.json`](workflow/03_flf2v_wan21.json) | 首尾帧高潮（Wan2.1 FLF2V **fp16 默认**） |

权重清单：[`manifest.json`](manifest.json)。提示词：[`prompts/`](prompts/)。

---

## P0 · 无卡装环境（可离线准备）

1. 复制 [`env.example`](env.example) → `.env`（勿提交密钥）；填 `COMFYUI_ROOT`、`MODELS_ROOT`、`SPEND_CAP_CNY`。
2. 安装/更新 **ComfyUI 最新版**（需原生 Wan2.1 与 Qwen-Image-Edit-2511 模板/子图）。
3. 按 `manifest.json` → `custom_nodes` 补齐（ControlNet aux 等）；**不要**装 NSFW 专用节点。
4. `bash scripts/restore.sh`（默认 **dry-run**）核对 URL 与落盘路径。
5. `bash scripts/smoke_test.sh --dry-run` 做离线验收（解析 workflow、对齐 manifest、检查定妆卡/双机 ID、noise/subject/motion 门禁自检、fixtures 噪点负样本、clip_status、assemble 自检、sha256 字段、restore dry-run），必须 **exit 0**。
6. 准备输入目录：`$INPUT_ROOT/cats/{A,B,C}/raw/`、`looklock/`、`$INPUT_ROOT/shots/`、`$OUTPUT_ROOT/{i2v,flf2v,exports}/`。仓库参考图放 `refs/cats/{A,B,C}/`；`restore.sh` 会硬拷贝 `front.jpg` / `cat-*.jpg` 到 `$INPUT_ROOT/cats/{A,B,C}/raw/`（已存在则跳过）。

**完成标准**：三份 workflow 能在 ComfyUI 打开（缺权重视为节点标红可接受）；路径不指向 comic 树。

---

## P1 · I2V smoke（需用户授权开机）

1. 按 [`scripts/race_boot.md`](scripts/race_boot.md) **互斥**开机（母/克隆只开一台）。
2. `bash scripts/restore.sh --apply --group i2v` 下载 **fp16** 默认 UNET（`fp8` 已标 optional，默认跳过）；真跑前先执行 `bash scripts/smoke_test.sh --dry-run` 离线预检。
3. 打开 `workflow/02_i2v_wan21_480p.json`：确认 UNET 为 `wan2.1_i2v_480p_14B_fp16.safetensors`，任意竖屏图 → 负向用 [`prompts/negative.txt`](prompts/negative.txt)。
4. Smoke：`480×832`、`length=49`、`steps=20`、`cfg=6`、`shift=8`、`uni_pc/simple`；正向用 R1 敬礼（禁 soft 词）；记录耗时与磁盘增量。
5. 生成后一键装配（等价于 G1→G2→G2m→三态）：
   ```bash
   python3 scripts/assemble_clip.py <输出视频> --start-image <首帧> --audio bed
   python3 scripts/assemble_clip.py <输出视频> --start-image <首帧> --human --note "身份/动作/音轨已听检"
   ```
   - G1 `noise_gate`；G2 `subject_gate`（SSIM 带宽 0.25–0.92）；G2m `motion_gate`（默认 max MAD≥11；上轮近静帧≈3.6 应 FAIL）
   - 人眼身份（同脸军装）+ 可见敬礼或抬头
6. 状态：`assemble_clip` 全过才写 `AUTO_QC_PASS` 并进 `candidates.jsonl`（仍非可用成片）；`--human` 写 `HUMAN_ACCEPTED` 才可对外。见 [`reviews/CLIP-STATUS.md`](reviews/CLIP-STATUS.md) 与 [`scripts/ASSEMBLE.md`](scripts/ASSEMBLE.md)。通过后再 **关机留盘**。

**完成标准**：可播短视频且 G1+G2+G2m PASS；**未**声称量产。

### ComfyUI 启动参数（2026-10-24 强制）

- **禁止** `--use-sage-attention`：Wan2.1 I2V 易出黑屏/噪点废片（ComfyUI#8573）。
- **强制** `--force-upcast-attention`（本轮 Wan I2V；ComfyUI#6987）。
- 示例：`python main.py --listen 0.0.0.0 --port 6006 --force-upcast-attention`。
- **R3 回退（非默认）**：仅 R1/R2 未过 G2m 时试 cfg=5 / shift=10；默认仍 cfg=6 / shift=8。

---

## P2 · 定妆（Look-lock）

1. 三猫定妆已锁定：**A 小橘 / B 银宝 / C 墨墨**（权威总锁 [`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md)，提示词见 [`prompts/look_cards.md`](prompts/look_cards.md)），直接使用各猫固定提示词前缀；实拍参考图已入库至 [`refs/cats/{A,B,C}/`](refs/cats/)。
2. `bash scripts/restore.sh --apply --group looklock`：默认下载 `qwen_image_edit_2511_fp8mixed.safetensors` + `qwen_2.5_vl_7b_fp8_scaled.safetensors` TE + `qwen_image_vae.safetensors`，并打印 looklock 精度策略、同步 `refs/cats/*/front.jpg` 到 `$INPUT_ROOT`。
   - **Qwen 默认 fp8mixed（OK）**；Wan 的 fp16 政策**不适用**于 Qwen，**不要**对 Qwen 加 `--force-fp16`（黑图风险）。
   - **禁止** `--use-sage-attention`。
   - Lightning 4steps LoRA 仅加速可选：**只能搭配 fp8mixed 基础模型**，不可叠加 fused lightning checkpoint；质量门禁默认 **OFF**（`Enable 4steps LoRA?` = false）。
3. 打开 `workflow/01_looklock_qwen_edit.json`：输入 `cats/A/raw/front.jpg` + 可选 `looklock/costume_ref_PLACEHOLDER.png`；正向已按 A 小橘前缀写为直立拟人美军诺曼底 / 二战步兵（露耳、SFW、不持枪），再接 [`prompts/positive_fragments.md`](prompts/positive_fragments.md) 动作/镜头片段。
4. 备选：Flux + HuMeow 等 **SFW** LoRA——manifest 仅列 Civitai 检索说明，**需人工确认许可**。
5. 每猫主装出正脸/侧面/3/4；盲测 ≥80%（见 `SERIES-WW2.md`）。

---


---

## looklock→I2V 构图（1024² → 480×832）

方图定妆直接喂竖屏 I2V 时，cover 裁切会切掉左右约 40% 宽度，**手/前臂可能出画**——没有手就很难敬礼。

```bash
python3 scripts/crop_check_i2v.py path/to/cat_anthro_looklock_00001_.png
# 打开生成的 *_i2v_480x832_crop.png，确认右手/前臂/肩在画内
```

- 手在画内 → 跑 R1/R2 敬礼。
- 手不在画内 → 本轮改 R4 抬头+围巾；敬礼留待竖幅定妆后再做。

## P3 · 单段样片

1. 定妆/分镜首帧 → `02_i2v_wan21_480p.json`（连击可多段）。
2. 高潮首尾帧 → `03_flf2v_wan21.json`（720×1280 fp16 默认；fp8 仅回退）。
3. 剪映：按主曲 **120–140 BPM** 对齐；补帧 30fps；导出 **1080×1920**；标 AI。
4. 有声：`python3 scripts/assemble_clip.py clip.mp4 --start-image <首帧> --audio bed`（或 `--audio silent` / `--audio wav --wav licensed.wav`）；也可直接用 `stitch_audio.py`。默认 128 BPM 程序化节拍床或静音；换轨只允许平台官方曲库/书面授权/CC0，见 [`scripts/AUDIO-SWAP.md`](scripts/AUDIO-SWAP.md)。
5. 单条 GPU 硬上限约定约 **3h ≈ ¥6**（需用户授权）；对照系列发布检查清单。

---

## AutoDL 4090 实务

| 项 | 建议 |
| --- | --- |
| 磁盘 | I2V fp16 ≈32.8GB + FLF2V fp16 ≈32.8GB + umt5 ≈6.3GB + 定妆 Qwen fp8mixed ≈19.1GB 等；fp8 回退可各省约 16GB/个但易噪。100G 盘建议按阶段只装当前所需 fp16，并绑持久盘 |
| 双机 race | 任意时刻只开一台；I2V 优先 025、克隆 003 可代跑；looklock 优先 003；见 [`race_boot.md`](scripts/race_boot.md) |
| 花费帽 | `SPEND_CAP_CNY` 提醒 + 人工停机；余额只以控制台为准、未充值 |
| 隔离 | `COMFYUI_ROOT` / `MODELS_ROOT` 禁止指向 comic/NSFW 树 |

### 双机实体（2026-10-24）

| 角色 | 实体 | 实例 ID | 区域 / 卡 / 盘 |
| --- | --- | --- | --- |
| 母 · I2V 优先 | 025机 | `9b4c40bda6-dad38bb9` | 重庆A · RTX 4090D · 扩盘 100G · shutdown 留盘 |
| 克隆 · looklock 优先 / 可代跑 I2V | 003机 | `bb8c4f8e12-00c8bdac` | 重庆A · RTX 4090D · 扩盘 100G · shutdown 留盘 |

任意时刻只开一台；两台当前均未开机，开机需用户授权。`env.example` 已填 `AUTODL_INSTANCE_PRIMARY` / `AUTODL_INSTANCE_CLONE` / `AUTODL_REGION`。克隆 003 可代跑 I2V（仍须单机互斥）。

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
- 权威定妆锁定：[`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md)
- 参考图索引：[`refs/cats/README.md`](refs/cats/README.md) · 入库状态：[`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)
- 双机创建结果：[`DUAL-CREATE-RESULT-2026-10-24.md`](DUAL-CREATE-RESULT-2026-10-24.md)
- 离线 smoke：[`scripts/smoke_test.sh`](scripts/smoke_test.sh)
- 社区修正落库：[`COMMUNITY-FIXES-2026-10-24.md`](COMMUNITY-FIXES-2026-10-24.md)
- 下次开机验证：[`NEXT-BOOT-CHECKLIST.md`](NEXT-BOOT-CHECKLIST.md) · 授权请示 [`reviews/BOOT-AUTH-ASK-2026-10-25.md`](reviews/BOOT-AUTH-ASK-2026-10-25.md)
- 噪声门禁 G1：[`scripts/noise_gate.py`](scripts/noise_gate.py)
- 主体门禁 G2：[`scripts/subject_gate.py`](scripts/subject_gate.py)
- 动作门禁 G2m：[`scripts/motion_gate.py`](scripts/motion_gate.py)
- 片段状态：[`scripts/clip_status.py`](scripts/clip_status.py) · [`reviews/CLIP-STATUS.md`](reviews/CLIP-STATUS.md)
- 一键装配：[`scripts/assemble_clip.py`](scripts/assemble_clip.py) · [`scripts/ASSEMBLE.md`](scripts/ASSEMBLE.md)
- G2 校准：[`reviews/SUBJECT-GATE-CALIBRATION.md`](reviews/SUBJECT-GATE-CALIBRATION.md)
- 有声/换轨：[`scripts/stitch_audio.py`](scripts/stitch_audio.py) · [`scripts/AUDIO-SWAP.md`](scripts/AUDIO-SWAP.md)
- 合成 QC 小样：[`fixtures/qc/`](fixtures/qc/)
- 构图预览：[`scripts/crop_check_i2v.py`](scripts/crop_check_i2v.py)
- 动作社区方案：[`reviews/COMMUNITY-I2V-MOTION-2026-10-25.md`](reviews/COMMUNITY-I2V-MOTION-2026-10-25.md)

---

## 定妆分工（Cursor 生图 vs Comfy）

| 用途 | 工具 | 是否入库锁定包 |
| --- | --- | --- |
| 军装气质 / 构图 mood | Cursor 生图（可选） | **否** |
| 真猫毛色/瞳色锁死 · 正侧 3/4 | **Qwen-Image-Edit-2511**（`01_looklock_qwen_edit.json`） | **是**（过盲测 ≥80%） |
| 纯文生拟人（HuMeow 等） | Flux+SFW LoRA | 仅备选；不锁「你家某只猫」 |

量产定妆以真猫多图条件编辑为准；Cursor 图只作前期探风格。

## 社区口径摘要（2026-10-23，2026-10-24 修正）

- **定妆**：Qwen-Image-Edit-2511 多图（图1身份 / 图2服装姿势 / 图3背景）为开源社区成熟免训练方案；可选 Identity Lock 提示或 Lightning（CFG≈1）。
- **视频**：Wan I2V 草稿 + FLF2V 高潮仍稳；**默认已切 Wan2.1 fp16**（官方模板口径）。`fp8_e4m3fn` 仅 VRAM 回退，最低档、易噪，不推荐；**禁止 `--use-sage-attention`**。Wan2.2 I2V 可作为 P1 后升级（需另补权重）。
- **隔离**：禁止引用漫画 NSFW/去衣栈。

## 进度同步

每完成一段工作：更新 [`PROGRESS.md`](PROGRESS.md) 并 push/PR；同步写入 Notion「小猫拟人」题材页下的进度记录。

