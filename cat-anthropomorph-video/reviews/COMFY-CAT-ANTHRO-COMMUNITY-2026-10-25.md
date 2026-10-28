# Comfy 猫拟人社区成熟方案对照（SFW · 2026-10-25）

> **只读公开资料**。未开机、未下载超大权重、未 merge。  
> **排除**：去衣 / undress / NSFW / 漫监资产。  
> 对照本仓：真猫 → Qwen looklock → Wan2.1 I2V 方案 A；用户 t56u 点名拟人度/精细度/题材不够。  
> 衔接：v0.1f = ¥0 剪辑；**v0.1g = 授权开机重定妆**（本文给默认社区栈）。

## 1. 社区成熟度结论（硬证据）

| # | 证据 | 说明 |
| --- | --- | --- |
| 1 | RunningHub《Animal To Talking Human》· <https://www.runninghub.cn/post/1989526705981321218> | **Qwen Image Edit「Animal→Human」LoRA** + 后续说话视频；宠物拟人已成可分享流水线（SFW 演示向） |
| 2 | OpenArt / Civitai《Anything to Real Characters 2511》· <https://openart.ai/workflows/aban/anything-to-real-characters-2511qwen-image-edit-2511/wMVyY41a03gCJV04HQ3P> · <https://civitai.com/models/2294036/anything-to-real-characters-2511> | Qwen-Edit-**2511** 定妆/转写 LoRA 生态活跃；强调脸稳定、表情、皮肤；与本仓 **同一基座世代** |
| 3 | Comfy 官方 Wan2.2 / Wan2.2 Animate · <https://docs.comfy.org/tutorials/video/wan/wan2_2> · <https://docs.comfy.org/tutorials/video/wan/wan2-2-animate> | 官方原生 I2V + **动作迁移 Animate**；社区短视频主路径已从「只有 SVD/AD」扩到 Wan 系 |
| 4 | ComfyUI.org 低显存猫视频 · <https://comfyui.org/en/create-adorable-cat-videos-with-ai> | Wan2.1 I2V GGUF + **4× 超分** + RIFE；「静图→短片→放大」是成熟模板 |
| 5 | masalib 日记：自有猫 + Wan2.2 Animate · <https://masalib.hatenablog.com/entry/2026/09/04/000000> | 真猫参考可锁毛色瞳色；**二足易塌回四足**——拟人姿态需参考强度/提示词专项对抗（与本仓痛点同构） |
| 6 | IP-Adapter Plus 官方 · <https://github.com/comfyorg/comfyui-ipadapter> | 「单图 LoRA」式身份/风格迁移；SDXL Face Plus 常与 ControlNet 组合（定妆侧成熟件） |
| 7 | Reddit WAN 2.2 Cat 分辨率帖 · <https://www.reddit.com/r/StableDiffusion/comments/1nmjlwg/wan_22_cat/> | 社区共识：首帧要够清 + 边长 16 对齐；分辨率策略影响「精细感」 |

**结论一句**：Comfy 侧「真宠物→拟人静帧→Wan 系 I2V→超分」**已成熟可抄**；难点不在「有没有 workflow」，而在 **二足拟人姿态不塌、多参考锁脸毛色、首帧够清**。SDXL/Pony/Illustrious+PuLID/InstantID 在「真人脸→二次元」更卷，**真猫→军装拟人**更贴 Qwen-Edit 多图 + 专用 Animal/Anthro LoRA（须 SFW  vet）。

不确定：具体 Civitai「cat anthro」LoRA 评分与商用条款——下载前人工核许可证；本文不点名 NSFW 合并包。

## 2. 推荐复用栈 vs 本仓现状

| 层 | 社区常用（SFW） | 本仓现状 | 差距 |
| --- | --- | --- | --- |
| 定妆基座 | Qwen-Image-Edit **2511** 多图；可选 Animal→Human / 拟人向 SFW LoRA | Qwen 2511 fp8mixed + cat+costume 槽 | **基座对齐**；缺专用拟人 LoRA、缺「直立姿态」硬约束提示、costume 常占位 |
| 脸/毛色锁 | 多参考（正脸+侧脸/全身）；IP-Adapter / InstantID / PuLID（偏 SDXL 人）；Qwen 侧靠 Image1 身份句 | 单 `front.jpg` + 英文前缀 | **参考密度不足** → 拟人五官弱 |
| 姿态 | OpenPose/Depth ControlNet；或 Wan Animate 骨架 | 无 ControlNet 姿态锁 | 敬礼/直立易漂 |
| I2V | Wan2.1 仍广用；**Wan2.2 I2V / Animate** 官方模板上升；AD/SVD 偏旧短片 | Wan2.1 I2V 方案 A fp16 | 工程正确；**代际与动作迁移**未上 |
| 精细 | 定妆 1024+ → I2V；出片 **4× ClearReality / 同类** + 可选 RIFE | 720 成片；无强制超分节点 | **商业精细感**不足 |
| 短视频结构 | 分镜密度高；社区猫视频多「多短 clip」 | 镜少 | 见 MARKET-GAP / V0.1F（剪辑侧） |

## 3. 立刻可改（仍用现有机 · 可先改仓库模板，开机后再跑）

