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

- **双机实体**：母 **025机** `9b4c40bda6-dad38bb9` / 克隆 **003机** `bb8c4f8e12-00c8bdac`（重庆A · RTX 4090D · 扩盘 100G · shutdown 留盘）；任意时刻只开一台；余额约 ¥17.25、未充值；开机需用户授权。~~当时角色名「母-Comfy定妆/克隆-Wan」~~ → **段24 t60u：全栈对齐、抢到者全干**
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
- **双机分工（历史·已废止）**：曾写 Wan/I2V 仅母 025、looklock 仅克隆 003 → **段24 t60u 废止**，见现行 `scripts/race_boot.md` DUAL-RACE-MODE。
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
- **开机请示改写**：`reviews/BOOT-AUTH-ASK-2026-10-25.md` 明确 **双机 race**、任意时刻只开一台；先离线 **v0.1b**；下一 GPU 包诺曼底 looklock→R4/R6；不 FLF2V、不定妆银宝/墨墨、不充值、不 release。~~「克隆可代跑 I2V / looklock 优先克隆」~~ → **段24 t60u：全栈对齐、不协同、抢到者本机全流程**（race_boot / BOOT-AUTH / TEMPLATES / README-PIPELINE 已改）。
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

## 2026-10-25 Asia/Shanghai · 段16：v0.1d ¥0 拼装（进行中 → 见段17）

- **状态**：本机执行器正在 box 上拼装 v0.1d（Opus **A**）；本仓无 outputs 二进制。
- **方案 / Notion**：[`reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md`](reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md) · https://app.notion.com/p/404b407a692a81e5ab71ec3656b50a99
- **占位 RESULT**：[`reviews/RESULT-v0.1d-2026-10-25.md`](reviews/RESULT-v0.1d-2026-10-25.md) → 目标 `outputs/v0.1d-b0-01-2026-10-25/`
- **边界**：¥0；**未开机**（B 须先报用户）；未充值；未 merge；未碰 comic/NSFW

## 2026-10-25 Asia/Shanghai · 段17：v0.1d ¥0 成片

- **成片路径**（不入库）：`outputs/v0.1d-b0-01-2026-10-25/B0-01-normandy-v0.1d.mp4` · 720×1280 · 13.6s · 有声 128BPM bed（同目录 silent）
- **S06**：`segments/s06_montage.mp4` 蒙太奇替绿缺卡；绿幕扫描 **MAX_GREENISH=0**
- **beatbed 作废**：`outputs/v0.1b-…/DO_NOT_USE-beatbed.md` + `.DEPRECATED`
- **段状态**：S04 **HA**；S05 **AUTO_QC_PASS**；S06 **DRAFT-HA**；其余 **RENDER_DONE**
- **RESULT**：[`reviews/RESULT-v0.1d-2026-10-25.md`](reviews/RESULT-v0.1d-2026-10-25.md)
- **方案 / Notion**：[`reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md`](reviews/IMPROVE-PLAN-v0.1d-2026-10-25.md) · https://app.notion.com/p/404b407a692a81e5ab71ec3656b50a99
- **边界**：¥0；**未开机**；未充值；未 merge；未碰 comic/NSFW（本机 brief 段23 ↔ 本仓段17）

## 2026-10-25 Asia/Shanghai · 段18：v0.1e 破¥8 补 S06 成片

- **成片路径**（不入库）：`outputs/v0.1e-b0-01-2026-10-25/B0-01-normandy-v0.1e.mp4` · 720×1280 · 13.7s · 有声 128BPM
- **S06**：`outputs/motion-test-i2v-2026-10-25-s06-battle/R6/cat_anthro_motion_R6_00001_.mp4` · seed **20261120** · G1/G2(minSSIM **0.4036**)/G2m **PASS** → **AUTO_QC_PASS**
- **花费**：7350→6990 分（≈¥0.36）；克隆003+母机 **shutdown 留盘**；**未充值、未 release**
- **RESULT**：[`reviews/RESULT-v0.1e-2026-10-25.md`](reviews/RESULT-v0.1e-2026-10-25.md)
- **Notion**：https://app.notion.com/p/404b407a692a81e0a961cbfecbb4cd09
- **边界**：本回合文档同步；未再开机；未 merge；未碰 comic/NSFW

