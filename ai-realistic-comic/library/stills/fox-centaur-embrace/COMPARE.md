# 旗袍九尾 / 铠甲半人马 — 成衣 vs 去衣对照

2026-10-06。成衣是 Codex CLI。去衣是北京 B Comfy crop-and-stitch，不是 Scheme B 全身重绘。F34 / G09 未开。打分都是 Codex。

## 总表

| 人 | 成衣均分 | 成衣硬门 | 去衣均分 | 去衣硬门 | 主要变化 |
| --- | --- | --- | --- | --- | --- |
| 林晚棠 | 9.0 | 空 | 6.5 | `clothes_remain` | 旗袍变薄纱，胸可见；狐尾还在；大腿前多了一只手 |
| 伊莲·沃斯 | 8.94 | 空 | 8.0 | `armor_remain` | 上身铠甲去掉；马身还在；领圈、左臂甲、腰甲残留 |

两张都没过收留线（均分 ≥ 9 且硬门空）。

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
| 锁脸 | `library/cast/<id>/ref-face.png`（打分对照）；实跑未接 InstantID |
| 寻卡 | 每两分钟一次；第 13 次开机 |

## 结论

- 伊莲：成衣→去衣身份稳住，马身保住；差在甲片残留，均分从 8.94 掉到 8。
- 林：狐尾和构图保住；衣服没褪干净，还引入多余手臂，均分从 9.0 掉到 6.5。
- 两张都不过门。若继续，林要换更稳的局部蒙版、避免二次长人；伊莲只需再抠领圈、左臂甲、腰甲。
