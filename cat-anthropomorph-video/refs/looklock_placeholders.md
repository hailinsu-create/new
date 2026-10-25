# Looklock 占位图路径（v0.1g）

Comfy input-relative（开机后由 `restore.sh` / 人工放到 `$INPUT_ROOT`）：

| 槽 | 默认相对路径 | 说明 |
| --- | --- | --- |
| costume_ref | `looklock/costume_ref_PLACEHOLDER.png` | 美军野战服参考；有真图则替换 |
| pose_or_scene_ref | `looklock/pose_or_scene_ref_PLACEHOLDER.png` | 直立姿态或诺曼底场景；可暂复用 costume 占位 |
| Animal→Human LoRA | `loras/PLACEHOLDER_qwen_animal_to_human_SFW.safetensors` | **默认 OFF**；不入库 |
| 4× 超分 | `upscale_models/4x-ClearRealityV1_PLACEHOLDER.pth` | 不入库；见 `workflow/04_upscale_4x_api_slots.json` |

禁止把 NSFW / 去衣权重放进这些路径。
