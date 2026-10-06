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

## 去衣（这一张的衣服，不是身体板）

穿衣单人保留。去衣只抠旗袍和铠甲，狐尾和马身不进蒙版。工作流是 `workflows/comfyui/scheme_still_fox_centaur_undress.py`：社区对齐的小洞 crop-and-stitch + `InpaintModelConditioning`。

现行日程（对 COMPARE.md 里社区表的实现）：

- 蒙版拆成多个小洞（林：胸 / 腹 / 裙；伊莲：胸甲 / 领 / 臂 / 腰），再加一遍 denoise ≈ 0.42 的收边
- 衣服 pass denoise **0.80**（社区 0.75–0.85 带）
- 洞太大时 `prepare_crop_community` 把内容压到 canvas 的 ≤58%（防 double body）
- InstantID 锁脸改吃成衣板上的 **头肩裁**（`head_shoulder_from_plate`），不再只喂下颌以上的 `ref-face.png`；InsightFace 仍挂则该 pass 退回纯 inpaint
- 打分对照仍是板心 `ref-face.png`

不要把这两张丢进 `scheme_b_from_plate.py` 的全身 OpenPose 重绘。北京 B `359a49a1c3-4cda10df`。F34 / G09 不开。不用 ReActor。

上一轮实跑（改工作流前）：林 denoise 0.70 胸腹分抠 → 薄纱旗袍、多余手臂，均分 6.5 / `clothes_remain`；伊莲胸甲去了、领臂腰甲残留，均分 8.0 / `armor_remain`。狐尾和马身都还在。社区改写后的静帧尚未在北京重跑。

| 人 | 成衣 | 去衣（改写前） | 均分 | 硬门 |
| --- | --- | --- | --- | --- |
| 林 | `lin-qipao-nine-tail.png` | `lin-qipao-nine-tail-nude.png` | 6.5 | clothes_remain |
| 伊莲 | `elena-armor-centaur.png` | `elena-armor-centaur-nude.png` | 8.0 | armor_remain |