## 2026-10-25 Asia/Shanghai · 段19：市面差距检索 + 提升方法（¥0）

- **文档**：[`reviews/MARKET-GAP-IMPROVE-2026-10-25.md`](reviews/MARKET-GAP-IMPROVE-2026-10-25.md) — 对照 v0.1e；默认先 **音乐+剪辑**，再考虑新 I2V；禁同参碰运气。
- **Notion Opus 市面评**：https://app.notion.com/p/8d13d54360d2496cabd7c68b123dee6b（段20 续）。
- **边界**：仅检索文档；未开机、未充值、未 merge；未碰 NSFW。

## 2026-10-25 Asia/Shanghai · 段20：v0.1f ¥0 剪辑计划（Opus A）

- **Opus 5.5（市面口径）**：**5.5/10** · https://app.notion.com/p/8d13d54360d2496cabd7c68b123dee6b
- **MARKET-GAP**：[`reviews/MARKET-GAP-IMPROVE-2026-10-25.md`](reviews/MARKET-GAP-IMPROVE-2026-10-25.md) · commit `fe0d1e1`
- **执行单**：[`reviews/V0.1F-PLAN-2026-10-25.md`](reviews/V0.1F-PLAN-2026-10-25.md)（10–14 刀、SFX/字幕/调色、1080 检查单）
- **ffmpeg 草案**：[`scripts/assemble_v0.1f.sh`](scripts/assemble_v0.1f.sh)（BGM=平台曲库/CC0 待填；粗剪非成片）
- **下一动作**：**本机 / 剪映做 v0.1f**（¥0，**不开机**）
- **边界**：未开机、未充值、未 release、未 merge；未碰 NSFW

## 2026-10-25 Asia/Shanghai · 段21：t56u 拟人/题材/精细差距补丁

- 用户反馈：画面不够精细、拟人性不好、与诺曼底主题差距多。
- 已写入 [`reviews/MARKET-GAP-IMPROVE-2026-10-25.md`](reviews/MARKET-GAP-IMPROVE-2026-10-25.md) §0 与差距表；[`reviews/V0.1F-PLAN-2026-10-25.md`](reviews/V0.1F-PLAN-2026-10-25.md) §2.5 题材¥0 + §2.6 v0.1g 验收。
- **分界**：字幕/滤镜/裁切/战役符号叠层 = ¥0（v0.1f）；新 looklock / 战场镜 / 高清定妆 = 须授权 GPU（v0.1g）。
- **边界**：未开机、未充值、未 release、未 merge。

## 2026-10-25 Asia/Shanghai · 段22：Comfy 猫拟人社区对照（SFW）

- **文档**：[`reviews/COMFY-CAT-ANTHRO-COMMUNITY-2026-10-25.md`](reviews/COMFY-CAT-ANTHRO-COMMUNITY-2026-10-25.md)
- **结论**：Qwen-Edit 拟人 LoRA + Wan 系 I2V/超分 社区已成熟；本仓缺直立拟人硬提示、多参考密度、超分；二足易塌需专项防。
- **v0.1g 默认栈**：Qwen-2511 多图 looklock（现权重）+ 拟人/军装提示强化 + 可选 SFW Animal→Human LoRA → Wan2.1 A（或授权评 Wan2.2）→ 4× 超分。
- **边界**：未开机、未下载大权重、未 merge；未碰 NSFW。

## 2026-10-25 Asia/Shanghai · 段23：t58u 管线就绪（v0.1g · 未开机）

