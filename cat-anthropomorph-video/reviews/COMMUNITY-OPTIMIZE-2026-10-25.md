# 社区优化调研 · 2026-10-25

> 范围：仅 `cat-anthropomorph-video/` SFW。本轮 **¥0、未开机、未跑 GPU、未充值、未 release**；不碰 `ai-realistic-comic/` 与 NSFW LoRA。
> 结构：来源链接 / 可复用做法 / 与本仓冲突 / 推荐默认。默认值以本仓动作门禁已校准为前提。

## 1. Wan2.1 / 2.2 I2V（动作、身份、9:16、CFG、shift、steps、length、Lightning、负向、首帧）

| 来源 | 可复用做法 | 与本仓冲突 | 推荐默认（本仓） |
| --- | --- | --- | --- |
| 官方 Wan2.1 `generate.py`：<https://github.com/Wan-Video/Wan2.1/blob/main/generate.py> | I2V steps=40；480*832 时 `sample_shift=3`；默认 `frame_num=81` | 本仓 steps=20 / shift=8 / length=49（动作优先，已用 R1 max_mad=16.27 校准） | **不改默认**；官方参数仅作质感受疑时对照 |
| Comfy 官方 Wan 教程：<https://docs.comfy.org/tutorials/video/wan/wan-video> | fp16 UNET 优于 bf16；480P I2V 用 `wan2.1_i2v_480p_14B_fp16` | 无（本仓已是 fp16） | **保留 fp16 / 480×832**；fp8 仅 VRAM 回退 |
| 社区 kombitz：<https://www.kombitz.com/2025/03/03/simple-comfyui-workflow-for-wan2-1-image-to-video-i2v-using-gguf-models/> | shift 3@480p / 5@720p；cfg≈5；steps≈20；length=49≈3s@16fps；用官方中文负向 | 本仓 cfg=6 / shift=8 | 默认仍 **cfg=6 / shift=8**；cfg5 只作 R3 双败回退 |
| Civitai 角色 LoRA 文：<https://civitai.com/articles/18711/wan-2122-comfyui-workflows-for-my-character-lora> | Lightning 要求 CFG=1 且负向失效（需 NAG）；Wan2.2 Lightning 会限动作；质量优先勿默认 Lightning；length 公式 16f+1；I2V shift 可降至 5–6 保表情 | 本仓无 NAG、未装 Lightning；shift=8 为动作服务 | **Lightning 默认 OFF**；length 继续 49（16×3+1）；记录「shift=3 官方 480p」为**保身份回退**，不改默认 |
| [本仓既有](../workflow/TEMPLATES.md) | 方案 A：fp16 + length=49 + 强动词 + static 负向 + steps20/cfg6/shift8；R3 回退 cfg5/shift10；禁 FLF2V 默认；禁 sage | — | 见下 |

**本节推荐默认**：

- 保留 **fp16 / 480×832 / length=49 / uni_pc+simple / steps=20 / cfg=6 / shift=8**（动作优先，已有 R1 校准）。
- 负向维持 [`prompts/negative.txt`](../prompts/negative.txt)：官方中文 + `static/still/frozen/motionless/no motion`。
- **Lightning 默认 OFF**；**勿默认 FLF2V**；首帧先 `crop_check_i2v.py`。
- 身份备选：`shift=3`（官方 480p）+ steps 上调仅作回退记录；**不改默认**。社区 shift/steps 与官方差异已在 `workflow/TEMPLATES.md` 说明。

## 2. Qwen-Image-Edit looklock 多图一致性

| 来源 | 可复用做法 | 与本仓冲突 | 推荐默认（本仓） |
| --- | --- | --- | --- |
| Comfy 官方 Qwen-Edit-2511：<https://docs.comfy.org/tutorials/image/qwen/qwen-image-edit-2511> | 2511 原生多图一致性增强；用最新 ComfyUI 模板/子图 | 无 | 继续用 `01_looklock_qwen_edit.json` 子图 |
| Next Diffusion：<https://www.nextdiffusion.ai/tutorials/consistent-outfit-changes-with-multi-qwen-image-edit-2511-in-comfyui> | Image1=角色、Image2=服装；prompt 明确写 “Change outfit of image 1 to outfit in image 2”；Lightning 4step CFG1 加速 | 本仓 Lightning OFF；正向偏场景叙述 | 槽位顺序 **cat_ref=身份 / costume_ref=服装或场景**；正向显式写身份保留句 |
| HF discussion #30：<https://huggingface.co/Qwen/Qwen-Image-Edit-2511/discussions/30> | 三参考 + 真 CFG 易出伪影；Lightning 更稳 | 本仓质量门禁默认 OFF | 先两图；三图仅在两图失败时试 |
| BD Identity Lock：<https://comfy.icu/node/BD_QwenIdentityLock> | 图1身份强度高、图2风格/服装 | 本仓未装该节点 | 借鉴思路，不新增依赖：靠槽位顺序 + prompt |
| [本仓既有](../workflow/TEMPLATES.md) | fp8mixed OK；cat_ref + costume_ref；Lightning OFF；勿对 Qwen `--force-fp16` | — | 不变 |

