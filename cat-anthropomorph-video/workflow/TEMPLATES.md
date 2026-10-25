# Comfy 可复用模板 · 填槽说明

> 原则：能模板化的不另起结构。图生视频与定妆都复用现有 workflow/01 与 02 JSON；参数清单在并列的 *_api_*.json 与 manifest.json。
> B0-01 缺镜头（R2 / R4 / 门落 / 涉水 / 卧倒）→ 同一 I2V 方案 A 模板，只改 start_image / positive 动作句 / seed。

## 文件名一览

| 角色 | 文件 | 说明 |
| --- | --- | --- |
| I2V 图 | workflow/02_i2v_wan21_480p.json | Comfy 图形模板（方案 A 已写入默认节点） |
| I2V 参数清单 | workflow/02_i2v_api_prompt_r1_r4.json | 锁定参数 + 可换槽（API/人工填槽契约） |
| Looklock 图 | workflow/01_looklock_qwen_edit.json | Qwen-Image-Edit-2511 多图定妆图 |
| Looklock 参数清单 | workflow/01_looklock_api_slots.json | 多图输入槽（含 pose_or_scene_ref）+ 输出 ≥1024 + 可选 LoRA 开关默认 off |
| 4× 超分钩子 | workflow/04_upscale_4x_api_slots.json · scripts/upscale_4x.sh | 权重路径占位，不入库 |
| 开机清单 | BOOT-v0.1g.md | 管线就绪后调度开机；本仓文档不执行开机 |
| 权重/策略 | manifest.json → groups.i2v / groups.looklock + 顶层 templates | 机器可读字段 |

## 方案 A · Wan I2V（锁定，勿每镜另存 workflow）

锁定（所有复用镜共用）：

- UNET wan2.1_i2v_480p_14B_fp16；禁 sage；强制 --force-upcast-attention
- 480x832 · length=49 · steps=20 · cfg=6 · shift=8 · uni_pc/simple
- 负向：含 static/still/frozen + Wan 中文静帧词（prompts/negative.txt）
- R3（cfg=5/shift=10）仅双败回退，不是默认模板
- Lightning 默认 **OFF**；FLF2V **不默认**；length 公式 16f+1（49=16×3+1）
- 社区官方 480p 参考 shift=3 / steps=40；本仓因 R1 max_mad=16.27 已校准动作，**默认不改**；仅身份漂移时作回退

每镜只改三槽：

| 槽 | Comfy 节点 | 填什么 |
| --- | --- | --- |
| start_image / **scene_lock_first_frame** | LoadImage #52 | 场景锁首帧；方图定妆先 size_gate≥1024 再 crop_check_i2v.py |
| positive | CLIPTextEncode Positive #6 | 动作前置强动词句；禁 soft 词；预设 R1/R2/R4 见参数清单 |
| seed | KSampler #3 widgets[0] | 整数；R2=同 R1 句换 seed |

衔接（一键装配；三门禁 + 状态拆分）：

```bash
python3 scripts/crop_check_i2v.py path/to/looklock.png
python3 scripts/assemble_clip.py out.mp4 --start-image path/to/start_480x832.png --audio bed
# 人眼确认身份/动作/音轨后：
python3 scripts/assemble_clip.py out.mp4 --start-image path/to/start_480x832.png --human --note "已听检"
python3 scripts/assemble_clip.py --self-test
```

也可手工分步：`noise_gate.py` → `subject_gate.py` → `motion_gate.py` → `clip_status.py set`。`assemble_clip` 全过才写 `AUTO_QC_PASS` 并进 `candidates.jsonl`；`--human` 才写 `HUMAN_ACCEPTED`。详见 [`../scripts/ASSEMBLE.md`](../scripts/ASSEMBLE.md)。

