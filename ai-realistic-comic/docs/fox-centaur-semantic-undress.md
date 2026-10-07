# 狐 / 马去衣：语义蒙版管线

2026-10-07。适用 `library/stills/fox-centaur-embrace/` 的四张：林晚棠旗袍九尾 nude / torn，伊莲铠甲半人马 nude / torn。不是身体板，不进 `library/cast/*/body-nude/`。机器只用北京 B `359a49a1c3-4cda10df`。F34 / G09 不开，脚本遇到它们的主机名直接 `FORBIDDEN_HOST`。

## 为什么改

2026-10-07 早先的 Fooocus 重跑用的是手画矩形和椭圆蒙版：林 nude 6.125（`clothes_remain`）、伊莲 nude 7.375（`armor_remain`）、伊莲 torn 7.75（`intact_clothes`）、林 torn 8.75（近门）。蒙版框不住旗袍裙摆和甲片轮廓，衣服留在蒙版外，单靠抬 denoise 解决不了。这一版先找衣服在哪，再重绘；重绘后再找一遍，只补残留。

## 管线

1. 语义蒙版（`semantic_undress.py`）
   - SegFormer B2 clothes（StartHua）：Upper-clothes、Skirt、Pants、Dress、Belt、Scarf 的并集。
   - GroundingDINO + SAM（storyicon）补件。林：qipao、cheongsam dress、silk fabric skirt、mandarin collar、shoulder strap、dress hem。伊莲：breastplate、pauldron、vambrace、gauntlet、fauld、gorget、golden armor。
   - 保护区先减掉：脸框、face、hair、glasses、fox tail、高跟鞋；伊莲再加 horse body / horse tail，但只在 y>720（1024×1536 板坐标）以下生效，而且 DINO 明确点名的甲件优先于马身保护，免得腰甲被当成马。
   - 裁到演员 ROI，丢掉过小的碎块，再外扩 10 px。
2. torn：在 nude 蒙版里用固定种子的锯齿多边形挖洞（林 62%，伊莲 68%），林保留领口 7% 和下摆 18%，伊莲保留下摆 10%，所以残骸留在身上，不会全裸。
3. 预填：Acly `INPAINT_MaskedFill`，`fill=neutral`。不用 Telea / NS 当去衣预填。等价 Fooocus 的 Disable initial latent + Modify Content。
4. Crop and Stitch：SDXL 固定 1024。蒙版按 420 px 高度分带，每带单独裁剪重绘再贴回，不用一个大洞。内容占比封顶 `MAX_CONTENT_FRAC=0.52`，伊莲只裁人躯干、手臂、腰接缝，不进马身。
5. 重绘：RealVisXL V5.0 fp16（非蒸馏写实 SDXL）+ Fooocus inpaint v2.6 patch（`fooocus_inpaint_head.pth`、`inpaint_v26.fooocus.patch`）。nude denoise 1.0，torn 0.96。衣服 pass 不开 DifferentialDiffusion。
6. 残留检查（nude）：对结果再跑一遍 1 的蒙版，残留面积占原衣服面积的比例 <5% 才算净；否则只对残留区域再重绘，最多 3 轮。这是代替抬 denoise 的手段。
7. 收边：蒙版边界 14 px 环带，denoise 0.42，开 DifferentialDiffusion，关预填。
8. InstantID：默认不开。脸在保护区里没被重绘，锁脸是多余的；去衣后 identity 若掉到 9 以下再手动加。头肩图和 `ApplyInstantID` 图在 `scheme_still_fox_centaur_undress.py` 的 `instantid_inpaint_graph`。

顺序：先两张 nude，再两张 torn。不开 ReActor。

## 入口

在北京机上（ComfyUI 监听 127.0.0.1:8188）：

```bash
# 只检查节点是否装齐
python workflows/comfyui/run_fox_centaur_semantic.py --check-stack

# 四张批跑；输出到 library/stills/fox-centaur-embrace/semantic/
python workflows/comfyui/run_fox_centaur_semantic.py --only lin elena --mode both

# 单张重试：换种子（attempt 每加 1，所有种子 +1000）
python workflows/comfyui/run_fox_centaur_semantic.py --only elena --mode nude --attempt 1

# 已过门的跳过
python workflows/comfyui/run_fox_centaur_semantic.py --resume

# 只打分（机器上没有 codex 时在别处补）
python workflows/comfyui/run_fox_centaur_semantic.py --score-only --out <含 png 的目录>
```

每张产物：`<stem>.png`、`<stem>.json`（打分 sidecar）、`<stem>.run.json`（种子、轮数、残留比）、`debug/<stem>-garment-overlay.png`、`work/`（各带的 api json 和中间图）。

装栈：`bash workflows/comfyui/install_undress_stack.sh inventory|install`。幂等，已有的跳过，模型走 hf-mirror，装包前去代理、用清华源。清单：lquesada ComfyUI-Inpaint-CropAndStitch、Acly comfyui-inpaint-nodes、storyicon comfyui_segment_anything、StartHua Comfyui_segformer_b2_clothes、ComfyUI_InstantID；`lllyasviel/fooocus_inpaint` 两个文件，`mattmdjaga/segformer_b2_clothes`。

## 打分

只走 Codex CLI，沿用 `score-nude.txt` / `score-torn.txt`，第一张是各自的 `ref-face.png`，第二张是结果。八项加硬门，收留线均分 ≥ 9 且硬门空。Codex 不可用（没有二进制、未登录、额度用完、超时、JSON 解析失败）就打印 `SCORE_FAILED codex <actor> <mode> reason=<原因>`，写 sidecar 和 `.score-fail.json`，**不回退 Grok，不换别的视觉模型，也不本地估分**。出图不因此中断。

工作流 JSON：`workflows/comfyui/scheme-semantic-*.api.json` 八个（SegFormer、两个 DINO、四个 inpaint、收边），由 `--emit-examples <目录>` 生成，测试里核对和脚本一致。MASK 输出口在机器上按 `/object_info` 取，JSON 里写的是 1。

## 状态（2026-10-07）

- 离线完成：蒙版逻辑、torn 挖洞、残留检查、Codex-only 打分、安装脚本、八个 API 图、说明文档；`tests/test_semantic_undress.py` 与 `tests/test_fox_centaur_undress.py` 通过。
- **没在机器上跑过。** 节点类名（`segformer_b2_clothes` 的输出口、DINO+SAM 的节点名）和权重路径按公开仓库写，装完后以 `--check-stack` 和 `/object_info` 为准，不符就改常量。
- 阻塞：北京 B `359a49a1c3-4cda10df` 已关机，开机弹窗「该主机空闲GPU不足…主机GPU空闲数量：0 卡」。需要用户给「克隆到有空卡主机」或其它开机授权。F34 不动。
- 开机后顺序：`install_undress_stack.sh inventory` → `install` → `--check-stack` → 先两张 nude，再两张 torn → Codex 打分（VM 无 codex 则 `SCORE_FAILED codex ... reason=cli_missing`）→ 机内关机留盘 → 回传四张和 json。
- AutoDL 余额：无开发者 Token，待读。