**本节推荐默认**：

- `cat_ref` = 身份（真猫 front）；`costume_ref` = 服装/场景。
- positive 显式加：`Preserve Image 1 cat face/fur identity; apply Image 2 costume/scene.`
- **Lightning OFF**；**两图优先于硬上三图**；fp8mixed 不变。

## 3. 防噪点假阳性质检（SSIM / 主体）

| 来源 | 可复用做法 | 与本仓冲突 | 推荐默认（本仓） |
| --- | --- | --- | --- |
| Forasoft 全参考指标：<https://www.forasoft.com/learn/video-quality/glossary/terms-vqm/full-reference> | SSIM 是全参考指标，必须逐帧对齐；错位/缩放会假失败 | 本仓采样帧与首帧尺寸需统一 | 统一缩到 256 宽后比较；不对未对齐素材下结论 |
| Hyperframes eval：<https://github.com/heygen-com/hyperframes/blob/main/skills/remotion-to-hyperframes/references/eval.md> | SSIM 单独不能证明身份；阈值留余量（p05−0.02 思路） | 本仓此前 G2 仅人眼 | 阈值取宽带宽余量，SSIM 不替代人眼 |
| media-os QC：<https://github.com/damionrashford/media-os/blob/main/modes/analysis-quality.md> | 广播 QC：freeze/black + 成对 SSIM | 无 | G2 与 G1/G2m 并联，任一单独不作为身份证明 |
| 内部评审（Opus）→ [三态落库](../reviews/CLIP-STATUS.md) | 门禁假阳性是 P0 → 拆分状态，勿把 `RENDER_DONE` 当 `AUTO_QC_PASS` | 本仓状态曾混用 | 引入三态 `clip_status.py` |
| [本仓既有](../reviews/MOTION-GATE-CALIBRATION.md) | G1 `noise_gate` 无参考熵/粗糙度；G2m `motion_gate` MAD | G2 仅人眼 | 新增 G2 `subject_gate.py` |

**本节推荐默认**：

- **G1** `noise_gate.py`（无参考熵/粗糙度）；**G2** `subject_gate.py`（相对首帧 SSIM 中带）；**G2m** `motion_gate.py`。
- G2 默认带宽 **0.25–0.92**：过低 = 噪点/身份崩（与 G1 联判）；过高仅 WARN（配合 G2m 判静帧）。
- 状态三态：`RENDER_DONE` / `AUTO_QC_PASS` / `HUMAN_ACCEPTED`；噪点负样本入 `fixtures/qc/`。
- SSIM **不单独替代人眼身份确认**；宽带宽换低假阳性。

## 4. 抖音 / 小红书 15s 卡点 + BGM 合规

| 来源 | 可复用做法 | 与本仓冲突 | 推荐默认（本仓） |
| --- | --- | --- | --- |
| IPRRR：「15 秒不算侵权」是误区：<https://www.iprrr.cn/news/306> | 时长不是豁免；卡点切片也可能侵权 | 本仓 beat sheet 有商业曲设想 | 成片默认 silent 或自制节拍床 |
| 楚天都市报 16s 案例：<https://www.ctdsb.net/c1734_202604/2716269.html> | 平台曲库跨平台/商用仍可能侵权；16 秒也被追责 | 换轨可能跨平台搬运 | 只在本平台内用官方曲库；不跨平台导曲 |
| 人民网：<http://society.people.com.cn/n1/2023/0512/c1008-32684555.html> | 优先平台内授权曲库，勿跨平台搬运 | 无 | 换轨 README 写清授权来源 |
| SellerKitly：<https://sellerkitly.com/articles/bgm-license-and-safe-music/> | 免版税≠免授权；公版作品≠公版录音 | 无 | 仅用书面授权 / CC0 录音；保留凭证 |
| [本仓既有](../reviews/BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md) | 128 BPM / 15s | 尚无有声脚本 | 新增 `scripts/stitch_audio.py` |

**本节推荐默认**：

- 成片 **silent** 或**程序生成简单节拍床**（`stitch_audio.py`，正弦滴答，非盗版曲）。
- 换轨只允许：目标平台官方曲库，或已书面授权 / CC0（保留凭证）；**勿塞盗版曲、勿跨平台搬运**。
- 卡点仍按 **128 BPM** beat sheet 对齐；导出后人工听检并记录来源。
