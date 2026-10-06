# ComfyUI 写实底板（北京 B）

2026-10-06。Qwen 去衣种子全部作废，不从 `99` 续跑。裸体从已有穿衣底板重出。F34 `xaxna66hqt-c5c9c7fc` 和 G09 没有开机、没有释放。本轮机器是新租的北京 B 791。

## 机器

| 项 | 值 |
| --- | --- |
| 实例 | `359a49a1c3-4cda10df` |
| GPU | NVIDIA GeForce RTX 5090，能力 `(12, 0)`，约 33.6GB 显存 |
| 系统 Python | `/root/miniconda3/bin/python`（3.12） |
| PyTorch | `2.8.0+cu128`，安装时没有让 pip 换掉这套 torch |
| 代码和模型 | 数据盘 `/root/autodl-tmp` |
| ComfyUI | 只听 `127.0.0.1:8188`，`--disable-auto-launch` |

SSH：

```bash
ssh -i ~/.ssh/bjb791 -p 34711 root@connect.bjb2.seetacloud.com
```

本机看界面时做隧道，不要把 8188 暴露到公网：

```bash
ssh -i ~/.ssh/bjb791 -p 34711 -L 8188:127.0.0.1:8188 root@connect.bjb2.seetacloud.com
```

浏览器打开 `http://127.0.0.1:8188`。脚本直接打这台机器上的 `http://127.0.0.1:8188`。

学术加速会拖慢 pip。装包前去掉 `http_proxy` / `https_proxy`，索引用清华 `https://pypi.tuna.tsinghua.edu.cn/simple`。模型用 `https://hf-mirror.com`。

做完后在机器内部 `shutdown`，磁盘保留。不要用 F34 的电源接口关这台。

## 安装

ComfyUI 在 `/root/autodl-tmp/comfyui`，标签 `v0.39.0`，提交 `b0b743566f65daafc423b4fea8a2fbda94b3384a`。

`requirements.txt` 里去掉了 `torch`、`torchvision`、`torchaudio` 和 `comfyui-workflow-templates`。清华源没有 `comfyui-workflow-templates-media-assets-02==0.1.9`（Python 3.12），那个包是界面素材，API 出图不用。启动日志里的 `comfyui-workflow-templates is not installed` 和 `[ComfyUI-Manager] PyTorch is not installed` 可以忽略：`/system_stats` 仍是 HTTP 200，采样能跑。

自定义节点（`custom_nodes/` 下的 git HEAD）：

| 节点 | 提交 | 用途 |
| --- | --- | --- |
| ComfyUI-Manager | `855a0f50ecc842adacab08aa24d8655a742fae40` | 节点管理 |
| ComfyUI-Impact-Pack | `429d0159ad429e64d2b3916e6e7be9c22d025c3c` | FaceDetailer |
| ComfyUI-Impact-Subpack | `50c7b71a6a224734cc9b21963c6d1926816a97f1` | Impact 依赖 |
| ComfyUI_InstantID | `72495e806bc2ab9c41581e15ccaa1bcf83c477e8` | 锁脸 |
| ComfyUI_IPAdapter_plus | `a0f451a5113cf9becb0847b92884cb10cbdec0ef` | FaceID Plus V2 |
| comfyui_controlnet_aux | `0cd290477128d42cdc3e76a826a402d866e8c684` | DWPose |
| comfyui-inpaint-nodes (Acly) | 数据盘 git HEAD | Fooocus inpaint：`INPAINT_LoadFooocusInpaint` / `INPAINT_ApplyFooocusInpaint` |
| comfyui_segment_anything (storyicon) | 数据盘 git HEAD | GroundingDINO + SAM 语义衣物蒙版 |

核心自带 `DifferentialDiffusion`（`comfy_extras/nodes_differential_diffusion.py`）。Impact 的 `requirements.txt` 去掉了 `git+sam2` 那一行。FaceDetailer 用 SAM1。PuLID 这轮不装。裸体图不用 ReActor。

