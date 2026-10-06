# 林晚棠一致性复盘

2026-10-06。本轮只读已有图、分数和公开资料。不开 F34，不出新图，不调用 Codex。

打分顺序不变：默认 Codex CLI，只有 Codex 不可用才回退 Cursor 的 `cursor-agent --model grok-4.7-xhigh`。这篇不改这条顺序。

## 先说结论

这不是一张图上的破限问题。去衣、锁脸、眼睛端正、全身入画是四件不同的事，当前链路把它们压进同一次 Qwen 编辑。已有结果里，真裸和像脸可以分别出现，没有一张同时过八项门，所以二采一次都没有跑到。

建议停掉「不过门就换下一颗籽」。下一张试跑用已经真裸、全身入画的籽 86 或 98，只修脸和眼睛。修完不像林晚棠，就换 SDXL 写实底模 + InstantID + FaceDetailer，不再加 Qwen 籽。

## 现有链路

1. Codex CLI 出穿衣底板。林晚棠正面在 `library/cast/lin_wantang/body-clothed/front.png`，1024×1536。文档记录这张已过门。
2. 锁脸是 `library/cast/lin_wantang/ref.png`。正面和侧面的第二张条件图是本机下颌裁切 `ref-face.png`（620×545），不覆盖 `ref.png`。背面不喂脸。
3. F34（文档记为 RTX 5090 D）上跑 `Qwen/Qwen-Image-Edit-2511`，8bit transformer，VAE 和文本编码器在 CPU。LoRA 是 `qwen-image-edit-plus-nsfw-lora.safetensors`，scale 0.85，只熔接一次。一采把穿衣底板 letterbox 到 448×592，这次试跑 16 步，true_cfg 4。
4. 一采八项都 ≥ 9 才允许二采。二采 896×1200，同一籽，denoise 从 0.20 起，只放大。
5. 打分看三张图：锁脸、结果的头肩裁切、全身。裁切框是宽 28%–72%、高 1%–24%。短边低于 200 时，`eyes_geometry` 只跟结构标志走，高光和眼睑不判负，也不把 identity 压到 7。

## 已有分数

林晚棠正面一采，scale 0.85，16 步。分数来自 `/opt/cursor/artifacts/body-nude/_fail/` 里的同名 json。没有一张八项都 ≥ 9。

方案 C 把整张带黑圆领的 `ref.png` 当第二张。抽查籽 62、70、78、79–85：identity 多为 9，wardrobe 为 2。衣服锁回来了。

不喂第二张脸的一批，籽 62、70、78、86：wardrobe 都是 10，`eyes_geometry` 为假，identity 被压到 7。

下颌裁切这一批：

| 籽 | identity | wardrobe | eyes_geometry | 低于 9 | scorer |
| --- | --- | --- | --- | --- | --- |
| 86 | 9 | 10 | 真 | 美感、照片感 | grok-4.7-xhigh |
| 87 | 8 | 2 | 真 | 身份、区分、美感、衣着、母题、照片感 | grok-4.7-xhigh |
| 88 | 7 | 9 | 真 | 身份、区分、姿势、美感、解剖、母题、照片感 | grok-4.7-xhigh |
| 89 | 7 | 3 | 真 | 身份、区分、美感、解剖、衣着、母题、照片感 | grok-4.7-xhigh |
| 90 | 9 | 2 | 真 | 区分、美感、衣着、母题 | grok-4.7-xhigh |
| 91 | 9 | 3 | 真 | 衣着、母题 | codex |
| 92 | 8 | 3 | 真 | 身份、区分、美感、衣着、母题 | grok-4.7-xhigh |
| 93 | 9 | 6 | 真 | 美感、衣着、母题、照片感 | grok-4.7-xhigh |
| 94 | 7 | 2 | 真 | 身份、区分、美感、衣着、母题、照片感 | grok-4.7-xhigh |
| 95 | 8 | 3 | 真 | 身份、区分、美感、衣着、母题 | grok-4.7-xhigh |
| 96 | 8 | 4 | 真 | 身份、区分、美感、衣着、母题、照片感 | grok-4.7-xhigh |
| 97 | 7 | 3 | 真 | 身份、区分、美感、衣着、母题、照片感 | grok-4.7-xhigh |
| 98 | 8 | 10 | 真 | 身份 | codex |