- **授权口径**：用户 t58u「做好管线就开机」→ **本回合只落代码/模板/清单**；真开机交调度，文档执行时 **未开机**。
- **定妆**：`workflow/01_looklock_*.json` — upright bipedal + 美军野战服 + 橘白锁；`#195 pose_or_scene_ref`；短边≥1024（`scripts/looklock_size_gate.py`）；SFW Animal→Human LoRA **槽位默认 off**。
- **I2V**：方案 A 不变；`scene_lock_first_frame` + B0-01 高光 brief 门落/爆破开路/插旗剪影。
- **超分**：`workflow/04_upscale_4x_api_slots.json` + `scripts/upscale_4x.sh`（权重占位）。
- **BOOT**：[`BOOT-v0.1g.md`](BOOT-v0.1g.md)（预算软顶约余额¥7、单轮≤¥1.5；禁 FLF2V/NSFW/扩B·C/充值/release）。
- **边界**：未开机、未充值、未 release、未 merge；未下大权重进 git。

## 2026-10-25 Asia/Shanghai · 段24：t60u 双机口径纠正（全栈对齐）

- **纠正**：双机内容应相同；**不要协同**；哪个抢到哪个在本机全流程。
- **已改**：[`scripts/race_boot.md`](scripts/race_boot.md)（DUAL-RACE-MODE）、[`DUAL-CREATE-RESULT-2026-10-24.md`](DUAL-CREATE-RESULT-2026-10-24.md)、[`BOOT-v0.1g.md`](BOOT-v0.1g.md)、[`reviews/BOOT-AUTH-ASK-2026-10-25.md`](reviews/BOOT-AUTH-ASK-2026-10-25.md)、[`README-PIPELINE.md`](README-PIPELINE.md)、[`CHARACTER-LOCK-2026-10-24.md`](CHARACTER-LOCK-2026-10-24.md)、[`workflow/TEMPLATES.md`](workflow/TEMPLATES.md)、api `machine` 字段、`env.example`。
- **作废**：一切「克隆只定妆 / 母机只 I2V / 代跑接力」表述。
- **边界**：未开机；未充值；未 merge。

## 2026-10-25 Asia/Shanghai · 段25：t59u 授权开机出新片（文档侧未开机）

- **授权**：用户 t58u+t59u 已授权开机出片；**调度正在 GPU 出 v0.1g**。
- **软顶**：**≤ ¥1.5** / 单轮；触顶停机留盘；**不充值、不 release**。
- **本轮调度路径（t60u）**：**全栈对齐**；race **抢到的那台**本机 looklock + I2V（+超分）**全流程**；**另一台关机**。~~曾误写「克隆定妆→母机 I2V」~~ → 见段26 废止。
- **模板固化**：社区结论 → [`reviews/COMFY-TO-TEMPLATES-v0.1g.md`](reviews/COMFY-TO-TEMPLATES-v0.1g.md)；looklock slots + Wan A + 超分钩子 + [`BOOT-v0.1g.md`](BOOT-v0.1g.md) 已在 PR#84。
- **本仓边界**：文档/模板 only；**未开机、未 SSH 花钱、未 merge**；未碰 NSFW。

## 2026-10-25 Asia/Shanghai · 段26：t60u 再纠正（废止段25 分流笔误）

- **废止**：commit `b22f397` 段25「克隆 003 定妆 → 母机 025 I2V」及 BOOT 同句——**一律作废**。
- **现行**：双机同内容；**谁抢到谁全干**（本机 looklock→门禁→I2V→超分）；另一台关机；**禁止**定妆后换机 I2V。
- **调度**：执行器已按 t60u 改；文档与调度口径对齐。
- **已改文件**：`PROGRESS.md`、`BOOT-v0.1g.md`、`reviews/COMFY-TO-TEMPLATES-v0.1g.md`、`scripts/race_boot.md`（DUAL-RACE-MODE 重申）。
- **边界**：文档 only；**未开机**。


## 2026-10-25 ~23:00 Asia/Shanghai · 段27：v0.1g 成片交付 + 本岗自评入库

