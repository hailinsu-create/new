# 狐 / 马去衣 — R4 默认标准流程

**生效：2026-10-10 18:59 用户拍板。** 本文件是林晚棠旗袍九尾、伊莲铠甲半人马（及同类戏服静帧）去衣 / 破衣的**唯一默认管线**。

## 标准栈

| 项 | 规定 |
| --- | --- |
| 模型 | `Qwen-Image-Edit-2511` FP8 mixed + `qwen_2.5_vl_7b_fp8_scaled` + `qwen_image_vae` |
| LoRA | Lightning-4steps + `qwen-edit-remove-clothes` + `Object-Remover`（592 已装 ≈31.55GB） |
| 采样 | steps **4**，cfg **1.0**，euler/simple，denoise 1.0 |
| **成功条件** | 采用 Qwen 全图编辑的 **贴回前 RAW**（`*-r4-raw.png`）。**禁止**用 `mask_region` 贴回成图覆盖正式库 |
| 成衣首图 | Cursor **GenerateImage**（锁脸 ref 作参考）；不去 Comfy 做成衣 |
| 去衣 / 破衣 | 仅北京 B Comfy（791 / 592）；**禁止** Cursor/Codex imagegen 做露点编辑 |
| 判定 | Cursor **观感**看 PNG（`VISUAL_JUDGE`）；取消均分≥9 / 硬门门禁 |
| 机器 | 互斥只开一台；**两机协同抢卡**（同时有卡优先 791）；592 有模型优先出图；791 先抢到则确认模型或 hf-mirror 下载 |
| 收尾 | 关机留盘；**禁止 release**；封顶按当次授权（默认出图计费 ≤¥4） |

## 入口脚本

- 单人狐/马四张历史：`run_fox_centaur_community_r4.py` / `r4b` / `r4_batch3`
- 情侣（林×顾，只改林衣）：`run_fox_couple_r4.py` + `run_fox_couple_pilot.py`
- 安装：`install_r4_qwen.sh`
- 抢卡试点模板：`run_r4_batch3_pilot.py`（`CARD_WAIT_MIN=None`，dual race）

## 已知坑（必须记住）

1. **贴回带回膜**：对金属甲 / 半透明残影，贴回会从底板把膜带回 → 正式库只收 raw。
2. **腰缝甲 / 护腕 MODEL_KEEP**：加宽蒙版也去不掉时，不要空转同一 Qwen 提示；伊莲 nude 已归档 R4-raw，禁止再拧同甲。
3. **Flux Fill（R5）FILL_KEPT_METAL**：同洞再拧无效。
4. **远程探测模型**：用 `test -s` 文件存在性，勿依赖裸 `python3` PATH。

## 废弃（勿再作为默认开机路径）

| 路径 | 状态 |
| --- | --- |
| Fooocus inpaint + 语义蒙版分带（`run_fox_centaur_semantic.py` / `scheme_still_fox_centaur_undress.py`） | **废弃**（局部擦衣糊死 / 金属膜） |
| R1 / R1-fix Fooocus 甲壳 | **废弃** |
| R3 / R3b / R3c 整图重生贴回 | **废弃** |
| R5 Flux Fill 定点洞 | **废弃**（同洞金属重建） |
| hillclimb 均分门禁 | **废弃**（改 Cursor 观感） |

历史细节与实验记录仍见 `docs/fox-centaur-semantic-undress.md`（文首指向本标准）。