十三张里 wardrobe ≥ 9 的只有 86、88、98。identity 和 wardrobe 同时 ≥ 9 的只有 86，卡在美感 8、照片感 8。98 的衣着是 10，身份是 8。

## 根因

每条都标证据。证据分三类：图和 json 是实测；公开页面是别人的说法；没有 A/B 的推断单独标出。

### 眼睛

穿衣底板和 `ref-face.png` 的眼睛是正的，虹膜和眼角能看清。有图。穿衣底板按打分用的头肩框量下来是 451×353。`ref-face.png` 整图 620×545。

一采结果是 448×592。同一头肩框是 197×137，短边 137，低于 200 的细节门槛。有测量。137 像素的脸上，虹膜只有十来个像素。最近邻放大后，眼睑和高光是色块，不是锁脸里那种分开的眼角和高光。有图：籽 86、98、62 的放大头肩。

下颌裁切这一批的 json 里，`eyes_geometry` 全部为真。这是规则造成的：短边低于 200 时，打分模型没把 `eyes_structure` 打成假，几何门就通过，identity 也不封顶。有代码，有 json。所以「分数说眼睛过了」不能证明眼睛是正的。

籽 88 的头不在画面上方。按同一裁切框切出来是一块灰，没有脸。有图。json 仍写 `eyes_geometry` 真、`eyes_black_brown` 假、interaction 3。打分没有看到眼睛，门却开了。有 json。

不喂脸的那批把 `eyes_geometry` 打成假，并把 identity 封到 7。那是改规则之前。同一类小脸，规则一改，几何门就从「几乎必失败」变成「几乎必通过」。两种打分都没有产出一张过门的二采。有 json。

二采会不会把眼睛修好：没有证据。二采从未执行。0.20 denoise 的放大是在已有像素上轻改，不会把十来个像素的虹膜重新摆正。这是机制推断，不是实验结果。

暗像素重心只作弱证据。籽 98 左右暗区垂直重心相差约 2.2 像素，发生在 137 像素高的裁切里。检测器分不清虹膜和眉毛，不能单独当结论。

### 脸锁不住

方案 C 说明编辑模型能跟着第二张图走：整张 `ref.png` 进去，identity 约 9，黑圆领也回来，wardrobe 停在 2。有 json，有图（籽 62 方案 C 的头肩仍是黑衣）。

拿掉衣服之后，脸就自己重画。不喂脸时 wardrobe 10，identity 被眼部门压到 7。下颌裁切之后，identity 在 7 和 9 之间晃，86 为 9，98 为 8。有 json。