`onnxruntime-gpu==1.30.0` 能 import，`get_available_providers()` 只有 `AzureExecutionProvider` 和 `CPUExecutionProvider`，没有 CUDA。InstantID 和 IP-Adapter FaceID 的 InsightFace 都设成 `CPU`。DWPose 走 OpenCV DNN。InsightFace / antelopev2 常见许可是研究或非商用，出片前要单独核对许可。

启动：

```bash
cd /root/autodl-tmp/comfyui
/root/miniconda3/bin/python main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch
```

模型目录只在进程启动时扫描。新文件下完要重启，`/object_info` 才列得出来。

## 模型

sha256 是数据盘上的文件。来源是 hf-mirror 上对应的仓库，除非另注。

| 文件 | 字节 | sha256 |
| --- | --- | --- |
| `models/checkpoints/RealVisXL_V5.0_fp16.safetensors` | 6938065488 | `6a35a7855770ae9820a3c931d4964c3817b6d9e3c6f9c4dabb5b3a94e5643b80` |
| `models/instantid/ip-adapter.bin` | 1691134141 | `02b3618e36d803784166660520098089a81388e61a93ef8002aa79a5b1c546e1` |
| `models/controlnet/instantid/diffusion_pytorch_model.safetensors` | 2502139136 | `c8127be9f174101ebdafee9964d856b49b634435cf6daa396d3f593cf0bbbb05` |
| `models/controlnet/openpose-sdxl-xinsir/diffusion_pytorch_model.safetensors` | 2502139104 | `b8524e557a7df60d081f5d4a0eb109967d107df217943bf88c2d99b9ebcc06c5` |
| `models/clip_vision/CLIP-ViT-H-14-laion2B-s32B-b79K.safetensors` | 2528373448 | `6ca9667da1ca9e0b0f75e46bb030f7e011f44f86cbfb8d5a36590fcd7507b030` |
| `models/ipadapter/ip-adapter-faceid-plusv2_sdxl.bin` | 1487555181 | `c6945d82b543700cc3ccbb98d363b837e9c596281607857c74b713a876daf5fb` |
| `models/loras/ip-adapter-faceid-plusv2_sdxl_lora.safetensors` | 371842896 | `f24b4bb2dad6638a09c00f151cde84991baf374409385bcbab53c1871a30cb7b` |
| `models/upscale_models/4x-UltraSharp.pth` | 66961958 | `a5812231fc936b42af08a5edba784195495d303d5b3248c24489ef0c4021fe01` |
| `models/ultralytics/bbox/face_yolov8m.pt` | 52026019 | `717923c19b3f4bbf5250b728f1fa6b2cb72a33aed1d236ea9caf0e21ad943e5f` |
| `models/sams/sam_vit_b_01ec64.pth` | 375042383 | `ec2df62732614e57411cdcf32a23ffdf28910380d03139ee0f4fcbe91eb8c912` |
| `models/inpaint/fooocus_inpaint_head.pth` | ~52KiB | `32f7f838e0c6d8f13437ba8411e77a4688d77a2e34df8857e4ef4d51f6b97692` |
| `models/inpaint/inpaint_v26.fooocus.patch` | ~1.3GiB | `f8657a025104e22d70f9c060635d8e8c2196f433871a2f68dc40abd2171f0d59` |
| `models/grounding-dino/groundingdino_swint_ogc.pth` | ~662MiB | `3b3ca2563c77c69f651d7bd133e97139c186df06231157a64c507099c52bc799` |
| `models/text_encoders/clip_l.safetensors` | ~235MiB | （Flux 文本；Fill 权重 gated 未下） |
| `ckpts/yzd-v/DWPose/yolox_l.onnx` | 216746733 | `7860ae79de6c89a3c1eb72ae9a2756c0ccfbe04b7791bb5880afabd97855a411` |
| `ckpts/yzd-v/DWPose/dw-ll_ucoco_384.onnx` | 134399116 | `724f4ff2439ed61afb86fb8a1951ec39c6220682803b4a8bd4f598cd913b1843` |
| `insightface/models/antelopev2/glintr100.onnx` | 260665334 | `4ab1d6435d639628a6f3e5008dd4f929edf4c4124b1a7169e1048f9fef534cdf` |
| `insightface/models/antelopev2/1k3d68.onnx` | 143607619 | `df5c06b8a0c12e422b2ed8947b8869faa4105387f199c477af038aa01f9a45cc` |
| `insightface/models/antelopev2/scrfd_10g_bnkps.onnx` | 16923827 | `5838f7fe053675b1c7a08b633df49e7af5495cee0493c7dcf6697200b85b5b91` |
| `insightface/models/antelopev2/2d106det.onnx` | 5030888 | `f001b856447c413801ef5c42091ed0cd516fcd21f2d6b79635b1e733a7109dbf` |
| `insightface/models/antelopev2/genderage.onnx` | 1322532 | `4fde69b1c810857b88c64a335084f1c3fe8f01246c9a191b48c7bb756d6652fb` |
| `insightface/models/buffalo_l/w600k_r50.onnx` | 174383860 | `4c06341c33c2ca1f86781dab0e829f88ad5b64be9fba56e56bc9ebdefc619e43` |

