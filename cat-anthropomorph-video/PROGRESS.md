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

## 2026-10-24 Asia/Shanghai · 段5：三张 jpg 重传仍未落地（uploads 路径为空）

- **用户重传声明**：消息给出 uploads 路径 `A-cat-A-ginger-white_3671.jpg` / `B-cat-B-silver-fold_c393.jpg` / `C-cat-C-black-fold_ed9a.jpg`
- **VM 实际**：Cloud Agent VM 全盘（含 `/workspace` 与 `find / -xdev`）仍未收到任何匹配二进制；`uploads` 目录仅有 9 月旧 md/json，无 jpg
- **本轮未做**：未拷贝到 `refs/cats/`、未删 [`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)、未伪造或生成图片
- **smoke**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → 仍打印三条缺图 `[smoke][WARN]`，其余检查通过
- **请用户改用**：① 本机 `git` 直接加到分支；② PR 评论附 raw 链接；③ 文件 base64/zip 放到可访问处
- **边界**：未碰 NSFW/`ai-realistic-comic`；未用 grok；未开机

## 2026-10-24 Asia/Shanghai · 段6：三猫原图已入库 + 文档收尾

- **入库确认**：仓库 tip `3abef51`，三猫原图六张 jpg 全部到位；每猫首选名与 `front.jpg` 兼容副本字节数一致
- **六路径**：
  - `cat-anthropomorph-video/refs/cats/A/cat-A-ginger-white.jpg` · 262169 B
  - `cat-anthropomorph-video/refs/cats/A/front.jpg` · 262169 B
  - `cat-anthropomorph-video/refs/cats/B/cat-B-silver-fold.jpg` · 247783 B
  - `cat-anthropomorph-video/refs/cats/B/front.jpg` · 247783 B
  - `cat-anthropomorph-video/refs/cats/C/cat-C-black-fold.jpg` · 183198 B
  - `cat-anthropomorph-video/refs/cats/C/front.jpg` · 183198 B
- **文档收尾**：`refs/cats/MISSING-UPLOADS.md` 改写为「已入库」状态页（保留文件名避免断链）；`refs/cats/README.md`、A/B/C README、`CHARACTER-LOCK-2026-10-24.md` 顶部及互链、项目 README / README-PIPELINE / DUAL / SERIES / look_cards / race_boot 同步去除待重传口径
- **smoke**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**；六张 jpg 非空，输出无「参考图待重传」或缺图类 WARN；完整日志 `/opt/cursor/artifacts/smoke-dry-run-cats-ok.log`
- **提交**：GitHub：本轮文档收尾 commit 即将/已 push 到 PR #84 分支。
- **边界**：未开机、未跑 GPU、未计费；禁止 grok；未触碰 `ai-realistic-comic/` 或任何 NSFW

## 2026-10-24 Asia/Shanghai · 段7：Wan2.1 I2V 噪点废片根因修正（社区方案落库）

- **事故**：第一只猫 I2V 首片为 raw noise 废片，主体不可辨；用户报告对输入首帧 **PSNR≈10 dB** 量级。
- **根因假设**：优先怀疑 ① 旧默认 `wan2.1_i2v_480p_14B_fp8_e4m3fn` 精度不足（官方模板为 fp16）；② ComfyUI `--use-sage-attention` 污染 Wan 注意力（ComfyUI#8573）；③ 未按需使用 `--force-upcast-attention`（ComfyUI#6987）。详见 [`COMMUNITY-FIXES-2026-10-24.md`](COMMUNITY-FIXES-2026-10-24.md)。
- **Workflow**：`02_i2v_wan21_480p.json` → id `cat-anthro-i2v-wan21-480p-fp16`，UNET + properties.models 切 `wan2.1_i2v_480p_14B_fp16.safetensors`，正向换 A 小橘猫拟人前缀；`03_flf2v_wan21.json` → id `cat-anthro-flf2v-wan21-720p-fp16`，UNET 切 `wan2.1_flf2v_720p_14B_fp16.safetensors`。保留 ModelSamplingSD3(8)、CLIPVisionEncode(none)、WanImageToVideo、KSampler(20/6/uni_pc/simple)。
- **Manifest**：i2v/flf2v 均新增 fp16 默认权重（约 32.79GB/个）；原 fp8 标 optional，注明「VRAM 回退；最低档、易噪，不推荐」。
- **启动口径**：README-PIPELINE、`scripts/race_boot.md`、`scripts/restore.sh` 均写明 **禁止 `--use-sage-attention`**，可选 `--force-upcast-attention`；P1 默认权重改 fp16，磁盘说明更新。
- **噪声门禁**：新增 `scripts/noise_gate.py`（图像/视频抽帧 + 熵/std/空间粗糙度；FAIL exit 2）；`smoke_test.sh` 增加 self-test、合成噪声必须 exit 2、`refs/cats/A/front.jpg` 必须 PASS，并强制 02/03 UNET 为 fp16、restore 日志含 fp16。
- **验收**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**；日志明示未生成真实视频、PASS 不代表生成成功。
- **尚未做**：未开机、未装 fp16 权重、未重跑 I2V、未复测 PSNR；下次按 [`NEXT-BOOT-CHECKLIST.md`](NEXT-BOOT-CHECKLIST.md) 验证后才可评价是否真修好。
- **边界**：未充值、未 merge、未用 grok；未触碰 `ai-realistic-comic/` 或任何 NSFW。


## 2026-10-25 Asia/Shanghai · 段8：I2V 近静帧 → 动作门禁 + length=49

- **事故**：looklock→I2V fp16 身份 OK（G2），但 ~2s 几乎不动（MAD≈3.6）；根因是 soft 词 / 缺 static 负向 / length=33，**不是** fp16。
- **Workflow `02`**：正向改 R1 敬礼强动词；负向追加 static/still/frozen… + Wan 中文静帧词；`WanImageToVideo.length` **33→49**；MarkdownNote 写明 R3(cfg5/shift10) 仅回退；仍 fp16 UNET；强制 `--force-upcast-attention`。
- **门禁**：新增 `scripts/motion_gate.py`（G2m，默认 max MAD≥11；基线近静帧≈3.6 应 FAIL）；`scripts/crop_check_i2v.py` 做 1024²→480×832 构图预览。
- **文档**：`reviews/COMMUNITY-I2V-MOTION-2026-10-25.md`、`README-PIPELINE`、`NEXT-BOOT-CHECKLIST`、`manifest.json` motion_policy、`prompts/*`、API 模板 `workflow/02_i2v_api_prompt_r1_r4.json`。
- **口径**：**未过 G2m 不得写「可用片段」**；未开机重跑 GPU（兄弟执行器负责）；未充值、未 merge、未碰 comic/NSFW；未用 grok CLI。

## 2026-10-25 Asia/Shanghai · 段9：¥0 预备包 + Comfy 模板化

- **¥0 离线包**：`reviews/BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md`（128 BPM / 15s）、`STORYBOARD-B0-01-NORMANDY-2026-10-25.md`（GPU 镜标注）、`MOTION-GATE-CALIBRATION.md`（R1 max_mad=**16.27**；静帧基线≈**3.6**）、`BOOT-AUTH-ASK-2026-10-25.md`（母-only R2+R4；可选 Normandy looklock；禁 FLF2V/银宝墨墨/未授权充值）。
- **双机分工**：`scripts/race_boot.md` — Wan/I2V **仅母 025** `9b4c40bda6-dad38bb9`；Qwen looklock **仅克隆 003**。
- **已模板化**：`workflow/TEMPLATES.md`；I2V 方案 A 参数清单升级 `02_i2v_api_prompt_r1_r4.json`（slots: start_image/positive/seed）；新增 `01_looklock_api_slots.json`；`manifest.json` `templates` + groups.reusable_template。B0-01 缺镜复用同一 02，只改槽。
- **v0-lite**：装配路径在 briefs/outputs；mp4 可不 commit（README-PIPELINE 已注）。
- **边界**：未开机、未充值、未 merge；未碰 NSFW/comic；未用 grok CLI。

## 2026-10-25 Asia/Shanghai · 段10：社区优化调研 + G2 主体门禁 + 三态状态 + 有声/换轨 + sha256 门禁

- **调研（先写后改）**：[`reviews/COMMUNITY-OPTIMIZE-2026-10-25.md`](reviews/COMMUNITY-OPTIMIZE-2026-10-25.md) 四节（Wan2.1/2.2 I2V、Qwen-Edit looklock、SSIM 防假阳性、抖音/小红书 BGM 合规），每条含来源链接 / 可复用做法 / 与本仓冲突 / 推荐默认。
- **G2 主体门禁**：新增 [`scripts/subject_gate.py`](scripts/subject_gate.py)（相对 start_image/frame0 的灰度 SSIM 带宽 **0.25–0.92**；过低 exit 2，过高仅 WARN；中心区可选 `--enforce-center`；`--self-test`）。文档 [`reviews/CLIP-STATUS.md`](reviews/CLIP-STATUS.md)；manifest `groups.i2v.motion_policy.gates` 挂 **G2=subject_gate**，looklock 也登记可选 G2。
- **三态状态**：新增 [`scripts/clip_status.py`](scripts/clip_status.py) —— `RENDER_DONE`（渲染结束，不可用）→ `AUTO_QC_PASS`（G1+G2+G2m 全过，仍不可用）→ `HUMAN_ACCEPTED`（人眼确认，唯一可用）。状态写 `<clip>.status.json`；禁止把前两态当「可用成片」。
- **QC fixtures**：[`fixtures/qc/`](fixtures/qc/) 合成噪点/渐变/位移/平场 PGM + README；smoke 引为 G1/G2 负样本，不依赖真猫图。
- **方案 A（社区高置信落地）**：保留 fp16 / 480×832 / length=49 / steps20 / cfg6 / shift8；`workflow/TEMPLATES.md` 增社区对照表；`workflow/02_i2v_api_prompt_r1_r4.json` 增 `community_defaults` / `fallbacks` / `status_model` / `audio`，记录官方 **shift=3** 仅身份回退、R3 cfg5/shift10 仅双败回退；Lightning 默认 OFF；FLF2V 不默认；`prompts/positive_fragments.md` 补身份回退备注。
- **Looklock**：槽位顺序明确 Image1=身份 / Image2=服装场景；01 workflow 正向追加 `Preserve Image 1 cat face/fur identity; apply Image 2 costume/scene.`；两图优先、Lightning OFF。
- **有声/换轨**：新增 [`scripts/stitch_audio.py`](scripts/stitch_audio.py)（silent / 可选 wav / 自动生成 128 BPM 正弦滴答节拍床；`--self-test`）与 [`scripts/AUDIO-SWAP.md`](scripts/AUDIO-SWAP.md)（仅平台官方曲库或书面授权/CC0；勿盗版/跨平台搬运）。
- **sha256 必验**：`manifest.json` 12 个权重全部填入 HF API `lfs.oid` 真实 sha256；新增 `checksum_policy`；`scripts/download_models.py` 默认 `--require-sha256`，下载后校验、已有文件重哈希后才 skip、缺 sha 非 dry-run 拒绝、`--validate-manifest` / `--checksum-only`；`restore.sh` 增加 sha 提醒并显式传 `--require-sha256`。
- **离线验收**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**（12 步：workflow/manifest+sha、三猫、CHARACTER-LOCK、双机、G1/G2/G2m、clip_status、stitch_audio、restore、缺 sha 拒绝、comic 隔离）。
- **未做（GPU 相关）**：未开机、未跑真实 I2V、未做 subject_gate 真机校准、未试听真实换轨；见 [`reviews/BOOT-AUTH-ASK-2026-10-25.md`](reviews/BOOT-AUTH-ASK-2026-10-25.md) 新增「待 GPU」段。
- **边界**：未充值、未 release、未发布、未 merge、未 force push；未用 grok CLI/设备码/OAuth；未碰 `ai-realistic-comic/` 与 NSFW LoRA。

## 约定落库

- Notion Memory：[工作同步：GitHub + Notion](https://app.notion.com/p/402b407a692a81ecb2ddcd6b35b29320)

## 2026-10-25 Asia/Shanghai · 段11：装配编排 + G2 校准登记 + 15s 有声 + 双机 race 改写

- **一键装配**：新增 [`scripts/assemble_clip.py`](scripts/assemble_clip.py) —— 无账本先写 `RENDER_DONE`，随后跑 **G1/G2/G2m**；三门禁全过才写 `AUTO_QC_PASS` 并进 `candidates.jsonl`，任一 FAIL 停在 `RENDER_DONE` 且不写候选；只有 `--human` 才写 `HUMAN_ACCEPTED`。支持 `--audio silent|bed|wav`（内部调 `stitch_audio.py`，对最终 mp4 跑门禁）；候选按 clip 绝对路径覆盖同一行，默认 `$OUTPUT_ROOT/candidates.jsonl`（未设则视频同目录）。
- **自检**：`assemble_clip.py --self-test` 用 `fixtures/qc/` + ffmpeg 合成短视频，覆盖 AUTO→候选、`--human`、静帧 G2m FAIL、音频 bed；smoke 已接入。
- **G2 校准**：新增 [`reviews/SUBJECT-GATE-CALIBRATION.md`](reviews/SUBJECT-GATE-CALIBRATION.md)：带宽仍 **0.25–0.92**，中带工作点约 **0.45**；fixtures 实测 moved=**0.5588**、flat=**0.2562**（中心 0.0213）、noise=**0.0057**；中心区只在 `--enforce-center --center-min-ssim 0.15` 时参与失败；默认值冻结，真机前不改。
- **G2 缩放修正**：`subject_gate.py` 在 PGM 参考与视频采样宽度不同时按 256 宽最近邻对齐，消除假 `width mismatch`；不改 SSIM 带宽/默认值。
- **15s 有声**：[`scripts/AUDIO-SWAP.md`](scripts/AUDIO-SWAP.md) 增 15s 竖屏 `assemble_clip`/`stitch_audio` 命令、1080×1920 检查、听检清单；默认 **silent 或自制 128 BPM 节拍床**，不塞盗版曲、不跨平台搬运。
- **装配文档**：新增 [`scripts/ASSEMBLE.md`](scripts/ASSEMBLE.md)；更新 [`reviews/CLIP-STATUS.md`](reviews/CLIP-STATUS.md)、[`workflow/TEMPLATES.md`](workflow/TEMPLATES.md)、[`README-PIPELINE.md`](README-PIPELINE.md) 的装配/候选/音频/机位口径。
- **开机请示改写**：`reviews/BOOT-AUTH-ASK-2026-10-25.md` 明确 **双机 race**、**克隆 003 可代跑 I2V**、任意时刻只开一台；先离线 **v0.1b**（R1/R2/R4，R4 场景漂移弱）；下一 GPU 包 **诺曼底艇/滩 looklock → R4 漂移修复或 R6 战场短动作**；不 FLF2V、不定妆银宝/墨墨、不充值、不 release；余额只以控制台为准。`scripts/race_boot.md`、`workflow/TEMPLATES.md`、`README-PIPELINE.md` 同步。
- **离线验收**：`bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run` → **exit 0**（13 步；新增 assemble self-test）。
- **GitHub**：本轮 commit 已 push 到 PR [#84](https://github.com/hailinsu-create/new/pull/84) 分支（同分支、无 force push）。
- **未做（GPU 相关）**：未开机、未跑真实 I2V、未修 R4 漂移、未跑 R6、未出诺曼底艇/滩 looklock、未在真实 15s 样片上听检换轨、未做 G2 真机校准；不充值、不 release、未 merge、未碰 `ai-realistic-comic/` 或 NSFW。

## 2026-10-25 ~18:30 Asia/Shanghai · 段12：v0.1c R4 真机过线短记（文档同步）

- **GPU**：仅开 **克隆 003** `bb8c4f8e12-00c8bdac`；用 **boat_ramp looklock** 首帧重跑 **R4**（方案 A，seed **20261114**）；跑完双机关机留盘。
- **门禁**：多帧 `subject_gate` **minSSIM=0.5663 PASS**（落中带，对照 [`reviews/SUBJECT-GATE-CALIBRATION.md`](reviews/SUBJECT-GATE-CALIBRATION.md) ≈0.45 工作点）；`noise_gate` / `motion_gate` 亦 PASS → 记 **AUTO_QC_PASS**（仍非 HUMAN_ACCEPTED）。
- **成片路径**（二进制不入库）：本机 `outputs/v0.1c-b0-01-2026-10-25/B0-01-normandy-v0.1c.mp4`（替换 S05）。
- **对照**：v0.1b R4 多帧 subject_gate **FAIL**（minSSIM **0.061**）已由本轮 R4 替换。
- **花费**：余额 **7720→7350 分**（以控制台为准）；**未充值、未 release**；未 merge；未碰 comic/NSFW。
- **Notion**：https://app.notion.com/p/404b407a692a8125a4e9f1d2e28590b0
- **短 RESULT**：[`reviews/RESULT-R4-BOAT-RAMP-v0.1c-2026-10-25.md`](reviews/RESULT-R4-BOAT-RAMP-v0.1c-2026-10-25.md)

## 2026-10-25 Asia/Shanghai · 段13：本岗评审 v0.1c（文档同步）

- **Notion**：https://app.notion.com/p/404b407a692a81bb8a63cd0796e03d30
- **综合自评**：**7.4**
- **镜头状态**：S05 **HUMAN_ACCEPTED**；S06 **占位**；成片 **无声**
- **Opus 审核**：进行中
- **本仓短档**：[`reviews/SELF-REVIEW-v0.1c-2026-10-25.md`](reviews/SELF-REVIEW-v0.1c-2026-10-25.md)（全文以 Notion 为准；链 [`RESULT-R4-BOAT-RAMP-v0.1c-2026-10-25.md`](reviews/RESULT-R4-BOAT-RAMP-v0.1c-2026-10-25.md)）
- **边界**：仅文档；未改 workflow/权重；未开机；未 merge

## 2026-10-25 Asia/Shanghai · 段14：Opus 5.5 审 v0.1c（文档同步）

- **Notion Opus 5.5**：综合 **6.6/10**（前序 5.6 **+1.0**）· https://app.notion.com/p/bdddad714fab464d8121c23471f42977
- **倾向**：A=¥0 有声 + 蒙太奇换 S06；B 仅盲测后且授权；C merge 并行待用户审
- **本岗自评**：[`reviews/SELF-REVIEW-v0.1c-2026-10-25.md`](reviews/SELF-REVIEW-v0.1c-2026-10-25.md)
- **边界**：仅文档；未改 workflow；未跑 smoke；未 merge

## 2026-10-25 Asia/Shanghai · 段15：v0.1d 提升方案（仅规划）

- **文档**：[`reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md`](reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md) — 社区检索增量 → 默认 **Opus A**（¥0 有声 + 蒙太奇换 S06 → 盲测）；B 护栏条件触发；C merge 与出片解耦。
- **目标**：第一个有声、无「缺」字卡、成片层全 HUMAN_ACCEPTED = **v0.1d**。
- **边界**：**仅规划文档**；未开机、未充值、未 stitch 正式成片、未 merge；未碰 comic/NSFW。
- **Notion**：https://app.notion.com/p/404b407a692a81e5ab71ec3656b50a99

## 2026-10-25 Asia/Shanghai · 段16：v0.1d ¥0 拼装（进行中）

- **状态**：本机执行器正在 box 上拼装 v0.1d（Opus **A**）；本仓无 outputs 二进制。
- **方案 / Notion**：[`reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md`](reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md) · https://app.notion.com/p/404b407a692a81e5ab71ec3656b50a99
- **占位 RESULT**：[`reviews/RESULT-v0.1d-PENDING.md`](reviews/RESULT-v0.1d-PENDING.md) → 目标 `outputs/v0.1d-b0-01-2026-10-25/`
- **边界**：¥0；**未开机**（B 须先报用户）；未充值；未 merge；未碰 comic/NSFW
