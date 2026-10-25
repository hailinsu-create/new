# Comfy 可复用模板 · 填槽说明

> 原则：能模板化的不另起结构。图生视频与定妆都复用现有 workflow/01 与 02 JSON；参数清单在并列的 *_api_*.json 与 manifest.json。
> B0-01 缺镜头（R2 / R4 / 门落 / 涉水 / 卧倒）→ 同一 I2V 方案 A 模板，只改 start_image / positive 动作句 / seed。

## 文件名一览

| 角色 | 文件 | 说明 |
| --- | --- | --- |
| I2V 图 | workflow/02_i2v_wan21_480p.json | Comfy 图形模板（方案 A 已写入默认节点） |
| I2V 参数清单 | workflow/02_i2v_api_prompt_r1_r4.json | 锁定参数 + 可换槽（API/人工填槽契约） |
| Looklock 图 | workflow/01_looklock_qwen_edit.json | Qwen-Image-Edit-2511 多图定妆图 |
| Looklock 参数清单 | workflow/01_looklock_api_slots.json | 多图输入槽 + 输出路径约定 |
| 权重/策略 | manifest.json → groups.i2v / groups.looklock + 顶层 templates | 机器可读字段 |

## 方案 A · Wan I2V（锁定，勿每镜另存 workflow）

锁定（所有复用镜共用）：

- UNET wan2.1_i2v_480p_14B_fp16；禁 sage；强制 --force-upcast-attention
- 480x832 · length=49 · steps=20 · cfg=6 · shift=8 · uni_pc/simple
- 负向：含 static/still/frozen + Wan 中文静帧词（prompts/negative.txt）
- R3（cfg=5/shift=10）仅双败回退，不是默认模板

每镜只改三槽：

| 槽 | Comfy 节点 | 填什么 |
| --- | --- | --- |
| start_image | LoadImage #52 | Comfy input 相对路径；方图定妆先 crop_check_i2v.py |
| positive | CLIPTextEncode Positive #6 | 动作前置强动词句；禁 soft 词；预设 R1/R2/R4 见参数清单 |
| seed | KSampler #3 widgets[0] | 整数；R2=同 R1 句换 seed |

衔接：

```bash
python3 scripts/crop_check_i2v.py path/to/looklock.png
python3 scripts/noise_gate.py out.mp4
python3 scripts/motion_gate.py out.mp4
```

G2m 阈值 11；R1 正例 max_mad=16.27；静帧基线约 3.6 应 FAIL。
输出：SaveVideo 前缀默认 video/cat_anthro_i2v；建议 $OUTPUT_ROOT/i2v/<shot_id>/（briefs 可留副本；mp4 可不 commit）。

## Qwen looklock（多图槽）

| 槽 | 节点 | 约定路径 |
| --- | --- | --- |
| cat_ref | LoadImage #41 | cats/{A,B,C}/raw/front.jpg（restore 自 refs/cats/） |
| costume_ref | LoadImage #83 | looklock/costume_ref_PLACEHOLDER.png 或真实军装/场景参考 |
| positive | 子图 positive | look_cards 固定前缀 + 场景句；换猫只换前缀 |
| seed | 采样 seed | 整数 |

精度：Qwen fp8mixed OK；勿对 Qwen --force-fp16；禁 sage。Lightning 4steps 默认 OFF。

输出路径约定：

- Comfy 默认 Save：looklock/cat_anthro_looklock_#####_.png
- 推荐归档：$OUTPUT_ROOT/looklock/{cat}/{yyyy-mm-dd}/cat_anthro_looklock_<seed>.png
- 过盲测后再作 I2V start_image；方图先 crop-check。

机位：looklock → 克隆 003；I2V → 母 025（scripts/race_boot.md）。

## B0-01 复用示例

| 镜头 | 模板 | start_image | positive 预设 | seed |
| --- | --- | --- | --- | --- |
| R2 敬礼复验 | 02 方案 A | 同 R1 过线首帧 | r1_salute_default | 新 |
| R4 抬头 | 02 方案 A | crop-check 过线帧 | r4_head_turn | 新 |
| 门落/涉水/卧倒 | 02 方案 A | 各镜头竖屏首帧 | 自写强动词句 | 新 |
| 场景定妆（可选） | 01 | cat_ref=A + costume/scene | A 前缀+诺曼底场景 | 新 |
