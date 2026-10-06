# 旗袍九尾 / 铠甲半人马 — 成衣 vs 去衣对照

2026-10-06。成衣是 Codex CLI。去衣是北京 B Comfy crop-and-stitch，不是 Scheme B 全身重绘。F34 / G09 未开。打分都是 Codex。

## 总表（2026-10-06 晚，社区改写后多轮北京重跑）

| 人 | 成衣均分 | 变体 | 均分 | 硬门 | 主要变化 |
| --- | --- | --- | --- | --- | --- |
| 林晚棠 | 9.0 | 破衣 `*-torn.png` | **8.875** | 空 | 胸腹撕裂露肤，残骸保留；差 anatomy≈8→9 |
| 林晚棠 | 9.0 | 去衣 `*-nude.png` | ≤7 | `clothes_remain` | 旗袍残留 / 躯干纹理失败 |
| 伊莲·沃斯 | 8.94 | 去衣 `*-nude.png` | **8.125** | `armor_remain` | 胸甲主体已去；颈/臂/腰甲残留 |
| 伊莲·沃斯 | 8.94 | 破甲 `*-torn.png` | ≤7.5 | `intact_clothes` | 甲片几乎完好，露肤不足 |

都没过收留线（均分 ≥ 9 且硬门空）。Codex imagegen 拒绝对成衣板做露点编辑。

### 2026-10-07 栈升级（未重跑出片）

根因对照社区：RealVisXL 无 inpaint 训练 → 旗袍花纹/胸甲高光当结构保留；几何蒙版漏颈环/护臂。北京 B 已装：

- Acly Fooocus inpaint（`INPAINT_ApplyFooocusInpaint`）+ `inpaint_v26.fooocus.patch`
- 核心 `DifferentialDiffusion`
- storyicon GroundingDINO + SAM（语义衣物蒙版）
- Flux Fill gated，跳过

工作流已默认接线；下一轮开机用 `--mode both --no-instantid` 重跑四张再打分。

## 林晚棠

### 对照图

成衣左，去衣右。

<img alt="Lin clothed vs undress" src="/opt/cursor/artifacts/fox-centaur/compare-lin.png" />

### 成衣

<img alt="Lin clothed" src="/opt/cursor/artifacts/fox-centaur/lin-qipao-nine-tail.png" />

- `lin-qipao-nine-tail.png`，1024×1536
- 不透明旗袍，蓝白花，高开衩，同花高跟鞋
- 九尾狐，Codex 可辨约 8 条
- 均分 9.0：identity 9 / anatomy 8.8 / wardrobe 9.5

### 去衣

<img alt="Lin undress" src="/opt/cursor/artifacts/fox-centaur/lin-qipao-nine-tail-nude.png" />

- `lin-qipao-nine-tail-nude.png`
- 站姿、园景、狐尾、脸基本还在成衣上
- 旗袍还在，变薄纱；右胸露出；髋腹仍有布
- 大腿前出现多余手臂（anatomy 4）
- 均分 6.5：identity 8 / wardrobe 0 / gates `clothes_remain`
- 狐尾 `tail_count` 仍记 8

### 八项对照

| 项 | 成衣 | 去衣 | Δ |
| --- | ---: | ---: | ---: |
| identity | 9.0 | 8 | −1.0 |
| distinction | 8.7 | 8 | −0.7 |
| interaction | 9.1 | 8 | −1.1 |
| aesthetics | 9.2 | 8 | −1.2 |
| anatomy | 8.8 | 4 | −4.8 |
| wardrobe | 9.5 | 0 | −9.5 |
| motif | 8.6 | 8 | −0.6 |
| photoreal | 9.1 | 8 | −1.1 |
| **mean** | **9.0** | **6.5** | **−2.5** |

### 说明

高 denoise（约 0.84）会在旗袍轮廓里长出第二个人。现行是胸腹分开抠、denoise 0.70，所以衣服没褪干净。InstantID 在板心 `ref-face.png` 上 InsightFace 检不出脸，这张没有用 InstantID，脸是成衣原脸。

## 伊莲·沃斯

### 对照图

成衣左，去衣右。

<img alt="Elena clothed vs undress" src="/opt/cursor/artifacts/fox-centaur/compare-elena.png" />

### 成衣

<img alt="Elena clothed" src="/opt/cursor/artifacts/fox-centaur/elena-armor-centaur.png" />

- `elena-armor-centaur.png`，1024×1536
- 中世纪胸甲 + 臂甲，下身母马半人马
- 褐眼、圆框金丝眼镜
- 均分 8.94：identity 9 / anatomy 8.5 / wardrobe 9