- **成片**：v0.1g 已交付（本机 `outputs/v0.1g-b0-01-2026-10-25/`；二进制不入库）。
- **本岗自评**：[`reviews/SELF-REVIEW-v0.1g-2026-10-25.md`](reviews/SELF-REVIEW-v0.1g-2026-10-25.md) · 综合约 **5.8** · Notion https://app.notion.com/p/404b407a692a81e59f09ef0e8e296a0a
- **花费口径**：Δ **1620 分 ≈¥1.62**（约定 1000分=¥1；对照段 Δ-360≈¥0.36）。
- **Opus 审核**：待进行。
- **边界**：文档同步 only；未开机、未 GPU、未 merge；未用 grok CLI。

## 2026-10-26 Asia/Shanghai · 段28：t62u 决策 · v0.2 一次大改长规划（文档）

- **用户 t62u**：废止「每轮只动一项」与「默认先 ¥0 剪映 v0.1h」；下一发布目标 = **一次打包大改 → v0.2**（可对外盲测接近市面入门线）。
- **新文档**：[`reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md`](reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md) — 问题树 / 12 刀分镜 / 三场景定妆 / I2V+FLF2V / 4×超分 / 卡点包装 / Phase 0–4 / 社区对照 / 授权卡 / 废弃清单。
- **锚点**：v0.1g ~14.4s · 1080 · CC0 战鼓 · 本岗 **5.8** / Opus 市面 **5.5**（与 v0.1e 持平）；余额约 **¥5.37**；双机关机留盘；dual-race 谁抢到谁全干。
- **社区补扫（2025–2026）**：Qwen-2511 多图/多角度、Animal→Human LoRA（默认 OFF）、Wan2.1 I2V/FLF2V、结构化 Wan prompt、4×/SeedVR2/FlashVSR、Hook→Payoff/onset 卡点/SFX/平台曲库；默认/否决与代价见文档 §4。
- **预算估算**：Phase 1–3 完整包 **¥4.3–7.6**（按 v0.1c/e/g 单价锚点，非实测）；余额可能不足 → **完整包须先充值授权**；压缩版软顶 **¥4.90**（P1 1.30 / P2 3.00 / P3 0.60）。
- **本轮边界**：文档 only；**未开机、未充值、未 release/删盘、未下载权重、未跑 GPU**；未碰 `ai-realistic-comic/` 或 NSFW；未用 grok CLI。
- **废止**：v0.1h 仅剪映小修默认、每轮只动一项、同参重抽、克隆/母机任务分流、先 ¥0 剪映再议开机默认。
- **下一步**：用户确认授权卡（充值授权或接受 v0.2-limited）→ Phase 0 补模板（¥0）→ 授权后 Phase 1。

## 2026-10-26 Asia/Shanghai · 段29：t63u 充值授权 · v0.2 完整包 Phase 0 模板落地（¥0）

- **用户 t63u**：已充值并授权 **v0.2 完整包 best edition**；余额约 **¥54**（以控制台为准）；GPU 渲染由 **local executor 并行**执行。
- **预算口径**：完整包**软顶 ¥8.5**；触顶停并回报，不自动充值、不静默透支。
- **本回合范围**：**仅 Phase 0 模板/文档**（**¥0**）；**未开机、未充值、未 release/删盘、未下载权重、未跑 GPU**。GPU 由 local executor 另线执行，本回合不代跑。
- **新建**：
  - `workflow/03_flf2v_api_slots.json` — S04 门落 / S10 插旗首末帧、prompt、seed、length、gates；FLF2V 仅此两镜。
  - `prompts/v0_2_shot_prompts.md` — S04–S11 共 8 条强动作 prompt + shared negative。
  - `workflow/05_v0_2_shot_manifest.md` — S01–S12 12 刀表、t 区间、模板、GPU、验收、状态/路径占位。
  - `workflow/06_v0_2_human_acceptance.md` — H1–H4 逐镜签字；`human_subject` / `human_motion` / `human_edit`；不替代 AUTO_QC。