这条链路没有身份向量。第二张图只是又一张编辑条件，不是 IP-Adapter、InstantID 或 PuLID。Qwen 官方页写 2511 加强了人物一致，指的是肖像编辑少漂，不是「448 全身去衣仍保持这双眼睛」。官方说法见 [Qwen-Image-Edit-2511](https://huggingface.co/Qwen/Qwen-Image-Edit-2511)。我们自己的全身结果对不上那种肖像一致。有图。

NSFW LoRA 不是角色 LoRA。模型卡写它是 Qwen-Image-Edit-2511 上的内容适配器，约 563MB，触发词是身体和体位，不是某个人。见 [qwen-image-edit-plus-nsfw-lora](https://huggingface.co/ScottzillaSystems/qwen-image-edit-plus-nsfw-lora)。它能把部分籽的衣服去掉，不能把脸锁回 `ref-face.png`。

### 衣服去不干净

同一提示、同一 LoRA、同一 16 步，wardrobe 从 2 摆到 10。有 json。所以不是「这个 LoRA 完全不能去衣」，也不是「提示词一次都没生效」。

籽 87 的图就是白背心加灰短裤，和穿衣底板是同一套衣服。有图。编辑模型经常把第一张的衣服留着。

方案 C 则是第二张把衣服带回来。条件图里有布，结果里就有布。有图，有 json。

籽 93 的 wardrobe 是 6，符合「肉色连体、髋部衣缝最多 6」这条门。籽 88 的分数给了 wardrobe 9，图上仍是连身肉色、髋部有缝。分数和图不一致。这张不能靠 json 叫做真裸。有图，有 json。

过滤不是主因。籽 62、86、98 能画出乳点和肚脐，没有马赛克。有图。过滤若始终封死裸露，这些张不会出现。

8bit 加 VAE 放 CPU 会不会伤眼睛：没有对照实验。不把它写成主因。scale 双乘 0.85×0.85 已改成只熔接一次，文档写过这解释不了后来的衣着失败。

### 各层怎么分担

| 层 | 眼睛 | 锁脸 | 去衣 | 证据 |
| --- | --- | --- | --- | --- |
| 穿衣底板 | 眼睛是正的 | 脸是清晰的 | 衣服本来就在 | 有图 |
| Qwen 编辑 | 全身一采把脸画成约 137 像素，眼角重画 | 没有身份适配器，籽与籽之间 identity 7–9 | 有时留下背心短裤，有时能到 wardrobe 10 | 有图，有 json |
| NSFW LoRA | 不负责眼睛 | 不负责这个人 | 部分籽能去衣，不是角色锁 | 模型卡，加上 wardrobe 的籽间波动 |
| 分辨率 | 虹膜只有十来个像素，二采没机会修 | 锁脸细节进不了一采 | 不是衣服回来的原因 | 有测量；二采未跑 |
| 条件图 | 下颌图没有把眼睛结构交出去 | 整张 ref 能锁脸，也把衣服锁回来 | 第二张带布，结果就带布 | 方案 C 对上下颌批 |
| 提示词 | 没有单独的眼睛结构句，只有锁五官 | 锁脸句在，结果仍漂 | 去衣句在，仍有大量 wardrobe 2–4 | 提示固定而分数波动 |
| 打分 | 137 像素时几何门几乎自动通过；籽 88 裁到灰底仍通过 | identity 8 能挡住 98，挡不住「眼睛看着歪但几何为真」 | 88 的 wardrobe 9 和图上的衣缝不一致 | 有代码，有 json，有图 |

人物一致性做不出来，是因为去衣编辑和身份锁定用的是同一次低分辨率重绘。破限只覆盖其中一件。

## 社区里已经在用的做法

下面是公开仓库和教程，不是我们跑过的结果。显存按这些页面自己的数字转述。F34 在文档里是 RTX 5090 D，下面按 32GB 判断能不能放下。社区博客里的「相似度 88/81/75」是作者自己的示意，不当成测量。

| 做法 | 做什么 | 链接 | 主要模型 | 显存 | 5090 32GB |
| --- | --- | --- | --- | --- | --- |
| PuLID-Flux | 推理时把一张正脸注入 Flux，不训练 | [ComfyUI_PuLID_Flux_ll](https://github.com/katalist-ai/ComfyUI_PuLID_Flux_ll)，权重常引用 `guozinan/PuLID` 的 `pulid_flux_v0.9.1` | Flux 主模型、PuLID、EVA02-CLIP、InsightFace antelopev2 | 该仓库写 16bit 约 22GB，FP8/GGUF 约 12GB；另一篇对比写 Flux+PuLID 约 18GB | 能跑。不要和 Qwen 2511 同时驻留 |
| InstantID | SDXL 上身份向量加关键点 ControlNet | [InstantID](https://github.com/instantX-research/InstantID)，权重 [InstantX/InstantID](https://huggingface.co/InstantX/InstantID) | SDXL 写实底模、InstantID ControlNet、ip-adapter.bin、antelopev2 | 作者在 issue 里建议 24GB，可用 CPU offload | 能跑 |
| IP-Adapter FaceID Plus v2 | SDXL 上最常见的单张脸参考 | [IP-Adapter](https://github.com/tencent-ailab/IP-Adapter) | SDXL 底模、FaceID Plus v2、CLIP-Vision、配套 LoRA | 对比文写 SDXL+FaceID 约 10GB | 能跑。身份紧度通常不如 InstantID 或 PuLID |
| FaceDetailer | 检出脸，放大重绘，再贴回。修大小眼和糊眼睑 | [ComfyUI-Impact-Pack](https://github.com/ltdrdata/ComfyUI-Impact-Pack) | `face_yolov8m.pt`、SAM、一次重绘用的底模 | 取决于重绘底模，本身检测模型很小 | 能跑。单独使用会换脸 |
| ADetailer | 和 FaceDetailer 同类，在 A1111/Forge | 同上教程所比 | 同上 | 同上 | 能跑。本仓库工人是 diffusers，不是 A1111 |
| ReActor | 生成之后换脸 | [ComfyUI-ReActor](https://github.com/Gourieff/ComfyUI-ReActor) | inswapper、InsightFace | 换脸本身轻 | 能跑，但不该用在裸图上。仓库写明带裸露检测，并自称为 SFW |
| ACE++ | Flux Fill 上的肖像/主体 LoRA，可做局部重绘 | [ACE_Plus](https://github.com/ali-vilab/ACE_Plus) | FLUX.1-Fill-dev、portrait LoRA | 说明页写推理至少 8GB，建议 16GB 以上；训练要 38–40GB | 推理能跑。训练这张 32GB 卡不合适 |
| 角色 LoRA | 用这个人的图训练，脸和体型一起走 | 各训练器，不指定一家 | 15–40 张这个人的图，外加底模 | 推理几乎不加显存；训练另算 | 推理能跑。现在没有这套训练图 |
| Qwen F2P | 用脸直接生成全身，不是从穿衣图上改 | [DiffSynth-Studio/Qwen-Image-Edit-F2P](https://modelscope.cn/models/DiffSynth-Studio/Qwen-Image-Edit-F2P/summary) | Qwen-Image-Edit 的 F2P LoRA | 与现有 Qwen 同级 | 权重能放。公开讨论主要在 2509，而且有人在等 NSFW 版。我们没有跑过 |

写实全身更常见的是 SDXL 底模（教程里常点 RealVis、Juggernaut 一类）加 InstantID 或 FaceID，再用 OpenPose 锁站姿，最后 FaceDetailer。Pony 更偏画风，不适合这套写实模板。Flux 加 PuLID 是现在不训练也能锁 Flux 脸的常见组合，身体仍要靠提示、姿势控制和单独的写实 LoRA。

InsightFace 的 antelopev2 一类模型，公开说明里常限制为研究或非商业。真要下载，先看权重页的许可证。

## 三个方案

验收都是林晚棠正面一张。人先看，再打分。四条都要过：脸像 `ref-face.png`，两眼大小和眼角齐，真裸（有乳点、有肚脐、髋部没有衣缝），头和双脚都在画面里。八项仍都要 ≥ 9。137 像素的眼睛裁切不得再把几何门自动放过。

### 方案 A：现有链路上只加修脸

用已经真裸、全身入画的籽 86 或 98，卸掉 Qwen，再跑 FaceDetailer。检测用 `face_yolov8m.pt` 和 SAM。重绘 denoise 约 0.35–0.45。重绘必须带 `ref-face.png` 的身份条件（InstantID 或 FaceID 的一种）。没有身份条件的修脸会把眼睛修直，同时把人修没。

不做 ReActor。它的维护分支拒绝裸图。

预期：身体留下，眼睛变清。身份可能仍不像，因为一采脸上没有可恢复的眼角。

改动：F34 上加一套 ComfyUI 修脸，或在现有工人后加一次小图重绘。Qwen 主循环不改。不换籽。

开机：下载检测模型和一个写实重绘底模之后，一张脸的重绘是分钟级。加上装环境和第一次加载，按一次短开机估，不超过两小时。不花 Codex。Qwen 已经在盘上。

风险：脖子接缝；修完不像林晚棠；88 这种头不在上方的图会检错脸。失败就停，不回到换籽。

### 方案 B：推倒重来，SDXL 写实加 InstantID

不再用 Qwen 编辑去衣。穿衣底板只提供 OpenPose 或深度，让站姿和全身构图留下来。`ref-face.png` 只进 InstantID。底模用写实 SDXL。裸露写在提示和底模或一条内容 LoRA 里，不和锁脸绑在同一次编辑上。输出直接做到短边至少 1024，脸不再是 137 像素。最后 FaceDetailer，denoise 低于主生成，身份条件仍是同一张 `ref-face.png`。

预期：脸像、眼睛、真裸、全身可以分开调。这是社区里重复最多的写实组合。

改动：新的工人或 ComfyUI 图。现有 Qwen 队列停下。穿衣底板和 `ref-face.png` 继续用。

开机：第一次要下载 SDXL 底模、InstantID、antelopev2、姿态模型、FaceDetailer 权重，大约十几 GB，以各仓库实际文件为准。装好之后一张正面是分钟级。第一次按半天以内的开机窗口估。不花 Codex。

风险：皮肤塑料感；InstantID 把表情也锁死；内容 LoRA 和底模不配会把衣服又画回来。许可证要在下载前看。

验收失败时只改一个旋钮：身份权重、姿势权重、或 FaceDetailer denoise。不要三个一起扫。

### 方案 C：Flux 加 PuLID

Flux.1 的 FP8 或 GGUF，加 PuLID-Flux、EVA-CLIP、antelopev2。姿势仍从穿衣底板来。写实和裸露用单独的 Flux LoRA，不用 Qwen NSFW LoRA。脸的生成分辨率同样至少让短边到 1024。需要时再加 FaceDetailer。

预期：皮肤和身份上限高于方案 B。节点更脆，PuLID 的 Comfy 包不能叠两个同名节点。

改动和 B 同级，模型更大。16bit Flux 约 22GB，32GB 卡可以单独跑，不能和 Qwen 2511 一起留在显存里。

开机：下载大于 B。第一次按一次开机窗口估，具体小时数取决于 Flux 权重用 FP8 还是 16bit。不花 Codex。

风险：Flux 的裸露 LoRA 质量参差；PuLID 锁脸不锁身体，体型会漂；Fill 路线的 ACE++ 更适合局部重绘，不适合作为第一张全身的主模型。

角色 LoRA 先不训。没有 15 张以上合格的这个人的图。等 B 或 C 有一张过验收的正面，再决定要不要训。

## 推荐

先做方案 A 的一次试跑，只修籽 86 或 98 的脸。四条验收有一条不过，就停 A，改做方案 B。方案 C 留到 B 的皮肤或身份明显不够再开。

不要把 Qwen 一采籽从 99 继续往下走。33 到 98 已经说明换籽不能同时满足真裸和这张脸。

2026-10-06 用户把上面的试跑顺序改掉了：Qwen 去衣种子全部作废，不再修籽 86 或 98，也不从 99 续跑。十二张穿衣底板保留。裸体改在北京 B 的 ComfyUI 上从底板重出，图在 `workflows/comfyui/`，安装记录在 `docs/comfyui-setup.md`。仓库里现有九张穿衣 png。阿德里安没有穿衣 png，这轮不补底板，也不出他的裸体。

## 要授权的事

本轮这些都没有做。

- 开机 F34。A、B、C 都要。不开 G09，不新建实例，不释放数据盘。
- 下载新模型。A 要脸检测、SAM 和一个写实重绘底模。B 要 SDXL 底模、InstantID、antelopev2、姿态模型和 FaceDetailer。C 要 Flux 和 PuLID 一套。下载前先看 F34 剩余空间，保留已要求的空闲额度。
- 钱只来自 F34 开机时长。不花 Codex。不充值。余额接口若仍是登录超时，只记原因。
- 不授权：继续盲换籽，用 ReActor 处理裸图，在 32GB 上训练角色 LoRA，把 Qwen 和 Flux 同时加载。
