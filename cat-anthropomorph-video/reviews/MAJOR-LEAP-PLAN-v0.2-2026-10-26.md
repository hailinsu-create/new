# v0.2 一次大改 · 长规划（B0-01 诺曼底 · 小橘 · SFW）

> 日期：2026-10-26 · 分支：`cursor/cat-anthropomorph-comfy-pipeline-db82` · PR [#84](https://github.com/hailinsu-create/new/pull/84)
> 状态：**文档定稿 / 未开机 / 未充值 / 未 release / 未删盘**。Phase 1–3 须用户另授权；本轮只做到 Phase 0 的文档部分。
> 边界：SFW；单猫 **A 小橘**优先；B 银宝 / C 墨墨二期；不碰 `ai-realistic-comic/` 与任何 NSFW。
> 目标片：B0-01 诺曼底 1944，约 14.4–15.0s，竖屏 **1080×1920**，有声完整片。
> 仓内依据：[SELF-REVIEW-v0.1g](SELF-REVIEW-v0.1g-2026-10-25.md) · [COMFY-CAT-ANTHRO-COMMUNITY](COMFY-CAT-ANTHRO-COMMUNITY-2026-10-25.md) · [COMMUNITY-I2V-MOTION](COMMUNITY-I2V-MOTION-2026-10-25.md) · [COMMUNITY-LOOKLOCK](COMMUNITY-LOOKLOCK-2026-10-24.md) · [COMMUNITY-OPTIMIZE](COMMUNITY-OPTIMIZE-2026-10-25.md) · [MARKET-GAP-IMPROVE](MARKET-GAP-IMPROVE-2026-10-25.md) · [IMPROVE-PLAN-v0.1d](IMPROVE-PLAN-v0.1d-2026-10-25.md) · [V0.1F-PLAN](V0.1F-PLAN-2026-10-25.md) · [BEAT-SHEET](BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md) · [STORYBOARD](STORYBOARD-B0-01-NORMANDY-2026-10-25.md) · [TEMPLATES](../workflow/TEMPLATES.md)
> 社区补扫：2025–2026 公开页，见 §4；只读，不下载大权重，不执行。

## 0. 决策摘要

- **旧默认失效**：v0.1c→g 的市面口径从 6.6 回落到 5.5，v0.1g 本岗 5.8；运动/卡点/精细三维没有跨档，证明「每轮只动一项」与「先 ¥0 剪映小修」是平台期内的无效循环。
- **新默认**：停止 v0.1h 小修，**一次打包大改 → v0.2**。
- **v0.2 定义**：叙事分镜 + 三场景定妆包 + 强动 I2V/FLF2V + 4×超分 + 卡点包装，同一包交付。
- **成功标准**：相对 Opus 市面 5.5，**规划目标 ≥7.0/10**（规划目标，非实测）；Phase 4 双边盲测为准。
- **可测口径**：3s 钩子留存意向、80% 认出同一只小橘、≥6/8 主镜可见动作、≥1 动作完成帧踩重拍、1080×1920 有声完整片。
- **不达标处理**：只允许一次定点补镜（≤2 镜或 1 次包装），预算另批；禁止回到小修刷分。
- **本轮文档态**：未开机、未充值、未 release、未删盘；Phase 1–3 须另授权。
- **预算预判**：Phase 1–3 完整包估算 **¥4.3–7.6**；余额约 **¥5.37**，**可能不足，须先充值授权**；压缩版软顶 **¥4.90**。

## 1. 问题树（根因）

> 只列能解释 v0.1g 观感的根因；四列回答「后期 / 定妆 / I2V / 新权重」能否解。v0.1g 锚点：~14.4s · 1080 · CC0 战鼓 · 本岗 5.8 / Opus 市面 5.5（与 v0.1e 持平）；门禁 noise PASS、subject SSIM 0.3848 / PSNR 12.662 PASS、motion max_mad 105.422 PASS。

| # | 根因 | v0.1g 证据 | 后期能解？ | 定妆能解？ | I2V 能解？ | 须新权重？ |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | **叙事-运动一体化不足**：镜头少、偏静帧硬切，缺门落/涉水冲锋/爆破/插旗高潮 | 本岗运动 4.5；视觉复审「多为战鼓踩点的静帧/短镜硬切」；片尾定妆静帧收束 | 部分（分镜/变速/静帧运镜） | 否 | **是**（主镜数量 + 关键镜 FLF2V） | 否（FLF2V 权重已有） |
| R2 | **动作 prompt/参数仍偏保守，门禁与人眼脱节** | 门禁 motion max_mad 105.422 PASS，但人眼仍觉幻灯片；硬切/闪白也可能拉高帧间差 | 否 | 否 | **是**（强动词、负向 static、length≥49、关键镜 FLF2V） | 否 |
| R3 | **定妆资产包不完整**：只有 portrait，boat_ramp 无新定妆 png；单 front 参考锁身份 | 拟人 7.2 进步最大，但船景/战场身份、盔标偶发漂移 | 否 | **是**（portrait + boat_ramp + battle 同身份） | 部分 | 可选（SFW Animal→Human / multi-angle LoRA） |
| R4 | **精细度链路缺失**：I2V 480 源直接上采样，无 4× 超分、无统一 grade | 成片 1080，但中后段糊、AI 感仍在；I2V 源仍 480p | 部分（调色/锐化） | 部分（≥1024） | 部分（720 FLF2V） | **是**（4× 超分权重） |
| R5 | **卡点包装仍停在「CC0 战鼓拼接」** | 无商用/平台曲、无 ≥2 SFX、无精踩字幕；卡点 5.0 | **是**（曲库/SFX/字幕/踩点） | 否 | 否 | 否 |

### 1.1 根因 → v0.2 动作映射

| 根因 | v0.2 对应包 | 关键动作 | 验收 |
| --- | --- | --- | --- |
| R1 | A 叙事分镜 + C 运动 | 12 刀完整叙事；6 主镜 I2V + 2 关键镜 FLF2V | 门落/涉水/卧倒/爆破/插旗至少 4 个高潮可见 |
| R2 | C 运动 + F 门禁 | 动作前置强动词；禁 gentle/slightly；负向 static；length≥49 | 人眼可见动作，不靠读 prompt；G2m + H2 |
| R3 | B 定妆资产包 | portrait/boat_ramp/battle 三场景同身份，≥1024 | 三场景 80% 认出同一只小橘 |
| R4 | D 清晰度 | I2V 后 4× 超分，再进 1080×1920 时间线 | 中后段不糊；无闪烁/振铃 |
| R5 | E 卡点包装 | 平台曲库/CC0 + 10–14 刀 + SFX≥2 + 字幕/日期条 | 3s 听感是歌/鼓点，不是工程滴答 |

### 1.2 为什么小修无效

v0.1c 本岗 7.4 / Opus 6.6（早期口径），v0.1e Opus 市面 5.5，v0.1g 本岗 5.8 / Opus 市面 5.5。分数没有跨档，不是执行不努力，而是四个结构性变量没动：

1. **镜头数/叙事密度**没动：仍是少量主镜 + 静帧硬切。
2. **场景定妆包**没动：只有 portrait，boat/battle 没有同身份起图。
3. **清晰度链路**没动：480 I2V 直接放大，没有 4× 超分。
4. **包装层**没动：CC0 战鼓 + 段拼接，没有平台曲库/SFX/字幕/精踩。

「每轮只动一项」只会在这四个变量里原地打转；v0.2 必须一次把它们全部推进，否则 Phase 4 盲测仍会回到 5.5–5.8 平台。

## 2. v0.2「一次打包」范围

### 2.1 包含 / 不包含（写死）

| 包含（v0.2 必须同包） | 不包含（本版/本轮） |
| --- | --- |
| A. B0-01 叙事分镜一次到位：Hook → 门落/艇 → 冲锋/爆破 → 插旗/收束 | 三战役并行量产 |
| B. 定妆资产包：portrait + boat_ramp + battle，同身份 ≥1024 | 银宝/墨墨定妆与扩角色（二期） |
| C. 运动一次到位：6–8 主镜 I2V length≥49；2 关键镜 FLF2V；禁 gentle/slightly；负向 static | 同参重抽碰运气、无限 seed 刷分 |
| D. I2V 后 4× 超分再进成片；成片锁 1080×1920 | 先交 720/低码率中间态当 v0.2 |
| E. 平台曲库或明确 CC0 曲 + 10–14 刀精踩 + SFX≥2 + 字幕/日期条 | 只有 CC0 战鼓拼接的「工程样片」当 v0.2 |
| F. 门禁升级：subject/motion 人眼验收写进清单（不只 AUTO_QC） | 只凭 AUTO_QC_PASS / RENDER_DONE 宣称可用 |
| G. 一次授权下的 Phase 1–3 连续执行（双机 race，只开一台） | 充值策略、发布投流、release/删盘、NSFW |

### 2.2 A · 叙事分镜一次到位（12 刀）

> 对齐 [BEAT-SHEET](BEAT-SHEET-B0-01-NORMANDY-2026-10-25.md) 128 BPM / 15s / 32 拍；主卡点 **3.75s 门落、7.97s 卧倒、10.78s 插旗/抬头**。所有时间可 ±0.15s 对齐实际曲目强拍。

| Shot | t (s) | 内容 | 首帧/素材来源 | 模板 | GPU | 验收 |
| --- | --- | --- | --- | --- | --- | --- |
| S01 | 0.00–1.20 | 真猫正面硬切 + 钩子字 `1944·诺曼底` / `上岸前 0.5 秒` | `refs/cats/A/front.jpg` | 剪映 | 否 | 3s 内知道「要开战/变身」 |
| S02 | 1.20–2.20 | 真猫 → 直立拟人 portrait looklock，2 帧闪白 | Phase 1 portrait | 剪映/01 | 否（图已定） | 一眼拟人、小橘身份可读 |
| S03 | 2.20–3.50 | LCVP 艇内，手扶门闩，门未落，浪花；轻推镜 | Phase 1 boat_ramp | 剪映/01 | 否（图已定） | 一眼登陆艇/门 |
| S04 | 3.50–4.80 | **门落重音**：钢门砸入海面，水花扑面，猫向前一步 | boat_ramp + 门落末帧 | **03 FLF2V** | **是** | 一眼门落；动作完成帧踩 3.75s |
| S05 | 4.80–6.10 | 涉水第一步，水花溅到腰，围巾被风拉起 | S04 末帧或 boat_ramp 竖幅 | 02 I2V | **是** | 水花可见、身份不崩 |
| S06 | 6.10–7.30 | 远景烟柱/反应镜：猫中近景回头/压低身体 | battle looklock | 02 I2V 或静帧+烟层 | **是/可选** | 战场可读、非棚拍 |
| S07 | 7.30–8.60 | **沙滩卧倒/翻滚**，尘土掠过；主卡点 7.97s | battle 竖幅首帧 | 02 I2V | **是** | 卧倒动作完整、不穿模 |
| S08 | 8.60–9.70 | **爆破开路/冲锋**：身后炸点、猫低姿前冲 | battle 竖幅首帧 | 02 I2V | **是** | 爆破可读、主体不糊 |
| S09 | 9.70–10.78 | 抬头盯镜/围巾强风；高潮起势；主卡点前最后一拍 | crop-check 过线首帧 | 02 I2V | **是** | 抬头完成、眼神可读 |
| S10 | 10.78–12.20 | **插旗剪影**：双爪握杆，旗升到顶，烟尘逆光；主卡点 10.78s | battle + 旗杆首/末帧 | **03 FLF2V** | **是** | 一眼插旗；剪影不糊 |
| S11 | 12.20–13.50 | 敬礼/持旗定格；红围巾收束 | S09/S10 峰值帧 | 02 I2V 或 freeze | **是/可选** | 敬礼可读或定格干净 |
| S12 | 13.50–15.00 | 定妆定格 + `Normandy 1944` + `#AI生成`；淡出 | portrait/battle 峰值 | 剪映 | 否 | 字幕不挡脸、收束干净 |

**硬约束**：S04/S10 必须用 FLF2V（首末帧都来自已验收 looklock）；其余主镜默认 I2V。若预算被压缩，优先保 S04/S05/S07/S08/S10，S06/S11 可降级为静帧+Ken Burns，但要在成片清单标注，不得把降级版叫完整 v0.2。

### 2.3 B · 定妆资产包（同身份三场景）

| 场景 | 提示重点 | 参考槽 | 输出 | 验收 |
| --- | --- | --- | --- | --- |
| `portrait` | 直立 bipedal、拟人五官可读、美军 M41、带耳洞钢盔、红围巾、SFW、不持枪 | Image1=A front；Image2=军装；Image3=直立姿态 mood | 短边 **≥1024**（建议 1024×1536） | H1；一眼拟人；小橘毛色/瞳色可读 |
| `boat_ramp` | 同身份在 LCVP 敞舱，手扶门闩/坡道，门未落，海面浪花，低角度 | Image1=A front；Image2=军装；Image3=已验收 portrait 锁身份 + 艇景 | 短边 **≥1024** | H1；一眼登陆艇；手在竖裁内 |
| `battle` | 同身份在滩头，烟柱/炸点背景，卧倒/前冲/插旗任选，SFW 无血腥 | Image1=A front；Image2=军装；Image3=已验收 portrait + 战场 mood | 短边 **≥1024** | H1；一眼诺曼底战场；主体不糊 |

**身份锁规则**：

1. 三场景都先保留 `Preserve Image 1 cat face/fur identity; keep the same helmet, red neckerchief and bipedal stance from Image 3.`
2. 正向必须含 `upright bipedal anthropomorphic cat-girl, humanoid face with readable eyes nose mouth, ears visible, US WWII Normandy infantry uniform, SFW, no muzzle-only cat face, no quadruped`。
3. 负向必须含 `quadruped, on all fours, feral cat body, snout-dominant, animal face only, extra limbs, extra characters, text, watermark`。
4. 每场景 **最多 2–3 个 seed**；选定 1 张进 I2V，不做无限重抽。
5. 可选 SFW Animal→Human LoRA：**默认 OFF**，只在 portrait 连续 3 seed 仍不拟人且人工核过 license 后，以 0.6–0.8 强度试一镜；不得默认开启。
6. 多角度 LoRA（如 Qwen-2511 Multiple Angles）只作 boat/battle 侧面/背面漂移的备选，不默认；IP-Adapter / InstantID / PuLID **不作为真猫主链默认**（人脸分布不匹配，见 §4.1）。

### 2.4 C · 运动一次到位（I2V / FLF2V）

**主镜参数（默认）**：

| 项 | I2V 主镜 | FLF2V 关键镜 |
| --- | --- | --- |
| 模型 | `wan2.1_i2v_480p_14B_fp16` | `wan2.1_flf2v_720p_14B_fp16` |
| 分辨率 | 480×832 | 720×1280 |
| length | **49**（3.06s@16fps）；hero 可 65 | **49**（hero 可 65） |
| steps / cfg / shift | 20 / 6 / 8 | 20 / 6 / 8 |
| 采样 | uni_pc / simple | uni_pc / simple |
| 精度/启动 | fp16；禁 sage；`--force-upcast-attention` | 同左 |
| 负向 | static/still/frozen/motionless/no motion/barely moving + 中文静帧词 | 同左 + morph/extra limbs |
| 用量 | 每镜 **最多 2 seed** | 每镜 **最多 2 次** |

**动作 prompt 社区公式**（结构比形容词重要）：

```txt
[Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear] +
[action starts at frame 0: verb + body part + direction/speed] +
[secondary motion: scarf/wind/water/smoke] +
[camera: fixed / low-angle / handheld tracking] +
[identity lock: same face, fur pattern, helmet and red neckerchief as the first frame] +
[positive constraints: only one character, no extra soldiers, no text, no extra limbs]
```

示例（门落，FLF2V 首末帧之间）：

```txt
Exactly one anthropomorphic orange-white cat soldier in US WWII Normandy gear. At frame 0 she grips the LCVP ramp handle and shoves the steel ramp down hard; the ramp slams into the surf, cold water sprays across the frame, she steps forward into the water. Fixed low-angle camera, medium shot. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text.
```

示例（冲锋，I2V）：

```txt
Exactly one anthropomorphic orange-white cat soldier. She sprints forward through knee-deep surf, rifle held low, ears pinned back, red neckerchief snapping hard in the wind; explosions bloom behind her and smoke rolls across the beach. Handheld camera tracks forward at her speed. Same face, fur pattern, helmet and red neckerchief as the first frame. Only one character, no extra soldiers, no text.
```

**硬约束**：

- 正向 **禁止** `gentle, slightly, small, soft, subtle, barely`；动作必须用强动词（shoves/slams/sprints/dives/raises/snaps）。
- 负向必须含 `static, still, still picture, frozen, motionless, no motion, barely moving, idle breathing only` 与中文静帧词。
- 关键镜 **S04 门落、S10 插旗** 用 FLF2V；首末帧都必须是已验收同身份 looklock。若首末帧身份不一致，先修定妆，不得直接跑。
- 旧 v0.1g 的「FLF2V 一律禁」在 v0.2 **仅对 S04/S10 解除**；其他镜仍不默认 FLF2V。
- 失败两次就换策略（FLF2V / 换首帧 / 静帧+Ken Burns），**禁止同参重抽**。
- Lightning 默认 **OFF**；CFG=1 会让负向基本失效，不采用。

### 2.5 D · 清晰度与交付

1. 每条 I2V/FLF2V 验收后先 **4× 超分**：480×832 → 1920×3328；FLF2V 720×1280 → 2880×5120（若显存/时间不够，FLF2V 可 2× 后直接进 1080 时间线，但要在清单标注）。
2. 4× 后做 **时间一致性检查**（抽帧 SSIM / 闪烁目检）；不合格不进修。
3. 超分后 **降采样到 1080×1920**（1920×3328 → 高度 1920，左右各裁约 14px；或上下补 24px，二选一后全片统一）。
4. 成片锁 **1080×1920 · 30fps · 14.4–15.0s**；H.264 high profile；AAC 192–320kbps；AI 标识。
5. 轻微 unsharp + 统一 grade；禁止每镜换滤镜；禁止过度锐化产生白边。
6. 4× 模型默认选 **4x-UltraSharp 或 4x-ClearRealityV1**（二选一后冻结）；若逐帧超分闪烁，A/B **SeedVR2 3B** 或 **FlashVSR**，但它们是新增权重/额外耗时，不作为默认。
7. RIFE 只在 16→30fps 明显卡顿时使用；不能用补帧伪造运动。

### 2.6 E · 卡点包装与 GPU 同包交付

| 项 | v0.2 写死 | 不合格示例 |
| --- | --- | --- |
| 曲 | 目标平台官方曲库，或明确 CC0/书面授权曲；保留凭证；目标 120–140 BPM，优先 128 | 只有 CC0 战鼓 loop；盗版曲；跨平台搬曲 |
| 刀数 | **10–14 刀**；本片 12 刀；每刀 0.8–1.6s，至少 1 个 ≥1.5s 喘息镜 | 3–5 段长拼接；每拍乱切 |
| 踩点 | 每 2/4 拍切；用 onset 检测/听检，不只算 BPM；主卡点 3.75/7.97/10.78s | 只对齐 BPM，累计漂移 |
| SFX | **≥2，目标 3–5**：门落金属、水花、爆破低频、旗布/风、riser、装备 | 只有 BGM，无音效层 |
| 字幕 | 0–2s 钩子；`1944-06-06` 日期条；片尾 `Normandy 1944 #AI`；不挡脸/眼 | 全程大字挡脸；无 AI 标识 |
| 调色 | 全片一个 LUT/grade；低对比略提饱和；眼神微提亮；可选胶片颗粒 | 每镜不同滤镜 |
| 响度 | 目标 **-14 LUFS integrated**，true peak ≤ -1 dBTP；手机外放听检 | 爆音/忽大忽小 |
| 命名 | 只有以上全过才叫 **v0.2**；包装未完成叫 `v0.2-draft`；预算压缩叫 `v0.2-limited` | 把中间态直接叫 v0.2 |

**禁止**：再交「只有 CC0 战鼓拼接」的中间态当 v0.2。若曲库授权/音效/字幕任一未完成，最多叫 `v0.2-draft`，不得对外盲测。

### 2.7 F · 门禁升级（不只 AUTO_QC）

现有 G1/G2/G2m 保留，但 v0.2 必须增加人眼项：

| 门 | 内容 | 通过标准 | 失败处理 |
| --- | --- | --- | --- |
| G1 | `noise_gate.py` | exit 0 | 不进候选 |
| G2 | `subject_gate.py` 相对首帧 SSIM 0.25–0.92 | exit 0；过高仅 WARN | 修首帧/换 seed |
| G2m | `motion_gate.py` max MAD≥11 | exit 0 | 改 prompt/FLF2V |
| **H1 身份** | 同一只小橘；直立；耳/钢盔/红围巾可读；非四足；无换脸/多肢 | 人眼 80% 认出 | 回 Phase 1 修定妆 |
| **H2 运动** | 不读 prompt 也能看出动作；无静帧感；动作在镜内完成；无瞬移 | 6/8 主镜过 | 换策略，不重抽 |
| **H3 构图** | 主体不裁手/旗；枪/旗可读；无文字伪影；无多余角色 | 逐镜过 | 重定首帧/裁切 |
| **H4 成片** | 切点踩拍；SFX 同步；字幕不挡脸；色感统一；无绿卡 | 全片过 | 回 Phase 3 |

> v0.1g 的 `motion max_mad 105.422 PASS` 说明单靠帧间差不能证明「连续运动」：硬切/闪白也会拉高统计。v0.2 的 H2 是必过项，AUTO_QC 只是入场券。

状态仍用三态：`RENDER_DONE` → `AUTO_QC_PASS` → `HUMAN_ACCEPTED`。Phase 0 之后在状态 JSON 增加 `human_subject` / `human_motion` / `human_edit` 三个布尔字段，禁止只用一个 `--human` 概括。

## 3. 分阶段执行（一次大改，按授权门拆步）

### 3.0 总览

| Phase | 内容 | 授权 | 预算软顶 | 产出 | 触地板？ |
| --- | --- | --- | --- | --- | --- |
| P0 | 文档/模板/权重清单 | ¥0，本轮可做 | ¥0 | 本文件 + PROGRESS/BOOT/NEXT 同步 | 否 |
| P1 | 三场景定妆资产包 | 须开机 | ≤¥1.30 | portrait/boat_ramp/battle 各 1 张过线 | 否（保留 ≥¥4.07） |
| P2 | 6 主镜 I2V + 2 关键镜 FLF2V | 须开机 | ≤¥3.00 | 8 条 HUMAN_ACCEPTED 或降级清单 | 接近/可能触地板，须先充值授权 |
| P3 | 4× 超分 + 剪映成片包装 | 部分 ¥0 / 超分须 GPU | ≤¥0.60 | 1080×1920 有声 v0.2 | 否（保留 ≥¥0.47） |
| P4 | 本岗 + Notion Opus 双边盲测 | ¥0 | ¥0 | 评分/结论/是否定点补镜 | 否 |

**总软顶（压缩版）**：**≤¥4.90**（P1 1.30 + P2 3.00 + P3 0.60），余额 ¥5.37 保留 ≥¥0.47。完整包估算 **¥4.3–7.6**，上界超余额，**须先充值授权**（见 §3.6）。

### Phase 0 · 文档 / 模板 / 权重清单（¥0，本轮只做到这里）

**输入**：本文件、现有 `workflow/TEMPLATES.md`、`workflow/01–04`、`scripts/*`、`refs/cats/A/front.jpg`。

**步骤**：

- [ ] 固化本文件的 12 刀清单、三场景定妆清单、8 条主镜 prompt 槽、4× 超分策略、H1–H4 验收表。
- [ ] 列权重清单：现有 Qwen-2511 / Wan2.1 I2V fp16 / Wan2.1 FLF2V fp16 / 4× 超分（新增，百 MB 级）；可选 SFW Animal→Human LoRA、multi-angle LoRA、SeedVR2/FlashVSR（全部默认 OFF，须人工 vet）。
- [ ] 在 `workflow/` 下补 §5 列出的模板（**本轮不写 JSON，只列职责**；下一轮 Phase 0 再落）。
- [ ] 跑 `bash cat-anthropomorph-video/scripts/smoke_test.sh --dry-run`，确认文档/链接改动不破坏离线验收。
- [ ] 同步 `PROGRESS.md`、`BOOT-v0.1g.md`、`NEXT-BOOT-CHECKLIST.md` 顶部口径。

**权重清单（Phase 1 前核对）**：

| 权重 | 用途 | 状态 | 体积 | 授权/代价 |
| --- | --- | --- | --- | --- |
| Qwen-Image-Edit-2511 fp8mixed + TE + VAE | 三场景定妆 | 已有 | 约 19.1GB + 6.3GB + VAE | 已有；须授权 GPU |
| Wan2.1 I2V 480p 14B fp16 | 6 主镜 | 已有 | 约 32.8GB | 已有；须授权 GPU |
| Wan2.1 FLF2V 720p 14B fp16 | S04/S10 | 已有 | 约 32.8GB | 已有；须授权 GPU |
| 4x-UltraSharp 或 4x-ClearRealityV1 | 4× 超分 | **新增** | 百 MB 级 | 须下载权重 + 须授权 GPU |
| SFW Animal→Human LoRA | portrait 备选 | 可选 | 百 MB–1GB（待核） | 须下载权重 + 人工 vet license |
| Qwen-2511 Multiple Angles LoRA | boat/battle 侧/背备选 | 可选 | 百 MB 级 | 须下载权重 |
| SeedVR2 3B / FlashVSR | 超分闪烁 A/B | 可选 | GB 级 | 须下载权重 + 须授权 GPU |

**输出**：本文件；PROGRESS 段 28；BOOT/NEXT 顶部 v0.2 默认句。

**验收**：链接可解析；无「v0.1h 小修默认」；smoke dry-run exit 0。

**失败回退**：只修文档/链接；不开机、不下载权重。

**预估 ¥**：**0**。**触地板**：否。

### Phase 1 · 定妆资产包（须开机）

**输入**：`refs/cats/A/front.jpg`；军装参考；艇/滩场景 mood；可选 v0.1g 已验收 portrait 作 Image3 身份参考。

**步骤**：

1. 抢到一台 4090（025 或 003 均可）；另一台保持关机；跑完 shutdown 留盘。
2. `restore.sh --apply --group looklock`；确认 Qwen fp8mixed、禁 sage、勿 `--force-fp16`。
3. 用 `01` 模板跑三场景：每场景 **2 个 seed**，最多 3 个；先 portrait，过 H1 后再跑 boat_ramp/battle。
4. 每张出图过 `looklock_size_gate.py`（短边≥1024）→ `crop_check_i2v.py`（480×832 手/旗在画内）→ 人眼 H1。
5. 选定 3 张（每场景 1 张）作为 v0.2 定妆包；其余作废，不无限重抽。

**输出路径**：

```text
outputs/v0.2-b0-01-2026-10-26/looklock/
  portrait/    cat_anthro_v02_portrait_<seed>.png
  boat_ramp/   cat_anthro_v02_boat_ramp_<seed>.png
  battle/      cat_anthro_v02_battle_<seed>.png
  accepted/    portrait.png / boat_ramp.png / battle.png   # 各 1 张过线
  *.480x832.crop.png
  looklock.manifest.json
```

**验收**：三场景均过 H1；短边≥1024；三张同身份（80% 认出同一只小橘）；boat_ramp 一眼艇门；battle 一眼滩头；SFW。

**失败回退**：

- portrait 连续 3 seed 不拟人 → 才允许试 SFW Animal→Human LoRA（0.6–0.8，人工核 license），仍不过则停，回报。
- boat/battle 身份漂移 → 用已验收 portrait 作 Image3 身份锁；仍漂移 → 多角度 LoRA 备选；不得改用 IP-Adapter/InstantID 主链。
- 场景参考不清 → 用 §4 社区 mood 重构，不硬跑。

**预估 ¥**：**¥1.0–1.8**（按 v0.1g looklock+R6 ¥1.62 锚点拆分，非实测）。**软顶**：≤¥1.30；累计 >¥1.20 停。**触地板**：否（保留 ≥¥4.07）。

### Phase 2 · 主镜 I2V / FLF2V 包（须开机）

**输入**：Phase 1 三张过线定妆；crop-check 首帧；§2.4 prompt；S04/S10 首末帧。

**步骤**：

1. 同机跑 6 条 I2V：S05 涉水、S06 烟反应、S07 卧倒、S08 爆破冲锋、S09 抬头、S11 敬礼/定格。
2. 同机跑 2 条 FLF2V：S04 门落、S10 插旗；首末帧都来自过线 looklock。
3. 每镜 **最多 2 seed**；每条出片先 `assemble_clip.py` 跑 G1/G2/G2m，再人眼 H1/H2/H3。
4. 过线写 `HUMAN_ACCEPTED`；失败两次换策略（FLF2V/换首帧/静帧+Ken Burns），不重抽。
5. 跑完记录花费/显存/耗时/seed；关机留盘。

**输出路径**：

```text
outputs/v0.2-b0-01-2026-10-26/
  i2v/S05_wade/          raw.mp4 + start_480x832.png + gates.json + status.json
  i2v/S06_smoke/         ...
  i2v/S07_prone/         ...
  i2v/S08_charge/        ...
  i2v/S09_head_turn/     ...
  i2v/S11_salute/        ...
  flf2v/S04_door_drop/   raw.mp4 + first.png + last.png + gates.json + status.json
  flf2v/S10_flag/        ...
  accepted/              # 只放 HUMAN_ACCEPTED
```

**验收**：至少 **6/8** 主镜 HUMAN_ACCEPTED，且 S04/S10 两条 FLF2V 必须过；H2 动作可见；无静帧硬切感；身份不崩；无四足/多肢/换脸。

**失败回退**：单镜两次失败 → 用 FLF2V（关键镜）或静帧+Ken Burns（非关键镜）；若 <6 条过线，不触发 Phase 3，不叫 v0.2；回报缺口，等二次定点补镜授权。**禁止**同参重抽、**禁止**开第二台。

**预估 ¥**：**¥3.0–5.0**（6 I2V×¥0.36–0.50 + 2 FLF2V×¥0.70–1.00 + 1–2 次失败重试；FLF2V 按 I2V 约 2× 估算，依据 v0.1c/e 单镜锚点，非实测）。**软顶**：≤¥3.00；累计 >¥4.60 停。**触地板**：完整 8 镜+重试可能触；故 **完整包须先充值授权**；压缩版（6 I2V+1 FLF2V）可在 ¥4.90 内完成。

### Phase 3 · 超分 + 剪映成片包装（可部分 ¥0）

**输入**：Phase 2 的 HUMAN_ACCEPTED 片段；4× 超分模型；平台曲库/CC0 曲；SFX；字幕文案。

**步骤**：

1. 每条片段 4× 超分 → 时间一致性抽检 → 降采样到 1080×1920。
2. 剪映/ffmpeg 按 12 刀时间线拼装；主卡点 3.75/7.97/10.78s 对齐。
3. 叠平台曲库/CC0 曲；SFX 3–5 个（门落/水花/爆破/旗风/riser）；响度 -14 LUFS。
4. 字幕：钩子、日期条、片尾 AI 标识；不挡脸。
5. 统一调色/轻微锐化；导出 1080×1920 30fps 有声 + silent + 封面。

**输出路径**：

```text
outputs/v0.2-b0-01-2026-10-26/
  upscaled/<shot>_1080p.mp4
  edit/v0.2-timeline/            # 剪映工程或 ffmpeg 中间件
  out/B0-01-normandy-v0.2.mp4
  out/B0-01-normandy-v0.2.silent.mp4
  out/B0-01-normandy-v0.2.cover.jpg
  out/audio-credits.md           # 曲目/授权/来源
```

**验收**：1080×1920；14.4–15.0s；12 刀（10–14）；≥2 SFX（目标 3–5）；字幕/日期条；无绿卡；无糊段；H4 全过；`v0.2` 命名条件满足。

**失败回退**：超分闪烁 → SeedVR2/FlashVSR A/B 或 2×+锐化；曲库授权不清 → 换 CC0；包装未完成 → 命名 `v0.2-draft`，不得对外盲测。

**预估 ¥**：**¥0.3–0.8**（GPU 超分；剪映/ffmpeg 编辑 ¥0）。**软顶**：≤¥0.60。**触地板**：否（保留 ≥¥0.47）。

### Phase 4 · 双边盲测（¥0）

**输入**：v0.2 成片、v0.1g 对照、盲测问题单、Notion Opus 评审页（现有页，不新建分页）。

**步骤**：

1. 本岗小样本 5–8 人盲测（非统计显著，只作方向）；问题：3s 内会停吗？认出同一只小橘吗？动作是否像视频不是幻灯片？哪个动作踩在鼓上？会看完吗？1–10 分。
2. Notion Opus 按同一 rubric 评：拟人/题材/精细/运动/卡点/工程。
3. 对照 v0.1g 与市面 5.5 锚点；记录每维分数与「为什么」。

**过线判据（规划目标，非实测）**：

- Opus 市面口径 **≥7.0（规划目标）**；本岗盲测 **≥7.0**；运动、卡点两维各 **≥6.0**；无维度 <5.5。若 Opus 落在 6.5–6.9，记「接近但未达标」，只允许一次定点补镜，不叫 v0.2 达标。
- 可测项：3s 停留意向 ≥半数「会/犹豫」；80% 认出同一只小橘；≥6/8 主镜可见动作；≥1 动作完成帧被指出踩重拍；1080×1920 有声完整片。
- 达标 → 记 **v0.2 release candidate**（仍不发布，发布须用户另批）。
- 未达标 → 只允许 **一次定点补镜**（≤2 镜或 1 次包装），预算另批；**禁止**回到「每轮只动一项」的小修刷分。

**输出**：`reviews/V0.2-RESULT-2026-10-26.md` + `reviews/V0.2-BLIND-TEST-2026-10-26.md`（Phase 4 新建）；回写现有 Notion 进度/评审页。

**预估 ¥**：**0**。**触地板**：否。

### 3.6 余额、软顶与充值授权

| 项 | 数值 | 说明 |
| --- | --- | --- |
| 当前余额 | **约 ¥5.37** | 以控制台为准；本轮未开机/未充值 |
| 已有单价锚点 | v0.1c 单 R4 **≈¥0.37**；v0.1e 单 R6 **≈¥0.36**；v0.1g looklock+R6 **≈¥1.62** | 来自已有评审；v0.2 为估算，非实测 |
| Phase 1 估算 | ¥1.0–1.8 | 三场景定妆，2 seed/场景 |
| Phase 2 估算 | ¥3.0–5.0 | 6 I2V + 2 FLF2V + 1–2 次重试 |
| Phase 3 估算 | ¥0.3–0.8 | 4× 超分 + 包装 |
| 完整包合计 | **¥4.3–7.6** | 上界超余额 |
| 压缩版软顶 | **¥4.90** | P1 1.30 + P2 3.00 + P3 0.60；保留 ≥¥0.47 |
| 停止线 | 累计 **>¥4.60** 停并回报；**>¥5.00** 硬停 | 不自动充值、不续跑 |
| 充值 | **须用户另授权** | 完整包建议先充值 **+¥5**（以控制台为准）；未充值只能做 `v0.2-limited` |

**写死**：按现有锚点，完整 v0.2 包的现实成本上界 **超过余额 ¥5.37**。因此 **Phase 1 之前必须先获得充值授权或明确接受压缩版**；调度不得先跑后补，不得静默透支。若用户只批 ¥4.90，则只跑压缩版（6 I2V + 1 FLF2V + 3 定妆 + 超分），并在成片/评审中标注 `v0.2-limited`，不得宣称达到完整 v0.2 目标。

## 4. 社区对照表（2025–2026 公开实践）

> 只读公开页；每条给来源、要点、本岗是否默认采用、代价。代价三档：**¥0** / **须授权 GPU** / **须下载权重**（可叠加）。不碰 NSFW。

### 4.1 真宠 → 拟人静帧：锁脸 / 锁身 / SFW

| 社区做法 | 来源（2025–2026） | 要点 | 本岗 v0.2 默认采用？ | 代价 | 替代 / 否决理由 |
| --- | --- | --- | --- | --- | --- |
| Qwen-Image-Edit-2511 多图一致性 | ComfyUI 官方 docs（2511）· <https://docs.comfy.org/tutorials/image/qwen/qwen-image-edit-2511>；Qwen 博客 2025-12-23 · <https://qwen.ai/blog?id=qwen-image-edit-2511> | 2511 强化角色一致性、多图融合、内置社区 LoRA；适合「图1身份 + 图2服装 + 图3姿态/场景」 | **采用** | ¥0（现有权重）+ 须授权 GPU | 本仓 01 已是 2511；继续三槽，不换基座 |
| Qwen-2511 Multiple Angles LoRA | fal / HF · <https://huggingface.co/fal/Qwen-Image-Edit-2511-Multiple-Angles-LoRA> | 96 个相机位（4 仰角 × 8 方位 × 3 距离），强度 0.8–1.0；可补 3/4、背面 | **备选，不默认** | 须下载权重 + 须授权 GPU | 只在 boat/battle 侧面/背面漂移时试；增加权重与姿态漂移风险 |
| Qwen Animal→Human / 宠物拟人 LoRA | RunningHub《Animal To Talking Human》· <https://www.runninghub.cn/post/1989526705981321218>；仓内 [COMFY-CAT-ANTHRO](COMFY-CAT-ANTHRO-COMMUNITY-2026-10-25.md) | 真宠→拟人已有可分享流水线；Qwen-Edit LoRA 生态活跃 | **可选，默认 OFF** | 须下载权重 + 须授权 GPU | license/质量未 vet；只在 portrait 连续 3 seed 仍不拟人时启用，强度 0.6–0.8 |
| Civitai「动物拟人」Illustrious LoRA | Civitai 2026-02-04 · <https://civitai.com/models/2364462/anthropomorphism> | 579.26 MB；Illustrious 2D 拟人概念 LoRA | **否决默认** | 须下载权重 | 2D/Illustrious 基座与写实 Qwen 不匹配；风格化会拉低「拟人可读」 |
| IP-Adapter FaceID / InstantID / PuLID | 2026 对比 · <https://aiofm.info/en/guides/pulid-vs-instantid-vs-faceid>；<https://github.com/SiddharthFulia/face-consistency-toolkit/blob/main/docs/IDENTITY-METHODS.md>；InstantID 维护停更 · <https://eastondev.com/blog/en/posts/ai/20260821-comfyui-face-identity-consistency> | 人脸 ID 强，但依赖 InsightFace/真人脸分布；InstantID 偏 SDXL 且 2025-04 起维护模式 | **否决默认** | 须下载权重 + 节点 | 真猫脸→拟人不是同一分布；只在人脸辅路实验，不进主链 |
| 多参考（正脸 + 侧脸 + 3/4 + 场景） | 仓内 CHARACTER-LOCK / COMFY-CAT-ANTHRO | 参考密度不足会削弱五官/毛色锁；多图优于单图 | **采用** | ¥0 | Phase 1 补 side/3/4 与场景参考；仍以 front 为 Image1 |
| 防四足塌缩（正向 upright + 负向 quadruped） | 仓内 COMFY-CAT-ANTHRO；masalib 2026-09 · <https://masalib.hatenablog.com/entry/2026/09/04/000000> | 真猫参考易塌回四足；需参考强度 + 提示词专项对抗 | **采用** | ¥0 | 正向写 upright bipedal；负向写 quadruped/feral/on all fours |
| Wan2.2 Animate 真猫动作迁移 | ComfyUI 官方 Wan2.2 Animate · <https://docs.comfy.org/tutorials/video/wan/wan2-2-animate>；masalib 2026-09 | 可锁毛色/瞳色，但二足易塌；新 14B 权重 | **不默认（v0.3 再评）** | 须下载十余–数十 GB + 须授权 GPU | 本版预算/时间不够；先榨干 Wan2.1 + FLF2V |

> 中文教程补充：知乎《Qwen Image Edit 本地部署 ComfyUI 教程》（2025-08-20，<https://zhuanlan.zhihu.com/p/1941561330537600404>）— 本地/fp8/多图编辑部署流程；本岗仅作部署核对，默认栈不变；¥0。

**一句话**：定妆主链仍是 **Qwen-2511 多图 + 三场景同身份 + 防四足**；Animal→Human / multi-angle 只作定点备选，IP-Adapter/InstantID/PuLID 不是真猫银弹。

### 4.2 Wan2.1 I2V / FLF2V：动作、长度、shift、负向、首末帧

| 社区做法 | 来源（2025–2026） | 要点 | 本岗 v0.2 默认采用？ | 代价 | 替代 / 否决理由 |
| --- | --- | --- | --- | --- | --- |
| 结构化 Wan prompt（80–120 词） | HF 论坛 2025-11 · <https://discuss.huggingface.co/t/how-to-get-the-most-out-of-prompts-for-wan-models/170354> | 写清角色数量、场景、镜头、动作时间线、动作边界；CFG=1 时负向弱，用正向约束兜底 | **采用** | ¥0 | 本仓 prompt 偏短；v0.2 每条补 count/camera/boundaries |
| Wan2.1 fp16 / 480p / FLF2V 720p | ComfyUI 官方 Wan2.1 · <https://docs.comfy.org/tutorials/video/wan/wan-video>；FLF2V · <https://docs.comfy.org/tutorials/video/wan/wan-flf> | fp16 优于 bf16；480p/720p 分模型；FLF2V 默认 720×1280 | **采用** | ¥0（现有权重）+ 须授权 GPU | I2V 480 草稿；FLF2V 仅 S04/S10 |
| 官方 `generate.py` steps=40 / shift=3 / frame=81 | Wan2.1 官方 · <https://github.com/Wan-Video/Wan2.1/blob/main/generate.py> | 官方质量档；480p shift=3 | **仅 hero 质量档，不默认** | 须授权 GPU | 成本高；本仓 20 steps/shift8 已用 R1 max_mad=16.27 校准动作 |
| kombitz：shift 3@480p、cfg≈5、length=49 | 仓内 [COMMUNITY-OPTIMIZE](COMMUNITY-OPTIMIZE-2026-10-25.md) · <https://www.kombitz.com/2025/03/03/simple-comfyui-workflow-for-wan2-1-image-to-video-i2v-using-gguf-models/> | 社区常用短片参数 | **仅回退** | 须授权 GPU | cfg/shift 已由动作门禁校准；不改默认 |
| Lightning CFG=1 会让负向失效；length=16f+1；shift 5–6 保表情 | Civitai 文章 · <https://civitai.com/articles/18711/wan-2122-comfyui-workflows-for-my-character-lora> | Lightning 省步数但限动作；负向需 NAG；I2V shift 可降 | **采用 Lightning OFF / length 公式 / shift 回退** | ¥0 | 不默认 Lightning；身份漂移时 shift 5–6，动作弱才 cfg5/shift10 |
| FLF2V 锁首末帧 | ComfyUI 官方 FLF2V · <https://docs.comfy.org/tutorials/video/wan/wan-flf>；HF 论坛 2025-11 | 用首末帧约束落点，避免随机漂移 | **采用 2 关键镜** | ¥0（现有 FLF2V 权重）+ 须授权 GPU | 仅 S04 门落、S10 插旗；其他镜不默认 |
| Wan2.2 I2V / Animate 代际升级 | ComfyUI 官方 Wan2.2 · <https://docs.comfy.org/tutorials/video/wan/wan2_2>；Animate · <https://docs.comfy.org/tutorials/video/wan/wan2-2-animate> | 新一代 I2V/动作迁移；权重十余–数十 GB | **延后 v0.3** | 须下载权重 + 须授权 GPU | 本版预算/时间不够；先做 v0.2 盲测再评 |
| 帧数 <120、草稿低分辨率、成片高分辨率、负向防抖 | Segmind 2026-01 · <https://blog.segmind.com/wan-i2v-prompts-tips-guide> | 控制单镜成本/随机性；负向写 unwanted camera shake | **采用** | ¥0 | 单镜 49/65 帧；草稿 480；FLF2V 720 |
| 首帧要清 + 边长 16 对齐 | Reddit WAN 2.2 cat · <https://www.reddit.com/r/StableDiffusion/comments/1nmjlwg/wan_22_cat/>；仓内 COMFY-CAT-ANTHRO | 首帧清晰度和对齐影响精细感 | **采用** | ¥0 | looklock≥1024；480×832；crop-check |
| 负向补 static/still/frozen | 仓内 [COMMUNITY-I2V-MOTION](COMMUNITY-I2V-MOTION-2026-10-25.md) · <https://docs.comfy.org/tutorials/video/wan/wan-video> | soft 词 + 缺 static + length33 是近静帧根因 | **采用** | ¥0 | 负向中英双语；length≥49；禁 gentle/slightly |

**一句话**：Wan2.1 仍是本版主力；v0.2 的关键不是换模型，而是 **结构化强动作 prompt + length≥49 + 2 条 FLF2V 锁落点 + 人眼运动验收**。

### 4.3 15s 竖屏 AI 卡点 MV：Hook → Payoff、刀数、SFX、字幕

| 社区做法 | 来源（2025–2026） | 要点 | 本岗 v0.2 默认采用？ | 代价 | 替代 / 否决理由 |
| --- | --- | --- | --- | --- | --- |
| Hook → Hold → Payoff 三拍 | veo3gen 2026-06 · <https://www.veo3gen.app/blog/the-hook-hold-payoff-3-beat-short-form-script-template-for-veo3gen-with-copy-pas>；technique.top 2026-02 · <https://technique.top/rapid-prototyping-guide-from-prompt-to-published-vertical-ep> | 0–3s 钩子，中段升级，末段 payoff；统一 LUT | **采用** | ¥0 | 本片 0–2s 变身钩子；10.8–15s 插旗/敬礼 payoff |
| 每 2/4 拍切，onset 检测而非只算 BPM | Cutflux 2026-06 · <https://cutflux.app/how-to-edit-to-the-beat.html> | 每拍切太密；累计漂移要用 onset；重拍切 | **采用** | ¥0 | 128 BPM 32 拍 → 10–14 刀；主卡点 3.75/7.97/10.78 |
| 3–6 个 SFX 点缀关键拍；BGM 首尾淡入淡出；静音也能读 | frame-smith · <https://github.com/mouse-lin/frame-smith/blob/main/.github/copilot-instructions.md> | 声音是成片的一半；SFX 与画面同帧 | **采用（最低 2，目标 3–5）** | ¥0 | 门落/水花/爆破/旗风/riser；不堆满 |
| 只用平台官方曲库 / 书面授权 / CC0 | 仓内 [COMMUNITY-OPTIMIZE](COMMUNITY-OPTIMIZE-2026-10-25.md) · IPRRR · 人民网 · SellerKitly | 「15s 不侵权」是误区；免版税≠免授权；不跨平台搬曲 | **采用** | ¥0（平台内）/ 可能须授权 | 保留凭证；授权不清就换 CC0 |
| 10–14 刀、每刀 1–2s、至少 1 个喘息镜 | 仓内 [V0.1F-PLAN](V0.1F-PLAN-2026-10-25.md) · bsquarevisuals 2025-12 · <https://bsquarevisuals.com/video-editing-trends-hyper-fast-cuts> | 快切堆密度，但要有呼吸 | **采用** | ¥0 | 12 刀；S03/S06 留 1.2–1.5s |
| 竖屏字幕/安全区，不挡脸 | Klap 2026-08 · <https://klap.app/blog/vertical-video-editing>；CapCut 2026 · <https://primalvideo.com/guides/capcut-for-pc-mac-tutorial> | 短行、强对比、避开脸/眼 | **采用** | ¥0 | 钩子/日期条/片尾 AI 标识 |
| 1080×1920 / 30fps 交付 | 仓内 V0.1F / ECHONOS | 一致性 > 分辨率，但 1080 是入门线 | **采用** | ¥0 | 最终只交 1080×1920 |

**一句话**：市面入门线卖的是「歌 + 踩点情绪 + 后期包装」；v0.2 不再用 CC0 战鼓拼接冒充成片，必须同包交付曲库/CC0 + 10–14 刀 + SFX + 字幕。

### 4.4 超分 / 锐化 / 1080 竖屏交付

| 社区做法 | 来源（2025–2026） | 要点 | 本岗 v0.2 默认采用？ | 代价 | 替代 / 否决理由 |
| --- | --- | --- | --- | --- | --- |
| 4× ESRGAN 类空间超分（4x-UltraSharp / ClearReality） | Comfy Hub 4x-UltraSharp · <https://comfy.org/hub/models/local/4x-ultrasharp>；仓内 COMFY-CAT-ANTHRO | 4× 放大后降采样，细节更稳 | **采用** | 须下载权重（百 MB 级）+ 须授权 GPU | 480×832→1920×3328→1080×1920；全片统一 |
| SeedVR2 3B one-step 视频超分 | ComfyUI 官方 2026 · <https://docs.comfy.org/tutorials/utility/seedvr2>；视频超分综述 · <https://docs.comfy.org/tutorials/utility/video-upscale> | 质量/时序一致性优先；10s 720p→1080 在 5090 约 312s | **A/B 备选，不默认** | 须下载权重 + 须授权 GPU | 新权重+慢；只在逐帧 4× 闪烁时试 |
| FlashVSR 快速视频超分 | ComfyUI 官方 2026 · <https://docs.comfy.org/tutorials/utility/video-upscale> | 速度优先；10s 720p→1080 约 41s（5090） | **A/B 备选，不默认** | 须下载权重 + 须授权 GPU | 4090 更慢；先 4×，闪烁再换 |
| RIFE 2–4× 补帧 | Civitai 2026-01 · <https://civitai.com/models/2341353/rife-vfi-video-interpolation-upscale-and-video-combine>；仓内 COMFY-CAT-ANTHRO | 16→30fps 平滑 | **可选，不默认** | 须下载权重 + 须授权 GPU | 只治卡顿，不伪造运动；运动弱先修 I2V |
| 4× 后降采样 + 轻锐化 + 统一 grade | 仓内 V0.1F / MARKET-GAP；ComfyUI 超分文档 | 避免直接放大糊；统一色感 | **采用** | ¥0 | 降采样到 1080×1920；轻 unsharp；不每镜换滤镜 |
| 响度 -14 LUFS / true peak | frame-smith 音效 skill · <https://github.com/whaleyxbt/claude-motion/blob/main/.claude/skills/sound-design/SKILL.md> | 成片响度统一，手机外放不炸 | **采用** | ¥0 | ffmpeg loudnorm；BGM 床 + SFX 短促 |
| 1080×1920 竖屏 + AI 标识 | 仓内 V0.1F / SERIES-WW2 | 平台入门交付规格 | **采用** | ¥0 | 30fps；H.264 high；AAC |

**一句话**：v0.2 的「精细」不是换一个更贵的模型，而是 **4× 超分 + 时间一致性检查 + 1080 降采样 + 统一 grade**；SeedVR2/FlashVSR 只作闪烁备选。

### 4.5 社区结论（默认采用 / 不采用）

**默认采用**：

1. Qwen-2511 多图三槽 + 多参考 + 防四足。
2. Wan2.1 fp16 480×832 + 强动作结构化 prompt + length≥49 + static 负向。
3. 2 条关键镜 FLF2V（门落/插旗）。
4. 4× 超分 → 1080×1920 → 统一 grade。
5. 平台曲库/CC0 + 10–14 刀 + SFX≥2 + 字幕/日期条。
6. H1–H4 人眼验收，不只 AUTO_QC。

**不默认 / 延后**：

1. IP-Adapter / InstantID / PuLID 作为真猫主链。
2. Animal→Human / multi-angle LoRA 默认开启。
3. Wan2.2 I2V/Animate 代际升级（v0.3 再评）。
4. Lightning / CFG=1 / 同参重抽。
5. SeedVR2/FlashVSR 作为唯一超分路径（先 4×，闪烁再 A/B）。
6. 三战役并行、银宝/墨墨扩角色、发布投流、NSFW。

## 5. 模板化清单

> 原则：能复用现有模板的不另起结构；本轮只改文档，**不新增 JSON/脚本**。下表标「已有」/「新建（Phase 0 后续）」，供下一轮直接落。

| 模板 / 文件 | 职责 | 状态 | v0.2 需要的改动 |
| --- | --- | --- | --- |
| `workflow/01_looklock_qwen_edit.json` | Qwen-2511 多图定妆图 | **已有** | 不改结构；确认三图槽与负向 |
| `workflow/01_looklock_api_slots.json` | 定妆槽位契约 | **已有** | 增加 `portrait` / `boat_ramp` / `battle` 三预设；optional LoRA 默认 OFF |
| `workflow/02_i2v_wan21_480p.json` | Wan2.1 I2V 图 | **已有** | 不改结构；length=49 默认 |
| `workflow/02_i2v_api_prompt_r1_r4.json` | I2V 参数/提示词槽 | **已有** | 增加 `v0_2_shot_presets`（S05–S09/S11）；每镜最多 2 seed |
| `workflow/03_flf2v_wan21.json` | Wan2.1 FLF2V 图 | **已有** | S04/S10 两关键镜启用；其他镜不默认 |
| `workflow/03_flf2v_api_slots.json` | FLF2V 首末帧/参数槽 | **新建** | 首帧/末帧路径、prompt、seed、length、gate |
| `workflow/04_upscale_4x_api_slots.json` | 4× 超分槽 | **已有** | 增加 4×→1080 策略、模型二选一、时序检查 |
| `scripts/upscale_4x.sh` | 超分封装 | **已有** | 增加批处理 + 1080 降采样 |
| `scripts/assemble_clip.py` / `scripts/ASSEMBLE.md` | 门禁/装配/状态 | **已有** | 增加 v0.2 shot manifest 与成片 H4 |
| `scripts/stitch_audio.py` / `scripts/AUDIO-SWAP.md` | 音频/合规 | **已有** | 平台曲库/CC0、-14 LUFS、SFX 清单 |
| `scripts/crop_check_i2v.py` | 构图裁切预览 | **已有** | 不改 |
| `scripts/looklock_size_gate.py` | 定妆短边≥1024 | **已有** | 不改 |
| `prompts/negative.txt` | 负向 | **已有** | 补 quadruped/extra limbs/face morph/text |
| `prompts/look_cards.md` | 角色固定前缀 | **已有** | 补三场景句与身份保留句 |
| `prompts/v0_2_shot_prompts.md` | 8 条主镜强动作 prompt | **新建** | 门落/涉水/烟/卧倒/爆破/抬头/插旗/敬礼 |
| `workflow/05_v0_2_shot_manifest.md` | 12 刀镜头表/状态/路径 | **新建** | 与 BEAT-SHEET/STORYBOARD 对齐 |
| `workflow/06_v0_2_human_acceptance.md` | H1–H4 人眼验收单 | **新建** | 逐镜签字；不替代 AUTO_QC |
| `reviews/V0.2-BLIND-TEST-2026-10-26.md` | 盲测问题单/结果 | **新建（Phase 4）** | 本岗小样本 + Opus rubric |
| `reviews/V0.2-RESULT-2026-10-26.md` | v0.2 结果/花费/结论 | **新建（Phase 3/4）** | 对标 v0.1g 与市面 5.5 |

**本轮不新增**：任何 JSON workflow、任何脚本、任何权重；只新建本规划 + 同步 3 个文档。Phase 0 的模板落地是下一轮 ¥0 工作。

## 6. 授权卡（给调度用，勿执行）

> 下面这段可直接发给用户请求一次授权。**本轮不执行**；未拿到授权前不开机、不充值、不 release。

```text
【v0.2 一次大改授权卡 · 复制给调度】

授权事项：一次性授权 Phase 1–3（三场景定妆 → 6 主镜 I2V + 2 关键镜 FLF2V → 4×超分 + 剪映卡点包装），同一台 4090 全流程；双机 race，任意时刻只开一台，跑完 shutdown 留盘。

软顶：总额 ≤¥4.90（P1 ≤¥1.30 / P2 ≤¥3.00 / P3 ≤¥0.60）；累计 >¥4.60 停并回报；余额现约 ¥5.37。完整包估算 ¥4.3–7.6，上界超余额。

充值：若调度判断完整包需超 ¥4.90，必须先在 Phase 1 前停下请求充值授权（建议 +¥5，以控制台为准）；不得先跑后补、不得静默透支。若只批 ¥4.90，则只跑压缩版并标 v0.2-limited。

不做：不 release、不删盘、不发布/投流、不 NSFW、不扩银宝/墨墨、不同参重抽刷分、不把 v0.1h 小修当默认。

回报：每阶段花费/余额/输出路径/门禁/H1–H4 人眼验收；触软顶立即停。
```

## 7. 明确废弃

以下口径 **一律作废**，不得再写成推荐默认：

- [ ] **v0.1h 仅剪映小修**：不再作为下一发布目标；下一目标是完整 v0.2 大改包。
- [ ] **每轮只动一项**：不再作为默认节奏；v0.2 一次打包 A–F 六项。
- [ ] **同参重抽碰运气**：每镜最多 2 seed；失败两次换策略，不刷 seed。
- [ ] **克隆/母机任务分流**：继续执行 t60u「双机全栈对齐、谁抢到谁全干、另一台关机」。
- [ ] **先 ¥0 剪映再议开机**：t62u 已否决为默认路径；v0.2 是「一次授权大改」，不是「先小修再看」。
- [ ] **把 AUTO_QC_PASS / RENDER_DONE 当可用**：只有 HUMAN_ACCEPTED 可进时间线。
- [ ] **把 CC0 战鼓拼接中间态当 v0.2**：包装未完成最多叫 v0.2-draft。
- [ ] **IP-Adapter / InstantID / PuLID 当真猫银弹**：不作为主链默认。
- [ ] **Lightning 默认 ON / CFG=1 负向**：默认 OFF；负向失效时不拿它当质量档。
- [ ] **三战役并行 / 扩银宝墨墨**：本版单猫小橘；二期再议。
- [ ] **充值 / 发布 / 投流 / NSFW**：一律不在本授权内；须用户另批。
- [ ] **force push / 未审 merge**：PR #84 同分支普通 push；merge 须用户审 diff。

> 注：旧 v0.1g 的「FLF2V 一律禁」不是全盘作废，而是改为 **仅 S04 门落、S10 插旗两关键镜解除**；其他镜仍不默认 FLF2V。旧 BOOT 的「单轮 ≤¥1.5」也不再适用 v0.2；v0.2 预算以 §3.6 与授权卡为准。

## 8. 风险与止损

| 风险 | 触发信号 | 止损 | 回退 |
| --- | --- | --- | --- |
| 预算超支 | 累计 >¥4.60 | 停跑、回报余额/花费 | 压缩版或等充值授权 |
| 定妆身份漂移 | 三场景认不出同一只猫 | 停 I2V | 回 Phase 1，最多 3 seed；再不行试 LoRA |
| 动作仍静帧 | H2 不过 / 动作读不出 | 停该镜 | 换 FLF2V/首帧/静帧+Ken Burns；不重抽 |
| FLF2V 崩 | 首末帧 morph/多肢 | 停该镜 | 回 I2V + 静帧；修首末帧 |
| 超分闪烁 | 抽帧 SSIM 跳变/目检闪 | 停该镜 | SeedVR2/FlashVSR A/B 或 2×+锐化 |
| 曲库授权不清 | 无法出示授权/凭证 | 不合成 | 换 CC0；不得跨平台搬曲 |
| 指标假阳性 | AUTO_QC 过但人眼不过 | 以人眼为准 | H1–H4 不过即 FAIL |
| 范围膨胀 | 想加银宝/墨墨/三战役 | 拒绝 | 二期另批；本版只小橘 |

## 9. 本轮文档变更与下一步

**本轮已做（Phase 0 文档部分）**：

1. 新建本文件：问题树、v0.2 范围、Phase 0–4、社区对照、模板清单、授权卡、废弃清单。
2. `PROGRESS.md` 追加段 28（2026-10-26）：t62u 决策 + 指向本文件 + 废止 v0.1h 默认。
3. `BOOT-v0.1g.md` / `NEXT-BOOT-CHECKLIST.md` 顶部加「下次开机默认 v0.2 大改包，不按 v0.1h」。
4. 跑 `smoke_test.sh --dry-run` 确认文档改动不破坏离线验收。

**本轮未做**：

- 未开机、未充值、未 release、未删盘；未下载任何权重；未跑 GPU。
- 未新增 JSON/脚本；未碰 `ai-realistic-comic/` 或 NSFW；未用 grok CLI。
- 未发布、未投流、未 merge。

**下一步（须用户授权）**：

1. 用户确认授权卡：充值授权或接受 `v0.2-limited`。
2. Phase 0 补模板（¥0）：`01/02/03/04` 槽位、`05` shot manifest、`06` H1–H4 验收单、`prompts/v0_2_shot_prompts.md`。
3. 授权后进入 Phase 1；未授权前保持关机留盘。

## 10. 现有 Notion 链接（只引用，不新建分页）

- 进度页：<https://app.notion.com/p/402b407a692a813c95dfe8301f82573f>
- v0.1g 本岗自评：<https://app.notion.com/p/404b407a692a81e59f09ef0e8e296a0a>
- Opus 市面 5.5（前序 v0.1e 口径）：<https://app.notion.com/p/8d13d54360d2496cabd7c68b123dee6b>
- Opus v0.1c 6.6：<https://app.notion.com/p/bdddad714fab464d8121c23471f42977>
- v0.1d 方案：<https://app.notion.com/p/404b407a692a81e5ab71ec3656b50a99>
- v0.1e 成片：<https://app.notion.com/p/404b407a692a81e0a961cbfecbb4cd09>
- v0.1c R4：<https://app.notion.com/p/404b407a692a8125a4e9f1d2e28590b0>
- v0.1c 自评：<https://app.notion.com/p/404b407a692a81bb8a63cd0796e03d30>

> 本文件不新增 Notion 子页；Phase 3/4 结果回写现有进度/评审页。
