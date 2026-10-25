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

## 约定落库

- Notion Memory：[工作同步：GitHub + Notion](https://app.notion.com/p/402b407a692a81ecb2ddcd6b35b29320)
