# LoRA smoke（791，破衣边缘，非 nude）

- 机：791 only（592 全程关机）
- 底板：`lin_qipao_1280x720.png`（林晚棠穿衣定妆裁横图）
- 管线：Qwen-Image 2.1 Edit int8，`er_sde`/`beta`，steps 16，cfg 3.0，seed **424242**，resolution 1024 → 出图约 **1376×768**
- 提示词：七要素长破衣（`prompt_torn_long7.txt`）；禁止全裸，只做破口/半裸边缘
- 封顶 ¥5 + watchdog；关机留盘

## 结果

| # | 文件 | LoRA | 权重 | 观感（相对 01 无 LoRA） |
| --- | --- | --- | --- | --- |
| 01 | `01_nolor_control.png` | 无 | — | 对照：提示词 alone 已有破口，但本张**头被裁出画幅**，身份锚弱 |
| 02 | `02_thesealpacas_v2.png` | `thesealpacas-nsfw-v2.safetensors` | 0.8 | **明显更强**：保留脸/发饰，破口更大、布料条更碎 |
| 03 | `03_femaledVaginus_L22-31.png` | `qwen2_1-femaledVaginus-nsfw-v1_3-fine_L22-31.safetensors` | 1.0 | **明显更强**：前襟撕开更狠、躯干暴露最大；仍非完全 nude |
| 04 | `04_nsfw_posture_v3.png` | `nsfw-posture-v3.safetensors` | 0.85 | **中等偏强**：有脸，破衣接近 02，姿势/体态略强调，增幅小于 03 |

## 花费 / 关机

- 开机前余额 ¥41.02 → 结束后约 **¥40.72**（花费约 **¥0.30**，未触 ¥5）
- 791/592：**shutdown 留盘**，未 release

## 对比拼图

- 本地：`/opt/cursor/artifacts/hybrid-pose-ab/lora-smoke/lora-smoke-compare.webp`（及 `.jpg`）
- 仓库：`docs/assets/hybrid-pose-ab/lora-smoke-compare.webp`
