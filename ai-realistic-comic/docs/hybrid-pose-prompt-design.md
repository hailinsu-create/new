# 混合姿势控制 + 长提示词设计（VNCCS × 现有 R4）

2026-10-14 起稿。**本文只做设计与安装/花费预估，不开 AutoDL、不下载权重、不嵌入裸图。**

借鉴公开 skill 仓库 [Arekejoker/qwen21-nsfw-pose-skill](https://github.com/Arekejoker/qwen21-nsfw-pose-skill)（README / `SKILL.md` / `install/setup.md` / `workflows/`），把其 **VNCCS 136 姿势 3D 人偶精确姿势** 与 **作者级长提示词（7 要素 / L0–L3）** 接到本仓狐/马去衣栈上；奇幻身体（九尾狐林晚棠、半人马伊莲）**不能**套标准人体人偶，继续走现有 **Cursor GenerateImage 穿衣底板 → 用户锁定 → R4 Qwen-Image-Edit-2511 FP8 + 去衣 LoRA**（见姊妹文档 `fox-undress-r4-standard.md`，在 `cursor/fox-centaur-r1fix-community-rescan-dbe2` 等后续分支；本分支历史见 `fox-centaur-semantic-undress.md`）。

上游元数据（GitHub API，2026-10-14）：`created_at=2026-10-13T03:09:42Z`（约 1 天前），`license=null`（页面未声明 SPDX）。README 自称 2026-10-12 复刻过 Civitai 作者样图；**本仓未独立复跑验证**。

---

## 1. 目标与非目标

| 要 | 不要 |
| --- | --- |
| 纯人体姿势：用 VNCCS 136 库精确摆姿出穿衣底板，再按需 Edit / R4 | 把 MakeHuman/VNCCS 人偶硬套半人马/九尾狐身体 |
| 奇幻女主：保留 GenerateImage 锁板 + R4 去衣/破衣 | 为「跟上游配方」默默关掉 NSFW LoRA 或砍短提示词 |
| 双人：男配可走人体姿势库；女主奇幻身体走我们的；男配**不锁**形象 | 两机同时开机；超 `spend_cap` / 无看门狗挂机观感 |
| 长提示词结构同时服务「穿衣底板」与「破衣步」（解决撕不够） | 本文授权开机、上传/嵌入裸图、花钱下载 |

---

## 2. 路由规则（决策表）

### 2.1 单人

| 主体 | 身体类型 | 穿衣底板怎么出 | 去衣 / 破衣 |
| --- | --- | --- | --- |
| 标准人体女演员 / 男演员 | 双腿人体，人偶可套 | **Route V**：VNCCS PoseStudio（136 姿势 JSON）+ 角色参考图 → 穿衣底板；可选上游 Route ② Edit 换姿势保脸衣 | 人体向：可试上游 Qwen-Image 2.1 Edit + `qwen21-nsfw-image-edit`；或并入本仓 R4（若已装 Edit-2511） |
| 林晚棠（九尾狐） | 奇幻（多尾） | **Route F**：Cursor **GenerateImage** 多候选 → 用户写入 `USER_LOCKED` / `POSE_LOCKED` | **仅 R4**：Qwen-Image-Edit-2511 FP8 + remove/torn LoRA；正式库收 raw |
| 伊莲（半人马） | 奇幻（马身） | **Route F**（同上） | **仅 R4**；马身/接缝规则仍按 R4 标准，禁止回退 Fooocus 甲壳 inpaint |

**判定启发式：**

1. 若 DWPose / OpenPose 能给出**单一连贯人体骨架**且无额外非人肢体必须保留 → 可走 VNCCS。
2. 若画面语义依赖**尾/马身/非人下盘**且人偶网格无对应骨骼 → **强制 Route F**，VNCCS 最多只服务同框男配。
3. 「已有角色图只换姿势」且为人体 → 上游 Route ② Edit；奇幻身体 → 重新 GenerateImage 锁板，或 R4 指令编辑（姿势漂移风险高，需用户再锁）。

### 2.2 双人（女主奇幻 + 男配人体）

| 角色 | 形象锁定 | 姿势来源 | 去衣范围 |
| --- | --- | --- | --- |
| 女主（林 / 伊莲） | 用户锁定的穿衣底板（脸、戏服、尾/马身、构图） | GenerateImage 候选；**不**走 VNCCS 人偶 | R4 **只改女主衣物** |
| 男配（顾承安等） | **成衣阶段不锁**形象/衣服；按女主画面氛围配合 | 男配为标准人体时，可用 VNCCS 姿势族定骨架，再合成进 GenerateImage 提示或二次合成；定稿后底板内男配随板锁定 | R4 **不改**男配脸/姿势/衣服/手 |

流程顺序（与 R4 情侣变体一致）：

1. 离线出穿衣候选（女主 Route F；男配可先 VNCCS 出姿再写进提示）。
2. 用户挑定 → 写 `POSE_LOCKED.json` / `USER_LOCKED` 板。
3. **另授权**后互斥开机跑 R4；未锁板禁止开机。

### 2.3 与上游三条路线的映射

| 上游 | 本仓用法 |
| --- | --- |
| ① T2I + NSFW LoRA | 仅**纯人体、从零 NSFW** 试点；狐/马成衣仍 GenerateImage |
| ② Edit | 人体换姿保身份；奇幻身体谨慎，默认不替代锁板 |
| ④ VNCCS PoseStudio | **纯人体底板**主路径；浏览器 CDP 跑 `VNCCS_PoseStudio_QI2.1.json` |

---

## 3. 长提示词结构（7 要素）如何接到穿衣底板与破衣

上游强制：**写满 7 要素、约 300–1500 字符、含 LoRA 触发词**；分工口诀：**LoRA 管质感，提示词管信息密度，机位管大胆度**。采样侧参考：`er_sde` + `beta`，CFG 2.5（Edit 常用 3），50 步 T2I / 较短 Edit，竖版 1152×1728（上游）；本仓 R4 仍用既定 4 steps / cfg 1.0 / Lightning，**不要混用采样配方**，只复用**提示词结构与 L 阶梯**。

### 3.1 七要素（顺序固定）

1. **Camera**：镜头与角度（low-angle / eye-level / overhead；lens 语气）
2. **Subject**：年龄感、体型、发型发色与干湿状态（奇幻角色加尾数/马身毛色，但 VNCCS 路径勿写非人肢体）
3. **Pose**：L0–L3 选一档，**逐肢**写清（哪条腿屈、手位置、头/视线）
4. **Setting + lighting**：场景与光（蒸汽、霓虹 bokeh、窗帘晨光等）
5. **Skin / material**：皮肤质感或戏服材质（旗袍缎面、铠甲高光——成衣步写材质，破衣步改为皮肤/破口）
6. **Anatomy / reveal 或 garment damage**：成衣步写服装闭合与褶皱；破衣步写**撕裂几何与露出区域**（见 §3.3）
7. **Finish**：`8k`、cinematic lighting、candid atmosphere、photorealistic anatomy（或 photoreal fabric）

模板（改写自上游，成衣示例骨架）：

```text
A hyper-realistic, {camera} shot of {subject with hair/wardrobe/fantasy limbs if Route F},
{one L-tier pose, limb by limb}. {Setting + lighting}.
{Skin or fabric material density}. {Wardrobe closed-state OR tear/reveal geometry}.
{face/expression}. 8k resolution, cinematic lighting, candid "caught in the moment"
atmosphere, photorealistic {anatomy|fabric}.
```

**LoRA 触发词：** 跟所用 Civitai/HF 卡片；默认人体 T2I 用 `femaledVaginus` 系文件名对应触发（以模型页为准）。R4 去衣 LoRA 继续用本仓既有触发句（如 remove-clothes 系），**不要**把上游 T2I 触发词塞进 Edit-2511 图除非 A/B 证明有效。

### 3.2 L0–L3 大胆度阶梯（姿势 × 机位 × 着装态）

| 档 | 着装/暴露 | 姿势族（VNCCS / 文案） | 机位 |
| --- | --- | --- | --- |
| **L0** | 全着装、编辑感 | Standing / Sitting / Walking；重心单腿、手插袋、踝交叉坐 | 平视为主 |
| **L1** | 泳装/湿身/松弛 | Squatting / Kneeling / Laying Back；膝分开蹲、侧卧撑肘 | 可略低 |
| **L2** | 大胆 / 作者向 NSFW | Kneeling / Prone / Splits / Crawling…；分腿、塌腰、低机位 | **低机位 ≈ +1 档** |
| **L3** | 极端/裁切 | L2 族 + 极低仰视或俯视分腿 + 腰上/大腿裁切 | 极低或 overhead |

规则（上游经验，纳入本仓）：

- 先定暴露态再选档；**L0 姿势 + NSFW LoRA** 是「平淡 NSFW」最常见原因。
- 低机位约 +1 大胆度；「低机位 + L1」≈「平视 + L2」。
- 一条提示词只写一个姿势；两套姿势描述会糊成平均态。

### 3.3 破衣步：为什么「一直撕不够」，提示词怎么加码

痛点（本仓已观察）：R4 / 编辑器常 **MODEL_KEEP** 腰缝、护腕、甲缘；短促「torn clothes」信息密度不够，模型优先保结构高光。

**破衣提示词加码（仍走七要素，第 6 点加重）：**

- 写清**破口拓扑**：哪片布/甲从哪条缝裂开、碎片挂在哪个关节、露出哪块皮肤、哪些区域必须消失（fauld、gorget、gauntlet）。
- 用**可检验的几何词**：`fabric peeled below the sternum`, `armor plates hanging from one pauldron only`, `large irregular holes at midriff with frayed edges` —— 避免只写 `damaged` / `sexy torn`。
- **机位**服务破口可见性（L2 低机位看腰腹破口；平视易被衣褶挡住）。
- **LoRA**：破衣用 torn/remove 系；质感 LoRA 不要替代「破口几何」句子。
- **阶梯**：成衣板 L0/L1 锁姿 → 破衣编辑提示升到 L2 的**暴露描述**，但**姿势句与底板姿势一致**（只升级 reveal，不升级成另一套pose，除非用户重锁板）。
- 仍失败时：加宽蒙版 / 多 seed / 接缝策略（见 Elena torn seam 试点），**不是**再叠一层空泛形容词。

成衣底板（GenerateImage 或 VNCCS）用 L0–L1 七要素写满服装与姿势；破衣步**复用 1–5 与姿势肢位**，重写 6（damage/reveal）并视需要加强 1（机位）。

---

## 4. 791 / 592 安装清单与体积（对照约 96G 空余）

数据来源：上游 `install/setup.md` + HF API `Comfy-Org/Qwen-Image-2.1` 文件 size（字节，2026-10-14 查询）；592 余盘引用本仓 R5 试点记录 **150G 盘 / 用 55G / 余 96G**（`df` 快照，见 `fox-centaur-semantic-undress` 在后续提交中的记载）。**本轮未开机复测 df。**

### 4.1 Qwen-Image 2.1 int8 底模（路线①②④共用）

| 文件 | 字节 (HF) | ≈ GiB |
| --- | --- | --- |
| `diffusion_models/qwen_image_2.1_int8_convrot.safetensors` | 7 256 783 064 | **6.76** |
| `text_encoders/qwen3vl_8b_int8_convrot.safetensors` | 9 350 798 360 | **8.71** |
| `vae/qwen_image_2.1_vae_bf16.safetensors` | 675 509 688 | **0.63** |
| **小计** | | **≈ 16.10 GiB** |

### 4.2 LoRA（按路线选装）

| 文件 | 大小（上游表） | 路线 |
| --- | --- | --- |
| `qwen2_1-femaledVaginus-nsfw-v1_3-fine_L22-31.safetensors` | 608M | ① 默认 |
| `qwen2_1-femaledVaginus-nsfw-v1.3-fine.safetensors` | 608M | ① 备选 |
| `thesealpacas-nsfw-v2.safetensors` | 79.7M | ① 最露 |
| `nsfw-posture-v3.safetensors` | 84M | ① 姿势增强 |
| `qwen21-nsfw-image-edit.safetensors` | 84M | ② |
| `VNCCS_QI2_PoseStudioV1.1.safetensors` | 159M（HF 159 436 408 B） | ④ |
| **若全装** | | **≈ 1.6 GiB** |

### 4.3 节点与姿势库

- **ComfyUI_VNCCS_Utils**（`AHEKOT/ComfyUI_VNCCS_Utils`）：git clone + `pytorch-lightning` / `roma` / `dynamicprompts`；体积相对权重可忽略（百 MB 级依赖另计）。
- **姿势库**：HF 四仓（General / Ballet / VNCCS_Main / MySuperPose）+ 包内 55 精选 → **136** 姿势；含 JSON + webp 预览。粗估 **约 0.5–3 GiB**（视预览分辨率；首次 `repositories/refresh` 拉取）。
- **路线④浏览器**：Playwright Chromium（CDP）；另计数百 MB～1 GiB。

### 4.4 与现有 R4 栈的关系（592 已有 Edit-2511 ≈31.55GB）

| 方案 | 新增盘估 | 592 余 ~96G？ | 说明 |
| --- | --- | --- | --- |
| **A. 最小 VNCCS 试点** | 底模 16.1 + VNCCS LoRA 0.16 + 节点/姿势库 ~1–3 ≈ **18–20 GiB** | **够**（余 ~76–78G） | 可与 R4 并存；注意勿与 Edit-2511 同时占满 VRAM |
| **B. 上游配方全量 LoRA** | A + 其余 NSFW LoRA ≈ **+1.4 GiB** → **~20–22 GiB** | **够** | 仍远小于昔日 Fill ~33GB |
| **C. 只借鉴提示词/L 阶梯，不装 2.1** | **0** | 够 | 狐/马继续 GenerateImage+R4；人体姿势仍弱 |

**791：** 作母机/真源时可装同一套后经中转清单同步到 592；互斥下优先在**已有 R4 权重的 592** 出图，避免 791 冷启动下载烧钱（与 dual-couple「prefer 592」一致）。

**VRAM：** 上游称 50 步 1152×1728 int8 约 200–400s；5090 可跑，但 **Qwen 2.1 与 Edit-2511 FP8 不要同时常驻**——A/B 时应卸载一侧。

---

## 5. 小规模 A/B 对照：GPU 时长与花费预估

约束（硬）：

- **两机不同开**（mutex；`ensure_peer_shutdown`）。
- **`8f803c1` `spend_cap.py`**：钱包差额与**墙钟投影 GPU**（默认 2880 厘/时 = **¥2.88/h**）取大，另计盘费 reserve（默认约 **¥1.40**）。
- **`autodl_watchdog`**：独立进程；信号 / `finally` / atexit → `shutdown_fleet`；禁止为观感挂机。
- 本设计文档**不授权**开机；下列为**若**用户另授权时的预估。

### 5.1 建议最小 A/B 矩阵（人体受试，不动狐/马正式库）

| # | 臂 | 目的 | 单次耗时（上游/经验） |
| --- | --- | --- | --- |
| 1 | VNCCS × 3 姿势（L0/L1/L2 各一）出穿衣底板 | 姿势保真 | ~60–90 s/张 → **~5–8 min** |
| 2 | 同角色参考 Route ② Edit 换姿 × 2 | 保脸衣 | ~60–120 s/张 → **~3–5 min** |
| 3 | 可选：同姿态短提示 vs 七要素长提示 T2I × 2 | 信息密度 | ~200–400 s/张 → **~8–15 min** |
| — | 首次下载底模+LoRA+姿势库 | 安装 | **~15–40 min**（带宽变） |

**合计冷启动：** 安装 + 矩阵 ≈ **40–70 min** 墙钟。  
**合计热启动（权重已在盘）：** ≈ **20–30 min**。

### 5.2 花费（¥2.88/h + 盘 reserve）

| 场景 | GPU 投影 | + disk reserve | 建议授权封顶 |
| --- | --- | --- | --- |
| 热启动小 A/B（25 min） | ≈ ¥1.20 | ≈ ¥1.40 → **有效 ~¥2.6** | **≤ ¥3** |
| 冷启动含下载（60 min） | ≈ ¥2.88 | ≈ ¥1.40 → **有效 ~¥4.3** | **≤ ¥5**（需用户明示） |
| 只跑 3 张 VNCCS（10 min） | ≈ ¥0.48 | ≈ ¥1.40 → **有效 ~¥1.9** | **≤ ¥3** |

狐/马破衣提示词 A/B（同 USER_LOCKED 板、多 seed、只改第 6 要素）应走**现有 R4**，不强制装 Qwen 2.1；时长接近既有 dual-couple 单张（数分钟级），封顶仍按当次授权（常见 ≤¥3）。

---

## 6. 风险与阻塞点

| 风险 | 级别 | 说明 |
| --- | --- | --- |
| 上游仓库过新 | 高 | 创建于 **2026-10-13**；本仓未复跑 `doctor.py` / 作者淋浴案 |
| **无 SPDX / license=null** | 高 | 权重版权归 HF/Civitai 原作者；skill 仓库本身许可未声明 → **商用/再分发前需人工确认** |
| 奇幻身体不适用人偶 | 高（已知） | 半人马/九尾狐 → 路由强制 F；违反则解剖崩（R3 双头史） |
| 底模双栈盘/显存 | 中 | 2.1 int8 (~16G) + R4 (~32G) 盘上可并存于 96G 余量；VRAM 需串行 |
| Civitai LoRA 条款 | 中 | NSFW 权重需遵守各模型页许可；部分地区/平台分发敏感 |
| 破衣仍 KEEP | 中 | 长提示词加重破口几何是必要非充分；接缝/蒙版策略仍要 |
| 路线④依赖浏览器 CDP | 中 | headless API live capture 超时；需 Playwright/CDP |
| 许可与样例图 | 低（本文） | 本文不嵌入裸图；跟跑上游 README 样例时注意仓库含 NSFW 展示图 |

**当前阻塞点（在授权任何安装/A/B 之前）：**

1. 用户确认可接受上游 **无 license** 与第三方 LoRA 条款，仅限私有机试验。  
2. 明确 A/B 封顶（建议热启动 **¥3** / 冷启动 **¥5**）并启用 `spend_cap` + watchdog。  
3. 592 开机后先 `df` 复核余盘（历史 96G 可能已变）。  
4. 狐/马正式仍片**不**纳入 VNCCS 试点范围。

---

## 7. 推荐落地顺序（仍须另授权）

1. **零成本**：把七要素 + L 阶梯写入 GenerateImage 成衣提示与 R4 破衣提示模板（方案 C）。  
2. **低成本热 A/B**（若 592 已有空位）：只装 VNCCS 节点 + 姿势库 + 最小 LoRA，用**人体**受试验证 Route V。  
3. 验证通过后，双人流程中男配姿势可切 VNCCS；女主保持 Route F + R4。  
4. 全文装 Qwen-Image 2.1 仅在需要上游 T2I 质感对照时再做。

---

## 8. 参考

- 上游：https://github.com/Arekejoker/qwen21-nsfw-pose-skill （`SKILL.md` §1–4，`install/setup.md`，`workflows/qwen21_*.json`，`VNCCS_PoseStudio_QI2.1.json`）
- 本仓：`docs/fox-centaur-semantic-undress.md`；R4 标准 / `spend_cap` / watchdog（后续分支上的 `fox-undress-r4-standard.md`、`autodl-shutdown-watchdog.md`、`workflows/comfyui/spend_cap.py`）
- HF 底模：`Comfy-Org/Qwen-Image-2.1`；VNCCS LoRA：`MIUProject/VNCCS_PoseStudio_QI2.1`；节点：`AHEKOT/ComfyUI_VNCCS_Utils`