> 不下载新超大权重也能改的部分。

1. **Looklock 提示词模板**（`01` / look_cards）：强制句  
   `upright bipedal anthropomorphic cat-girl, humanoid face with readable eyes nose mouth, digitigrade optional but standing on two legs, US WWII Normandy infantry uniform, ears visible, SFW, no muzzle-only cat face, no quadruped`  
2. **多槽用法写死**：Image1=真猫身份；Image2=军装/场景；可选 Image3=「直立拟人参考静帧」（自制 mood，非 NSFW）。  
3. **拒绝四足**：负向加 `quadruped, on all fours, feral cat body, snout-dominant, animal face only`。  
4. **定妆输出规格**：looklock 目标 **≥1024 短边**（方图可 1024²）；I2V 前 crop_check；社区建议边长 %16==0。  
5. **workflow MarkdownNote**：链本文 + 「二足易塌，参考强度勿过低」。  
6. **文档/manifest**：登记可选 SFW 拟人 LoRA **待 vet 名录槽**（不下具体 NSFW 包）。

须装节点但权重不大时（仍算「可改」，开机装）：IP-Adapter Plus 或 ControlNet OpenPose——**仅当用户授权装机**；本回合只列清单。

## 4. 须新权重 / 磁盘 / 可能触预算（授权后）

| 项 | 约略体积（公开页，**不确定以 HF 为准**） | 用途 |
| --- | --- | --- |
| Qwen Animal→Human / 拟人 SFW LoRA | 通常 ≪ 基座（百 MB～1GB 级，**待核**） | 抬拟人五官 |
| Wan2.2 I2V 14B 或 Animate | 与 Wan2.1 同级十余～数十 GB | 动作/代际 |
| IP-Adapter SDXL + CLIP Vision | 数 GB 级 | 若走 SDXL 辅路定妆 |
| 4x ClearReality / 超分 | ~百 MB 级 | 成片精细 |
| InstantID/PuLID 全家桶 | InsightFace+adapter | **偏人像**；真猫主链非首选 |

**不作为 v0.1g 默认**：SVD/AnimateDiff 老栈；任何 undress；漫监拷贝。

## 5. 与 v0.1f / v0.1g 衔接

| 版本 | 做什么 | 用不用社区新栈 |
| --- | --- | --- |
| **v0.1f** | ¥0 音乐+剪辑+诺曼底符号叠层（已规划） | 不用新权重 |
| **v0.1g**（须授权） | **重定妆 + 必要短 I2V** | **默认采用下文社区定妆模板** |

### v0.1g 默认定妆栈（一句话）

**继续 Qwen-Image-Edit-2511 多图 looklock（现有 fp8mixed）+ 强化直立拟人/军装提示 + 真猫正面必选第二服装/场景参考；可选挂 SFW Animal→Human/拟人 LoRA（人工 vet）；定妆 ≥1024 后接现有 Wan2.1 方案 A（或授权后再评 Wan2.2）；出片侧加 4× 超分节点。**

验收沿用 [`V0.1F-PLAN`](V0.1F-PLAN-2026-10-25.md) §2.6：拟人五官可读、军装贴合、战场可读、门禁 HA。

## 6. 二战/军装卡点可借鉴结构（非同题材）

社区军装历史片少「现成猫拟人包」，可借结构：

- 分镜密度：登陆/敬礼/滩头拆成 **多短 I2V** 而非单长镜（对齐 V0.1F 10–14 刀）。  
- 一致性：同一 looklock 包喂所有 I2V；场景换 Image2 不换猫身份。  
- 符号：钢盔/艇门/日期条 —— v0.1f ¥0 先叠；v0.1g 用场景 looklock 补真感。

## 7. 下载清单（仅列表 · 本回合不下）

开机授权后按优先级：

1. （可选）Civitai/HF：**SFW** Qwen Animal→Human / cat-anthro edit LoRA — 核 license  
2. （可选）`4x-ClearRealityV1.pth` 或仓库另选超分  
3. （中期）Wan2.2 I2V 或 Animate 官方 Comfy 拆分文件  
4. （旁路）IP-Adapter Plus SDXL + CLIP-ViT-H — 仅当试 SDXL 辅路  

体积以各页为准；4090 盘需预留空间；`restore --group looklock` 不自动拉可选包。

## 8. 不要做

- 开机本回合；静默下载数十 GB；拷漫监 NSFW  
- 把 InstantID 当真猫银弹而不改提示词  
- 用 Wan Animate 却不防四足塌缩  
- 用社区「精细」当借口跳过 v0.1f 音乐剪辑  

## 9. 默认下一步

1. 本机执行 **v0.1f**（剪映）  
2. 用户若仍嫌拟人/题材：授权 → **v0.1g** 按 §5 默认栈跑新 looklock → 短 I2V → 超分 → 再剪

## 10. 模板固化（v0.1g）

已落入可复用槽位与开机清单，见 [`COMFY-TO-TEMPLATES-v0.1g.md`](COMFY-TO-TEMPLATES-v0.1g.md) 与 [`../BOOT-v0.1g.md`](../BOOT-v0.1g.md)。
