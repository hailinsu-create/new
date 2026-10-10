# 林晚棠 × 伊莲·沃斯 — 旗袍九尾狐 / 铠甲半人马 相拥

一次性成衣双人静帧，不是身体板，也不改 CAST 常驻身体。林晚棠常驻仍是白素贞蛇身；伊莲常驻仍是人身珀耳塞福涅。这一张只锁这次的戏服和体变。

## 脸

- 林晚棠：`library/cast/lin_wantang/ref-face.png`
- 伊莲·沃斯：`library/cast/elena_voss/ref-face.png`（褐眼；默认保留板心圆框金丝眼镜）
- 正好两人。成人。原创脸，非真人。

## 这一张的身体和衣服

- 林：穿旗袍，人身，另外长出**九条狐尾**（狐，不是蛇，不是鱼）。腿仍是人腿。
- 伊莲：上身中世纪铠甲，腰以下是马身（半人马），四条马腿。不是墨绿纱裙。
- 动作：两人相拥。脸要看得见。

## 不是

- 不是 p01–p08，不是蛇尾格，不是去衣底板。
- 不要第三人，不要文字，不要武器，不要未成年人。
- 伊莲不要绿眼、不要蓝灰眼、不要尖耳。
- 林不要金黄瞳、不要正红唇、不要花钿。

眼镜待定：现行锁脸带着眼镜，这一张按锁脸来，不把没戴眼镜写成硬门。

## 出图

成衣：Cursor GenerateImage（历史板为 Codex CLI）。F34 / G09 未开。

- 双人：`lin-elena-embrace.png` 1536×1024。打分均分 9.3，硬门空，anatomy 8.8。
- 林单人：`lin-qipao-nine-tail.png` 1024×1536。更挺拔。Codex 均分 9.0，硬门空；狐尾可辨约八条，第九条可能重叠。
- 伊莲单人：`elena-armor-centaur.png` 1024×1536。马身拉长、母马腹线。身份 9，人马衔接仍略硬。

## 去衣 / 破衣破甲（这一张的衣服，不是身体板）

穿衣单人保留。每人两张：`nude`（去衣）和 `torn`（旗袍/铠甲破碎露肤）。狐尾和马身不进蒙版。工作流 `workflows/comfyui/scheme_still_fox_centaur_undress.py`：北京 B crop-and-stitch + `InpaintModelConditioning` + **Fooocus inpaint patch** + **DifferentialDiffusion**；语义蒙版可用 GroundingDINO+SAM。

现行日程：

- 小洞 / 椭圆破洞；衣服 denoise **0.98**；破衣 **0.96**；收边 **0.42**；`MASK_BLUR=8`；`MAX_CONTENT_FRAC=0.52`
- 默认 Fooocus + `INPAINT_MaskedFill(neutral)`；衣服 pass 关 DifferentialDiffusion（软边会留布）
- InstantID 头肩裁已接，实跑去衣默认 `--no-instantid`
- 打分：Cursor 读锁脸 + 结果，对照板心 `ref-face.png`；收留线均分 ≥ 9 且硬门空；scorer=`cursor`
- 成衣板打分与新首图走 Cursor；露点/破甲编辑只走北京 Comfy（不去 Cursor/Codex imagegen）

不要丢进 `scheme_b_from_plate.py`。北京 B `359a49a1c3-4cda10df`。F34 / G09 不开。不用 ReActor。

| 人 | 成衣 | 变体 | 均分 | 硬门 | 说明 |
| --- | --- | --- | --- | --- | --- |
| 林 | `lin-qipao-nine-tail.png` | `lin-qipao-nine-tail-torn.png` | **8.75** | 空 | 近门；wardrobe 8，anatomy 9（保留此前最佳破衣） |
| 林 | 同上 | `lin-qipao-nine-tail-nude.png` | 6.125 | `clothes_remain` | Fooocus 可开胸窗，裙/残布与 smear 仍过门 |
| 伊莲 | `elena-armor-centaur.png` | `elena-armor-centaur-nude.png`（= **r4-raw usable**） | 8.125† | 空（可接受腰缝/护腕） | **2026-10-10 归档**：Qwen-Edit raw；勿贴回覆盖；禁止再拧同甲 |
| 伊莲 | 同上 | `elena-armor-centaur-torn.png` | 7.75 | `intact_clothes` | 破甲仍偏保守 |

伊莲 nude 已过用户可用线（† scorer=`user_decision`，R4 Qwen raw）。林 nude / 破衣破甲仍未过收留线。

~~未过收留线。下一步优先 GroundingDINO…~~（伊莲金属甲局部擦衣路线已停；见 `docs/fox-centaur-semantic-undress.md`「R4-raw 正式归档」。）