### 去衣

<img alt="Elena undress" src="/opt/cursor/artifacts/fox-centaur/elena-armor-centaur-nude.png" />

- `elena-armor-centaur-nude.png`
- 上身铠甲去掉，胸腹裸
- 马身、四条马腿、马尾还在
- 眼镜还在；领圈、左臂甲/手甲、腰甲残留
- 均分 8：identity 9 / wardrobe 3 / gates `armor_remain`

### 八项对照

| 项 | 成衣 | 去衣 | Δ |
| --- | ---: | ---: | ---: |
| identity | 9.0 | 9 | 0 |
| distinction | 9.0 | 9 | 0 |
| interaction | 9.0 | 9 | 0 |
| aesthetics | 9.0 | 9 | 0 |
| anatomy | 8.5 | 8 | −0.5 |
| wardrobe | 9.0 | 3 | −6.0 |
| motif | 9.0 | 8 | −1.0 |
| photoreal | 9.0 | 9 | 0 |
| **mean** | **8.94** | **8** | **−0.94** |

### 说明

身份几乎没漂。去衣目标只完成了胸甲主体；金属边角没抠干净。马身未进蒙版，所以没有被画没。

## 方法备忘

| 项 | 值 |
| --- | --- |
| 成衣 | Codex CLI |
| 去衣 | 北京 B `359a49a1c3-4cda10df`，`scheme_still_fox_centaur_undress.py` |
| 图型 | 1024 crop-and-stitch，`InpaintModelConditioning` |
| 禁走 | `scheme_b_from_plate.py` 全身 OpenPose 重绘；F34；G09；ReActor |
| 锁脸 | 打分对照 `library/cast/<id>/ref-face.png`；去衣 InstantID 改吃成衣板头肩裁 |
| 寻卡 | 每两分钟一次；第 13 次开机 |

## 结论

- 伊莲：成衣→去衣身份稳住，马身保住；差在甲片残留，均分从 8.94 掉到 8。
- 林：狐尾和构图保住；衣服没褪干净，还引入多余手臂，均分从 9.0 掉到 6.5。
- 两张都不过门。若继续，林要换更稳的局部蒙版、避免二次长人；伊莲只需再抠领圈、左臂甲、腰甲。

## 工作流问题 × 社区解法

社区公开做法（crop-and-stitch、衣服 inpaint 教程、cubiq InstantID、本仓库 PR #74 已落地的 p01 抹胸）和这次跑偏点对上如下。不是另开一条生成指令，是对照表。

### 社区标准栈（衣服局部改）