InstantID 用 antelopev2。IP-Adapter FaceID Plus V2 的统一加载器默认下 `buffalo_l`，不走 antelopev2。`buffalo_l.zip` 来自 hf-mirror 上 `datasets/Gourieff/ReActor` 的 `models/buffalo_l.zip`，解压后五个 onnx 放在 `models/insightface/models/buffalo_l/`。其中 `1k3d68.onnx`、`2d106det.onnx`、`genderage.onnx` 和 antelopev2 同哈希；`det_10g.onnx` 与 antelopev2 的 `scrfd_10g_bnkps.onnx` 同哈希。

两个 diffusers 格式的 ControlNet 用 `DiffControlNetLoader`，旁边有各自的 `config.json`。CLIP 视觉模型从 `h94/IP-Adapter` 的 `models/image_encoder/model.safetensors` 改名，好让 FaceID Plus V2 的文件名匹配。

`4x-UltraSharp.pth` 已在盘上，这轮图没有做 4 倍放大。眼部分割 `Anzhc Eyes seg hd` 没下下来：文件名里的空格经过 hf-mirror 双重编码，xet 桥返回 401。FaceDetailer 只用 `face_yolov8m.pt`。

底模是 [SG161222/RealVisXL_V5.0](https://huggingface.co/SG161222/RealVisXL_V5.0) 的 fp16。它是社区常用的 SDXL 写实底，能画成人裸体。缩小人物给脚留边时，它会在胸口加一条黑丝带，所以图后面还有一次胸口重绘。

## 工作流

仓库里的可运行脚本是 `workflows/comfyui/scheme_b_from_plate.py`。API 格式示例：

- `workflows/comfyui/scheme-b-front-side.api.json` 正面和侧面（林晚棠正面的图）
- `workflows/comfyui/scheme-b-back.api.json` 背面

这些图是社区节点拼出来的，不是把别人的整张工作流原样导入。

| 来源 | 为什么用 |
| --- | --- |
| [Impact Pack 的 FaceDetailer 示例](https://github.com/ltdrdata/ComfyUI-Impact-Pack/blob/Main/example_workflows/1-FaceDetailer.json) | 脸部重绘用量最高的一条。denoise 0.40，把眼睛修正在身份还在的时候，不整个人换掉 |
| [ComfyUI_InstantID](https://github.com/cubiq/ComfyUI_InstantID) | InstantX/InstantID 的移植。身份来自锁脸，关键点来自穿衣底板，侧面不会被拉成正面 |
| [IPAdapter FaceID Plus V2](https://github.com/cubiq/ComfyUI_IPAdapter_plus) | 预设 FACEID PLUS V2，权重来自 h94/IP-Adapter-FaceID。只接到 FaceDetailer 的模型上，不和 InstantID 叠在同一次采样上 |
| [comfyui_controlnet_aux](https://github.com/Fannovel16/comfyui_controlnet_aux) 的 DWPose，加 [xinsir/controlnet-openpose-sdxl-1.0](https://huggingface.co/xinsir/controlnet-openpose-sdxl-1.0) | 穿衣底板出姿势。`scale_stick_for_xinsr_cn=enable`，手和身体开，脸关 |

Qwen 去衣把身份和脱衣压进同一次 448 编辑，没有一张八项都过。用户作废了那些种子，所以不用方案 A 去修籽 86 或 98。

图的形状：

1. 穿衣底板进 DWPose（`yolox_l.onnx` + `dw-ll_ucoco_384.onnx`）。
2. 姿势图缩到 0.86，贴到 1024×1536 黑底的 `(72, 40)`。不缩小的时候脚会被裁掉；缩得太多胸口更容易长出丝带。0.86 是脚还在画面里的那一档。
3. xinsir OpenPose，strength 0.95。
4. 正面和侧面：锁脸进 InstantID（weight 0.8，CPU），脸关键点用同一套缩放贴回全画布。`ApplyInstantID` 的 `image_kps` 必须是照片或全画布关键点。检测失败时节点会把这张关键点图本身当控制图，这是预期，不是没提出脸。锁脸本身要能检出脸。
5. 主采样：种子 `20261006`（ComfyUI 采样种子，不是 Qwen 去衣种子），26 步，cfg 4，`dpmpp_2m` / `karras`，1024×1536。
6. FaceDetailer：guide 768，16 步，cfg 4.5，denoise 0.40。FaceID Plus V2 的 `lora_strength` 0.6，`weight` 0.85，`weight_faceidv2` 1.0，`weight_type` linear，`embeds_scaling` 为 `V only`，provider CPU。SAM 是 `sam_vit_b`。
7. 背面只有 OpenPose，不喂脸，不做 FaceDetailer。

RealVisXL 在缩小后的全身图上仍会画黑丝带或抹胸。脚本在正面和侧面出图后，只把「左右两侧都是皮肤」的近黑像素当成丝带（高 15.5%–42%、宽 32%–68%，通道低于 48，至少 120 个这样的像素）。头发贴着灰背景，不会被算进去。够数就用实心矩形蒙版做一次 denoise 1.0 的重绘，种子 `20261009`，20 步，cfg 4.5，提示只写裸露的胸口皮肤。矩形宽超过 340 或高超过 380 就放弃，避免把手臂或胯一起重绘。背面不跑这一步。浅色布这一步认不出来。

第一版清理用的是全部近黑像素的外接矩形。伊莲侧面那一版把远处的手臂画薄了，所以打分用的是清理前的那张。林晚棠正面的丝带是后一步收紧蒙版之前清掉的。

输入文件名是 `{actor}-{view}-clothed.png` 和 `{actor}-ref.png`，放在 ComfyUI 的 `input/`。仓库里有九张穿衣 png：林晚棠、顾承安、伊莲各正面、侧面、背面。阿德里安只有 `ref.png`，没有 `body-clothed/`，这轮不补底板，也不出他的裸体。

调用（在北京机器上，ComfyUI 已监听本机 8188）：

```bash
/root/miniconda3/bin/python /root/autodl-tmp/scheme_b_from_plate.py \
  --only lin_wantang front \
  --out /root/autodl-tmp/comfy-runs
```

不带 `--only` 会按脚本里的九张顺序跑。结果写到 `--out/{actor}-{view}.png`。

## 打分

阶段是 `pass1`。打分顺序不变：Codex CLI 优先，不可用才回退 Cursor 的 `cursor-agent --model grok-4.7-xhigh`。这九张的 `scorer` 都是 `codex`。八项都要 ≥ 9。1024×1536 的头肩裁切短边超过 200，眼睛细节会计入，几何不过会把 identity 封到 7。采样种子是 `20261006`。

九张里四张过门：林晚棠侧面、林晚棠背面、顾承安背面、伊莲背面。正面没有一张过门。

| 人 | 向 | identity | distinction | interaction | aesthetics | anatomy | wardrobe | motif | photoreal | 门 | 过 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 林晚棠 | 正 | 7 | 8 | 8 | 7 | 6 | 10 | 8 | 8 | H7 | 否 |
| 林晚棠 | 侧 | 9 | 9 | 10 | 9 | 9 | 10 | 10 | 9 |  | 是 |
| 林晚棠 | 背 | 9 | 9 | 10 | 9 | 9 | 10 | 10 | 9 |  | 是 |
| 顾承安 | 正 | 8 | 8 | 8 | 8 | 8 | 10 | 8 | 8 |  | 否 |
| 顾承安 | 侧 | 7 | 8 | 9 | 9 | 9 | 10 | 8 | 9 | EYES_GEOMETRY | 否 |
| 顾承安 | 背 | 9 | 9 | 10 | 9 | 9 | 10 | 10 | 9 |  | 是 |
| 伊莲 | 正 | 8 | 9 | 10 | 9 | 9 | 10 | 9 | 9 |  | 否 |
| 伊莲 | 侧 | 8 | 9 | 9 | 8 | 9 | 10 | 9 | 9 | FEET | 否 |
| 伊莲 | 背 | 9 | 9 | 9 | 9 | 9 | 10 | 10 | 9 |  | 是 |

衣着九张都是 10。林晚棠正面的脚在画面里，趾形被打成 anatomy 6。顾承安正面用 0.86 缩小后双脚悬空，八项里除衣着外都是 8；把姿势缩放送回 1.0 之后人站到了地上，脚被裁出画面，这张不采用。顾承安侧面眼睛几何没过，identity 被封到 7。伊莲正面只差 identity 1 分。伊莲侧面 Codex 给了 FEET。

2026-10-06 第二次：用户要林晚棠裸体三向。北京 B `359a49a1c3-4cda10df` 再次开机，F34 和 G09 仍关机。InstantID 改吃 `ref-face.png`（记事干净正脸裁到下巴，无衣领）。种子仍是 `20261006`。Codex `pass1`：正面 identity 7、anatomy 6、H7，不过门；侧面和背面过门。背面图和第一次相同，因为背面不喂脸。出完后机器再次内部关机，磁盘保留。

2026-10-06 旗袍九尾 / 铠甲半人马单人去衣 / 破衣破甲：不要跑 `scheme_b_from_plate.py`。衣服走 `workflows/comfyui/scheme_still_fox_centaur_undress.py --mode both`：小洞/椭圆 crop-and-stitch + `InpaintModelConditioning`，衣服 denoise **0.88**、收边 **0.40**，`MAX_CONTENT_FRAC=0.52`。InstantID 头肩裁可用，但去衣实跑默认 `--no-instantid`（叠 InstantID 易薄纱或双人）。最佳成绩：林破衣 Codex 均分 **8.875** 硬门空；伊莲去衣 **8.125** / `armor_remain`。Codex imagegen 拒绝对成衣板做露点编辑。机器北京 B `359a49a1c3-4cda10df`。F34 / G09 不开。裸体不用 ReActor。

2026-10-07 去衣优化栈：北京 B 数据盘 Acly Fooocus inpaint、GroundingDINO+SAM、核心 `DifferentialDiffusion`。`/object_info` 确认 `INPAINT_LoadFooocusInpaint`、`INPAINT_ApplyFooocusInpaint`、`DifferentialDiffusion`、`GroundingDinoSAMSegment (segment anything)`。Flux Fill gated 未装。工作流默认 `MaskedFill(neutral)` + Fooocus；衣服 denoise **0.98**，破衣 **0.96**，收边 **0.42**；衣服 pass 关闭 DifferentialDiffusion。重跑 Codex：林破衣 **8.75** 硬门空；其余仍未过门（`clothes_remain` / `armor_remain` / `intact_clothes`）。F34 / G09 不开。
