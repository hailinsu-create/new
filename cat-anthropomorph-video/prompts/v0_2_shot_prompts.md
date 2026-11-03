# v0.2 主镜强动作提示词 · B0-01 诺曼底

> 权威：`reviews/MAJOR-LEAP-PLAN-v0.2-2026-10-26.md` §2.2 / §2.4；时间轴：`reviews/BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md`。
> 范围：**8 条主镜**。S04 门落、S10 插旗走 **03 FLF2V**；S05/S06/S07/S08/S09/S11 走 **02 I2V**。
> 每镜 **最多 2 个 seed**；两次失败换策略，禁止同参重抽。只允许 **HUMAN_ACCEPTED** 进时间线。SFW。

## 锁定参数

| 项 | I2V 主镜（S05–S09/S11） | FLF2V 关键镜（S04/S10） |
| --- | --- | --- |
| 模板 | `workflow/02_i2v_wan21_480p.json` | `workflow/03_flf2v_wan21.json` |
| 模型 | `wan2.1_i2v_480p_14B_fp16` | `wan2.1_flf2v_720p_14B_fp16` |
| 分辨率 | 480×832 | 720×1280 |
| length | 49（hero 65） | 49（hero 65） |
| steps / cfg / shift | 20 / 6 / 8 | 20 / 6 / 8 |
| 采样 | uni_pc / simple | uni_pc / simple |
| 精度 / 启动 | fp16；禁 sage；`--force-upcast-attention` | 同左 |
| seed 上限 | 2 / 镜 | 2 / 镜 |

## 动作 prompt 结构（固定顺序）

```txt
[Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear] +
[action starts at frame 0: strong verb + body part + direction/speed] +
[secondary motion: scarf / wind / water / smoke / dust] +
[camera: fixed / low-angle / handheld tracking] +
[identity lock: same face, fur pattern, helmet and red neckerchief as the first frame] +
[positive constraints: only one character, no extra soldiers, no text, no extra limbs]
```

**正向禁用词**：`gentle`、`slightly`、`small`、`soft`、`subtle`、`barely`。动作一律用强动词：`shoves / slams / drives / wades / snaps / dives / launches / sprints / hauls / plants / cracks / locks`。

## Shared negative v0.2

> 逐字用于 02 I2V 与 03 FLF2V。必须保留英文静帧词、中文静态词、morph / extra limbs。

```txt
色调艳丽，过曝，静态，静止，静止不动的画面，画面停滞，细节模糊不清，字幕，风格，作品，画作，整体发灰，最差质量，低质量，JPEG压缩残留，丑陋的，残缺的，多余的手指，画得不好的手部，画得不好的脸部，畸形的，毁容的，形态畸形的肢体，手指融合，杂乱的背景，三条腿，背景人很多，倒着走, static, still, still picture, frozen, motionless, no motion, barely moving, idle breathing only, slow motion, morph, face morph, body morph, extra limbs, extra arms, extra legs, extra characters, duplicate character, text, watermark, weapon, rifle, gun, four-legged, realistic cat body, melting paws, quadruped, on all fours, feral cat body, snout-dominant, animal face only, pure animal, face swap, different cat, identity drift, NSFW, undress, nude, muzzle-only cat face
```

## S04 · 门落重音 · FLF2V

| 项 | 值 |
| --- | --- |
| t | 3.50–4.80s · 主卡点 3.75s |
| 模板 | **03 FLF2V**（唯一解锁镜之一） |
| 首帧 | `outputs/v0.2-b0-01-2026-10-26/flf2v/S04_door_drop/first.png`（boat_ramp 已验收；手扶门闩、门未落） |
| 末帧 | `.../S04_door_drop/last.png`（门砸入海面、猫向前一步；同身份） |
| length / seeds | 49（hero 65）/ 最多 2 |
| 验收 | 一眼门落；动作完成帧踩 3.75s；首末帧同身份；水花可见；无多肢/换脸 |

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 she grips the LCVP ramp handle and shoves the steel ramp down hard; the ramp slams into the surf, cold water sprays across the frame, she steps forward into the water. Fixed low-angle camera, medium shot. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text, no extra limbs.
```

## S05 · 涉水第一步 · I2V

| 项 | 值 |
| --- | --- |
| t | 4.80–6.10s |
| 模板 | **02 I2V** |
| 首帧 | S04 末帧或 boat_ramp 竖幅 crop（`.../i2v/S05_wade/start_480x832.png`） |
| length / seeds | 49 / 最多 2 |
| 验收 | 水花可见；身份不崩；围巾强风可读；非静帧 |

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 she drives her boot into the knee-deep surf and wades forward, water blasts up to her waist and the red neckerchief rips sideways in the wind. Handheld low tracking camera follows at her pace. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text, no extra limbs.
```

