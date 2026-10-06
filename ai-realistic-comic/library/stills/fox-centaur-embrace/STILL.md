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

Codex CLI 成衣。F34 / G09 未开。

- 双人：`lin-elena-embrace.png` 1536×1024。打分均分 9.3，硬门空，anatomy 8.8。
- 林单人：`lin-qipao-nine-tail.png` 1024×1536。更挺拔。Codex 均分 9.0，硬门空；狐尾可辨约八条，第九条可能重叠。
- 伊莲单人：`elena-armor-centaur.png` 1024×1536。马身拉长、母马腹线。身份 9，人马衔接仍略硬。

## 去衣 / 破衣破甲（这一张的衣服，不是身体板）

穿衣单人保留。每人两张：`nude`（去衣）和 `torn`（旗袍/铠甲破碎露肤）。狐尾和马身不进蒙版。工作流 `workflows/comfyui/scheme_still_fox_centaur_undress.py --mode both`：社区对齐小洞 crop-and-stitch + `InpaintModelConditioning`。

现行日程：

- `nude`：林胸/腹/裙；伊莲胸甲/领/臂/腰；衣服 denoise **0.80** + 收边 **0.42**
- `torn`：更小的椭圆破洞，denoise **0.78** + 收边；提示写撕破旗袍 / 碎裂铠甲，保留衣甲残骸
- 大洞 `MAX_CONTENT_FRAC=0.58`；InstantID 吃成衣板 **头肩裁**；失败则该 pass 退回纯 inpaint
- 打分对照仍是板心 `ref-face.png`；收留线均分 ≥ 9 且硬门空

不要丢进 `scheme_b_from_plate.py`。北京 B `359a49a1c3-4cda10df`。F34 / G09 不开。不用 ReActor。

| 人 | 成衣 | 去衣 | 破衣/破甲 |
| --- | --- | --- | --- |
| 林 | `lin-qipao-nine-tail.png` | `lin-qipao-nine-tail-nude.png` | `lin-qipao-nine-tail-torn.png` |
| 伊莲 | `elena-armor-centaur.png` | `elena-armor-centaur-nude.png` | `elena-armor-centaur-torn.png` |

上一轮（改工作流前）去衣：林 6.5 / `clothes_remain`；伊莲 8.0 / `armor_remain`。新日程重跑后更新分数。