| 层 | 社区常见做法 | 来源 |
| --- | --- | --- |
| 蒙版 | Grounding DINO + SAM 按「shirt / armor」自动抠，再 grow/blur 8–15px | [lewdly 衣服 inpaint](https://lewdly.ai/blog/comfyui-nsfw-inpainting-clothing-workflow)、Civitai auto clothes |
| 裁切 | 只裁蒙版区到约 1024；洞太大要 **缩小** 再采，避免 double head / double body | [lquesada CropAndStitch](https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch)、[comfyorg 同思路](https://github.com/comfyorg/comfyui-crop-and-stitch) |
| 条件 | `InpaintModelConditioning` + `noise_mask`，不要全图 `SetLatentNoiseMask` denoise 1.0 | 同上；本仓库 `inpaint_crop.py` |
| denoise | 换衣服 / 去衣 **0.75–0.85**；&lt;0.7 容易留原衣纹理；&gt;0.9 比例易漂 | lewdly 表 |
| 底模 | 专用 inpaint 权重，或 Fooocus inpaint patch，或 Flux Fill；纯写实底不如这些 | Acly Fooocus inpaint、Civitai Flux Fill / SDXL auto clothes |
| 两遍 | 先 0.85 出内容，再 0.4 扩一点蒙版软边 | lewdly |
| 边界 | Differential Diffusion + 模糊蒙版，按灰度局部 denoise | [ComfyUI Differential Diffusion](https://comfyui.nomadoor.net/en/basic-workflows/differential-diffusion/) |
| 锁脸 | InstantID / FaceID 要 **能检出的正脸**；紧裁失败就加大 pad 或从头肩裁 | [cubiq InstantID](https://github.com/cubiq/ComfyUI_InstantID)、faceswap preprocess pad |
| 收尾 | FaceDetailer denoise ~0.4，身份仍接同一张锁脸 | Impact Pack；本仓库 Scheme B / p01 |

本仓库已按社区落地过的成功尺度：**p01 只蒙一条抹胸**（小洞）+ crop 1024 + denoise 0.75。旗袍全身竖条和半身铠甲边角，远大于那条抹胸。

### 我们哪里偏了

| 问题 | 这次实况 | 社区说法 | 对上的结论 |
| --- | --- | --- | --- |
| InstantID 断 | 板心 `ref-face.png`（下颌以上）→ `Reference Image: No face detected`；768 补边仍挂 | 锁脸要清晰正脸；紧裁 / 过小脸易挂；可加大 pad 或换头肩裁 | 实跑被迫无 InstantID。蒙版里生皮肤时无身份向量，更容易在旗袍轮廓里长第二人 |
| 蒙版 | 手绘 polygon + 颜色启发式 | DINO+SAM 语义抠衣 | 伊莲领圈 / 护手 / 腰甲漏蒙 → `armor_remain`；林开衩边糊进肤色 |
| denoise | 0.38 几乎不动；0.70 薄纱；0.84 长人 | 去衣要 0.75–0.85；&lt;0.7 留衣纹 | 林卡在「要褪衣就必须进社区区间」和「进了就长人」之间，没有工作点 |
| 洞太大 | 旗袍整条竖洞一次 crop | CropAndStitch 明文：洞太大要 **downscale**，否则 double head/body | 林高 denoise 的第二人，和社区「洞太大长双人」是同一类失败 |
| 底模 | 只用 RealVisXL + IMC | 社区换装多用 inpaint ckpt / Fooocus patch / Flux Fill | 蓝白花旗袍先验太强，中 denoise 被读成薄纱而不是裸肤 |
| 结构锁 | 去衣采样无 OpenPose / Depth | SDXL 换装常加 ControlNet 保体型 | 高噪时躯干可被重解释成另一个人 |
| 两遍策略 | 有时硬推高 denoise；有时只降 | 社区是高噪出内容 + 低噪收边，不是一直加噪 | 我们缺「第二遍只修边」 |
| 成功参照 | p01 抹胸小洞过得去 | 同栈 | 证明 crop+0.75 在 **小衣服洞** 上成立；不证明能一次抠完整旗袍 |

### 和 Scheme B 的关系

社区「全身裸体底板」是另一条：OpenPose + InstantID + 提示写 nude（本仓库 `scheme_b_from_plate.py`）。那条会抹掉九尾和马身，这次不能用。

社区「成衣静帧去衣」才是 crop-and-stitch。我们选对了族，但：

1. 洞比社区示例大一个数量级；  
2. 蒙版不是语义分割；  
3. InstantID 输入不合 InsightFace；  
4. 没有 inpaint 专用权重；  
5. 撞上 double-body 时，社区解法是 **缩小 crop / 拆更小洞**，我们却主要靠 **降 denoise**，于是直接撞上 `clothes_remain`。

### 已按社区改写的工作流（代码）

`scheme_still_fox_centaur_undress.py` 已落地优先序里能在北京现有节点上做的部分（仍无 DINO+SAM、仍无 Fooocus/Flux Fill）：

| 项 | 现行 |
| --- | --- |
| 小洞 | `lin_region_passes` / `elena_region_passes`：胸腹裙或胸甲领臂腰，各跑一次 |
| denoise | 衣服 pass `CLOTH_DENOISE=0.80`；收边 `EDGE_DENOISE=0.42` + grow |
| 大洞降采样 | `prepare_crop_community`，`MAX_CONTENT_FRAC=0.58` |
| InstantID | `head_shoulder_from_plate` 从头肩盒裁；检不出脸则该 pass 退回纯 inpaint |
| 禁走 | Scheme B 全图；F34；G09；ReActor |
| 未做 | Grounding DINO+SAM；Fooocus inpaint patch / Flux Fill；Differential Diffusion；FaceDetailer 收尾 |

静帧 PNG 仍是改写前那一轮；北京重跑后再更新分数表。

### 若再继续，优先序

1. **SAM（+ Grounding DINO）抠衣**，替代手绘 box。  
2. 有磁盘就加 **Fooocus inpaint patch** 或 SDXL inpaint / Flux Fill。  
3. 可选 Differential Diffusion；FaceDetailer 收尾。  
4. 北京重跑两张，用 Codex 打分更新本表。

一句话：社区已经说明 **小洞 + 语义蒙版 + 0.75–0.85 + 专用 inpaint + 能检出的锁脸**；代码侧已接上小洞、0.80/0.42、大洞降采样、头肩 InstantID；语义蒙版和专用 inpaint 权重仍待装。