- **增量更新**：
  - `workflow/01_looklock_api_slots.json` — `portrait` / `boat_ramp` / `battle` 预设；optional LoRA 仍默认 **OFF**。
  - `workflow/02_i2v_api_prompt_r1_r4.json` — `v0_2_shot_presets`（S05–S09/S11；每镜最多 2 seed）；S04/S10 重定向 FLF2V 03。
  - `workflow/04_upscale_4x_api_slots.json` — v0.2 4×→1080 策略；UltraSharp | ClearRealityV1 二选一；时序检查。
  - `workflow/03_flf2v_wan21.json` — 仅锁定值对齐（length 49、cfg 6、v0.2 negative），不改图结构。
  - `workflow/TEMPLATES.md` — 文件一览补 v0.2 模板。
- **锁定**：Wan FLF2V `wan2.1_flf2v_720p_14B_fp16` · 720×1280 · length 49（hero 65）· steps20/cfg6/shift8 · uni_pc/simple · fp16 · 禁 sage · `--force-upcast-attention`；I2V 仍 480×832 / length49；可用状态仅 **HUMAN_ACCEPTED**。
- **Git**：提交并 push 到 **PR #84** 同分支；**不 merge、不 force-push**。
- **边界**：未开机、未充值、未 release/删盘、未下载大权重、未跑 GPU；未碰 `ai-realistic-comic/` 或 NSFW；未用 grok CLI。
- **下一步**：local executor 并行渲染 Phase 1–2；回填 `05` 状态/路径与 `06` H1–H3 签字，再做 Phase 3 超分/成片。

## 2026-10-26 21:48 Asia/Shanghai · 段：v0.2 完整包收尾（第三次接管）

- **背景**：前两次执行器被平台中断；远端 orch 未重启，续跑至 ORCH_MOTION_DONE
- **winner**：克隆003 `bb8c4f8e12-00c8bdac`；母机025 全程 shutdown 留盘
- **accepted**：S04–S11（I2V+FLF）齐
- **upscale**：8/8 **spandrel-UltraSharp** 真超分（无 ffmpeg 兜底）
- **成片**：`outputs/v0.2-b0-01-2026-10-26/out/B0-01-normandy-v0.2.mp4` · **1080×1920** · **15.1s** · 有声 · SFX≥4 · 字幕 · 13 刀
- **花费**：54030→49780 分（Δ **-4250** / ≈¥4.25）；软顶/地板未破；未充值未 release
- **关机**：克隆 power_off→shutdown；母机已 shutdown；双机留盘
- **文档**：`reviews/RESULT-v0.2.md` · `BOOT-STATUS-NOW.md` / `BOOT-v0.2.md`
- **GitHub**：PR [#84](https://github.com/hailinsu-create/new/pull/84) 分支 `cursor/cat-anthropomorph-comfy-pipeline-db82`（仅 md；大 mp4 不入库）


## 2026-10-27 Asia/Shanghai · 段30：本岗评审 v0.2 入库（综合约 6.5）

- **用户 t64u**：你和 notion 分别评审。
- **本岗自评**：[`reviews/SELF-REVIEW-v0.2-2026-10-27.md`](reviews/SELF-REVIEW-v0.2-2026-10-27.md) · 综合约 **6.5**（等权六维：拟人 6.8 / 题材 6.8 / 精细 7.0 / 运动 5.0 / 卡点 6.2 / 工程 8.2）。
- **相对 v0.1g**：本岗 5.8 → **约 6.5**；一次大改有进步，**未达规划市面 ≥7.0**。
- **主缺口**：强动高潮（门落/插旗）未兑现；滩头直立一致性；音乐/卡点张力。
- **成片锚点**（二进制不入库）：`outputs/v0.2-b0-01-2026-10-26/out/B0-01-normandy-v0.2.mp4` · 1080×1920 · 15.1s · ≈¥4.25。
- **Notion 交付页**：https://app.notion.com/p/405b407a692a812a8706cf2b01b62c66
- **Opus 审核**：待进行（并行）。
- **边界**：文档同步 only；未开机、未 GPU、未 merge；大 mp4 不入库。