- G2 `subject_gate`：相对首帧 SSIM 带宽 **0.25–0.92**；过低 FAIL，过高仅 WARN；中心区默认只报告。
- G2m 阈值 11；R1 正例 max_mad=16.27；静帧基线约 3.6 应 FAIL。
- **RENDER_DONE / AUTO_QC_PASS 都不是可用成片**；人眼确认后 `--state HUMAN_ACCEPTED --human` 才可对外。
- 输出：SaveVideo 前缀默认 video/cat_anthro_i2v；建议 $OUTPUT_ROOT/i2v/<shot_id>/（briefs 可留副本；mp4 可不 commit）。
- 有声：`scripts/assemble_clip.py --audio silent|bed|wav` 或直接 `scripts/stitch_audio.py`（默认 128 BPM 节拍床/静音）；合规见 `scripts/AUDIO-SWAP.md`。
- 候选：全过后进 `candidates.jsonl`（默认 `$OUTPUT_ROOT/candidates.jsonl`）；`AUTO_QC_PASS` 仍非可用成片。

### 社区参数对照（2026-10-25）

| 来源 | shift | steps | cfg | length | 本仓取舍 |
| --- | --- | --- | --- | --- | --- |
| 官方 `generate.py` | 3（480p） | 40 | — | 81 | 仅身份/质感回退参考 |
| 社区 kombitz | 3（480p）/5（720p） | ~20 | ~5 | 49 | cfg/shift 已由动作门禁校准，默认不改 |
| 本仓方案 A | **8** | **20** | **6** | **49** | **默认**（R1 max_mad=16.27） |
| R3 回退 | 10 | 20 | 5 | 49 | 仅 R1/R2 未过 G2m |

详表：[`reviews/COMMUNITY-OPTIMIZE-2026-10-25.md`](../reviews/COMMUNITY-OPTIMIZE-2026-10-25.md)。

## Qwen looklock（多图槽）

| 槽 | 节点 | 约定路径 |
| --- | --- | --- |
| cat_ref | LoadImage #41 | cats/{A,B,C}/raw/front.jpg（restore 自 refs/cats/） |
| costume_ref | LoadImage #83 | looklock/costume_ref_PLACEHOLDER.png 或真实美军野战服参考 |
| pose_or_scene_ref | LoadImage #195 | looklock/pose_or_scene_ref_PLACEHOLDER.png（直立姿态/诺曼底场景） |
| positive | 子图 positive | look_cards 固定前缀 + **upright bipedal** + 场景句；换猫只换前缀 |
| optional_lora | 槽位+开关 | SFW Animal→Human；**默认 off**；权重名占位不入库 |
| seed | 采样 seed | 整数 |

正向固定句：`Preserve Image 1 cat face/fur identity; apply Image 2 costume; keep bipedal stance from Image 3 when present.`
槽位：Image1=身份，Image2=服装，Image3=姿态/场景；定妆短边 **≥1024**（`scripts/looklock_size_gate.py`）。
精度：Qwen fp8mixed OK；勿对 Qwen --force-fp16；禁 sage。Lightning 4steps 默认 OFF。

输出路径约定：

- Comfy 默认 Save：looklock/cat_anthro_looklock_#####_.png
- 推荐归档：$OUTPUT_ROOT/looklock/{cat}/{yyyy-mm-dd}/cat_anthro_looklock_<seed>.png
- 过盲测后再作 I2V start_image；方图先 crop-check。

机位（双机 race / **t60u**）：**025=003 全栈对齐**；不协同；**抢到者本机**跑 looklock→I2V→超分；任意时刻只开一台（`scripts/race_boot.md` DUAL-RACE-MODE）。

## B0-01 复用示例

| 镜头 | 模板 | start_image | positive 预设 | seed |
| --- | --- | --- | --- | --- |
| R2 敬礼复验 | 02 方案 A | 同 R1 过线首帧 | r1_salute_default | 新 |
| R4 抬头 | 02 方案 A | crop-check 过线帧 | r4_head_turn | 新 |
| 门落/涉水/卧倒 | 02 方案 A | 各镜头竖屏首帧 | 自写强动词句 | 新 |
| R6 战场短动作（授权后） | 02 方案 A | 战场竖屏首帧 | 强动词短动作句 | 新 |
| 诺曼底艇/滩场景定妆（授权后优先） | 01 | cat_ref=A + 艇/滩参考 | A 前缀+诺曼底场景 | 新 |
