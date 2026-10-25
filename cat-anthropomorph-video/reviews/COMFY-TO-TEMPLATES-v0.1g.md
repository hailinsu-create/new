# Comfy 社区结论 → 可复用模板固化（v0.1g · SFW）

> 依据 [`COMFY-CAT-ANTHRO-COMMUNITY-2026-10-25.md`](COMFY-CAT-ANTHRO-COMMUNITY-2026-10-25.md)。  
> **只固化槽位/清单/钩子**；大权重不进 git；本文件作者 **不开机**。

## 对照表

| 社区结论 | 本仓固化位置 | 约定 |
| --- | --- | --- |
| Qwen-Edit-2511 多图定妆 + 直立 bipedal + 负向防四足 | [`workflow/01_looklock_qwen_edit.json`](../workflow/01_looklock_qwen_edit.json) · [`01_looklock_api_slots.json`](../workflow/01_looklock_api_slots.json) · [`prompts/look_cards.md`](../prompts/look_cards.md) / [`negative.txt`](../prompts/negative.txt) | Image1 cat_ref · Image2 costume · Image3 pose_or_scene；短边 ≥1024（`scripts/looklock_size_gate.py`） |
| 可选 SFW Animal→Human LoRA | `01_looklock_api_slots.json` → `optional_lora` | **开关默认 off**；权重名占位，不下载进 git |
| Wan2.1 I2V 方案 A（社区常用短片路径） | [`02_i2v_wan21_480p.json`](../workflow/02_i2v_wan21_480p.json) · [`02_i2v_api_prompt_r1_r4.json`](../workflow/02_i2v_api_prompt_r1_r4.json) | **锁定** fp16 · 480×832 · length=49 · cfg=6 · shift=8；FLF2V 非默认 |
| 场景锁首帧 + 诺曼底符号镜 | `02` slots `scene_lock_first_frame` + `b0_01_highlight_briefs` · [`positive_fragments.md`](../prompts/positive_fragments.md) | 门落 / 爆破开路 / 插旗剪影 |
| 出片 4× 超分 | [`04_upscale_4x_api_slots.json`](../workflow/04_upscale_4x_api_slots.json) · [`scripts/upscale_4x.sh`](../scripts/upscale_4x.sh) | 模型路径占位；开机后落盘 |
| 开机执行顺序 / 预算软顶 | [`BOOT-v0.1g.md`](../BOOT-v0.1g.md) | 单轮 ≤¥1.5；禁充值/release/NSFW/扩 B·C |
| 填槽总说明 | [`workflow/TEMPLATES.md`](../workflow/TEMPLATES.md) | 能模板化的不另起结构 |

## 一句话

**社区栈已落成可复用模板**：looklock slots（含可选 LoRA off）+ Wan 方案 A + 超分钩子 + `BOOT-v0.1g.md`；GPU 出片由调度按授权执行，文档仓不 SSH。