## S06 · 烟柱 / 反应镜 · I2V

| 项 | 值 |
| --- | --- |
| t | 6.10–7.30s |
| 模板 | **02 I2V**（预算压缩时可降级为静帧 + 烟层） |
| 首帧 | battle looklock（`.../i2v/S06_smoke/start_480x832.png`） |
| length / seeds | 49 / 最多 2 |
| 验收 | 战场可读、非棚拍；回头/压低动作完成；身份不崩 |

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 she snaps her head toward the rising smoke column, drops her shoulder and presses low, ears flattening; thick smoke rolls across the beach and wind snaps her red neckerchief. Fixed medium close shot. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text, no extra limbs.
```

## S07 · 沙滩卧倒 · I2V

| 项 | 值 |
| --- | --- |
| t | 7.30–8.60s · 主卡点 7.97s |
| 模板 | **02 I2V** |
| 首帧 | battle 竖幅首帧（`.../i2v/S07_prone/start_480x832.png`） |
| length / seeds | 49 / 最多 2 |
| 验收 | 卧倒动作完整；尘土可见；不穿模；无多肢 |

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 she dives flat onto the sand, elbows digging, helmet dipping, dust blasts over her back and the red neckerchief whips hard. Handheld low-angle camera tracks the fall. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text, no extra limbs.
```

## S08 · 爆破冲锋 · I2V

| 项 | 值 |
| --- | --- |
| t | 8.60–9.70s |
| 模板 | **02 I2V** |
| 首帧 | battle 竖幅首帧（`.../i2v/S08_charge/start_480x832.png`） |
| length / seeds | 49 / 最多 2 |
| 验收 | 爆破可读；主体不糊；低姿前冲完整；无多余角色 |

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 an explosion bursts behind her and she launches forward in a low sprint, arms pumping, boots kicking sand, smoke and debris blast outward. Handheld camera tracks forward at her speed. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text, no extra limbs.
```

## S09 · 抬头盯镜 · I2V

| 项 | 值 |
| --- | --- |
| t | 9.70–10.78s · 高潮起势 |
| 模板 | **02 I2V** |
| 首帧 | crop-check 过线首帧（`.../i2v/S09_head_turn/start_480x832.png`） |
| length / seeds | 49 / 最多 2 |
| 验收 | 抬头完成；眼神可读；围巾强风；身份不崩 |

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 she snaps her head up and locks her eyes on the camera, ears forward, jaw set; strong wind rips the red neckerchief sideways and dust streaks past. Fixed medium close-up. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text, no extra limbs.
```

## S10 · 插旗剪影 · FLF2V

| 项 | 值 |
| --- | --- |
| t | 10.78–12.20s · 主卡点 10.78s |
| 模板 | **03 FLF2V**（唯一解锁镜之一） |
| 首帧 | `outputs/v0.2-b0-01-2026-10-26/flf2v/S10_flag/first.png`（battle 已验收；旗杆在手、旗未升顶） |
| 末帧 | `.../S10_flag/last.png`（旗升到顶、逆光烟尘；同身份） |
| length / seeds | 49（hero 65）/ 最多 2 |
| 验收 | 一眼插旗；剪影不糊；主体不裁手/旗；首末帧同身份；无多肢 |

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 she drives the flagstaff into the sand with both paws and hauls the US flag to the top; the flag snaps open hard, dust and backlight flare behind her. Fixed low-angle wide-to-medium camera. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text, no extra limbs.
```

## S11 · 敬礼 / 收束 · I2V

| 项 | 值 |
| --- | --- |
| t | 12.20–13.50s |
| 模板 | **02 I2V**（预算压缩时可 freeze 定格） |
| 首帧 | S09/S10 峰值帧（`.../i2v/S11_salute/start_480x832.png`） |
| length / seeds | 49 / 最多 2 |
| 验收 | 敬礼可读或定格干净；红围巾收束；身份不崩 |

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 she snaps her right paw to the brim of her helmet in a crisp salute and holds it firm, chin lifts, eyes lock the camera; the red neckerchief cracks in the wind. Fixed medium shot. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text, no extra limbs.
```

## 失败回退（写死）

- 每镜 2 seed 后仍 H2/运动门禁不过：S04/S10 修首末帧或改 I2V；其他镜改首帧、FLF2V 或静帧 + Ken Burns，并在 `05_v0_2_shot_manifest.md` 标注降级。
- 首末帧身份不一致：先回 Phase 1 修定妆，不得直接跑 FLF2V。
- 禁止 Lightning 默认 ON；禁止 CFG=1；禁止同参重抽。
- 只有 `RENDER_DONE → AUTO_QC_PASS → HUMAN_ACCEPTED` 全过且人眼 H1–H3 签字，才可进时间线。
