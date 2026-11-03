# BOOT-v0.1g · 管线就绪后一键跑清单（文档 · 不开机）

> **2026-10-26 t62u**：下次开机默认按 **v0.2 大改包**（见 [`reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md`](reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md)），不按 v0.1h；本文 v0.1g 的 FLF2V/预算/范围仅作历史清单，冲突时以 v0.2 计划为准。
> **本文件是调度用清单**，不是本仓自动开机脚本。  
> **t58u**：管线就绪即可由调度开机；**文档/模板作者不得真的开机/SSH 花钱**。  
> **t59u**：用户已授权开机出新片；**调度**按 GPU 出 v0.1g；**软顶 ≤¥1.5**。本文件仓库侧仍只维护清单。  
> **t60u（强制）**：双机 **全栈对齐**；race **抢到的那台**本机 looklock+I2V 全流程；**另一台关机**。  
> **废止**：一切「克隆只定妆 / 母机只 I2V / 定妆→换机 I2V」。调度执行器已按 t60u。  
> 对照：`reviews/COMFY-CAT-ANTHRO-COMMUNITY-2026-10-25.md` · `reviews/V0.1F-PLAN-2026-10-25.md` · `workflow/TEMPLATES.md` · `scripts/race_boot.md`

## 0. 预算与禁令（软顶）

| 项 | 口径 |
| --- | --- |
| 余额 | 控制台为准（口头约 **¥7**；以控制台刷新值为准） |
| 单轮软顶 | **≤ ¥1.5**；接近或超过则 **停机留盘**，不续跑 |
| 禁 | **FLF2V**；NSFW/去衣；扩到银宝/墨墨；**充值**；**release/删盘**；双开；跨机接力 |
| 权重 | 可按清单下载到 **抢到的那台** 数据盘；**不**把超大权重 commit 进 git |

## 1. 开机前（离机已完成 / 调度核对）

- [ ] `bash scripts/smoke_test.sh --dry-run` → exit 0
- [ ] 定妆槽：`workflow/01_looklock_api_slots.json`（cat_ref / costume_ref / **pose_or_scene_ref** / optional_lora **default off** / 短边≥1024）
- [ ] I2V 方案 A 锁定：`02` · length=49 · cfg=6 · shift=8 · fp16；`scene_lock_first_frame` + B0-01 三高光 brief
- [ ] 超分钩子：`workflow/04_upscale_4x_api_slots.json` + `scripts/upscale_4x.sh`（模型路径占位）
- [ ] `scripts/race_boot.md` DUAL-RACE-MODE = 全栈对齐 + 抢到者全干
- [ ] 另一台确认已关机；只准备抢 **一台**

## 2. 抢卡与启动（调度执行 · 只开一台）

1. 025 `9b4c40bda6-dad38bb9` 与 003 `bb8c4f8e12-00c8bdac` **均可**去抢；无偏好。
2. **谁先 Running → 谁是本轮唯一工人**；另一台保持关机。
3. `source .env`；确认 `AUTODL_BOOT_AUTHORIZED=1`（仅调度侧；本仓不代开）。
4. 在 **同一台** 装齐：`restore.sh --apply --group looklock` 与 `--group i2v`（盘不够则先 looklock 再 i2v，但仍不换机）。
5. 可选：放置 SFW 4× 模型到 `upscale_models/…`（非 git）；Animal→Human LoRA 仅人工 vet 后且开关仍默认先 off 试一镜。
6. Comfy 启动：**禁** `--use-sage-attention`；Wan 段 **必须** `--force-upcast-attention`；Qwen **勿** `--force-fp16`。

## 3. 本机全流程顺序（抢到者）

### A. 定妆（Qwen-Edit-2511）

1. 打开 `workflow/01_looklock_qwen_edit.json`
2. 槽位：`#41` 真猫 A front · `#83` 美军野战服 · `#195` 直立/诺曼底场景（可暂占位）
3. 正向含 upright bipedal / 橘白长毛锁；负向含四足/纯兽/换脸（`prompts/negative.txt`）
4. optional Animal→Human LoRA：**保持 OFF**（除非本轮书面启用）
5. 出图 → `python3 scripts/looklock_size_gate.py <png>`（短边≥1024）→ 人眼盲测身份
6. `python3 scripts/crop_check_i2v.py <png>` → 得到 480×832 **scene_lock_first_frame**

### B. 人眼 / 门禁（静帧）

- 拟人五官可读、美军野战服、橘白锁、直立非四足、SFW
- 未过则同机改 seed/参考槽，**不换机**

### C. I2V 高光镜（方案 A · 同机）

对 B0-01 三镜（见 `02_i2v_api_prompt_r1_r4.json` → `b0_01_highlight_briefs`）：

| 镜 | 中文 | positive key | 验收 |
| --- | --- | --- | --- |
| H1 | 门落 | `b0_01_ramp_door_drop` | 一眼登陆艇门/坡道 |
| H2 | 爆破开路 | `b0_01_blast_breach` | 一眼滩头爆破/开路 |
| H3 | 插旗剪影 | `b0_01_flag_silhouette` | 一眼插旗剪影 |

每镜：换 `LoadImage` #52 + positive + seed → 出片 →  
`assemble_clip.py` / G1+G2+G2m → 仅 `HUMAN_ACCEPTED` 可对外。

### D. 超分

- Comfy 4× 节点或 `bash scripts/upscale_4x.sh -i <in> -o <out>`  
- 模型缺失时勿默默跳过质量门；仅显式 `--ffmpeg-lanczos` 可作占位（质量差，记 WARN）

### E. 关机留盘

- 记录花费；若单轮将破 **¥1.5** 软顶 → 立即停
- **shutdown 留盘**；不 release；不充值；不双开第二台续跑

## 4. 与 v0.1f / 旧 BOOT 关系

- **v0.1f**：¥0 剪辑仍可本机做；不阻塞本清单 GPU 段
- `NEXT-BOOT-CHECKLIST.md` / `reviews/BOOT-AUTH-ASK-2026-10-25.md`：技术核对仍可参考，**机位分工以本文 + race_boot t60u 为准**

## 5. 回报字段（调度跑完后）

- 抢到实例 ID（025 或 003）
- looklock 路径 + size_gate
- H1/H2/H3 是否 HUMAN_ACCEPTED
- 超分是否真实 4× 模型
- 花费（分）与是否触软顶
