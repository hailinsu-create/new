# 三猫定妆锁定 · CHARACTER LOCK · 2026-10-24

> **状态**：文档锁定生效（SFW）。锁定日 **2026-10-24（Asia/Shanghai）**。
>
> **原图状态**：三猫原图**已入库**（tip `3abef51`）；六张 jpg（首选名 + `front.jpg` 兼容副本）路径与字节数见 [`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)（保留原文件名避免断链）。
>
> **来源**：`prompts/look_cards.md` 已锁定字段 + 用户权威字段重建；本文件为文本锁定，原图位于 `refs/cats/`。

## 权威角色表

| 代号 | 名字 | 外观 | 阵营 |
| --- | --- | --- | --- |
| A | 小橘 | 橘白长毛 | 美军 / 诺曼底 |
| B | 银宝 | 银虎斑折耳 | 苏军 / 斯大林格勒 |
| C | 墨墨 | 全黑折耳 | 飞行员 / 中途岛 |

一猫一阵营，跨条不得换脸、换毛色、换瞳色或串阵营主装。每猫固定提示词前缀可直接复用 [`prompts/look_cards.md`](prompts/look_cards.md)。

---

## A · 小橘（美军 / 诺曼底）

| 字段 | 锁定值 |
| --- | --- |
| 代号 / 名字 | A / **小橘** |
| 外观 | 橘白长毛 |
| 毛色与花纹 | 头顶、背脊、尾巴为橘色虎斑块；口鼻、胸口、四爪为白色 |
| 瞳色 | 琥珀铜色 |
| 耳形 | 直立大耳，耳尖有长毛簇，耳内粉色；钢盔耳洞必须露耳 |
| 胡须 | 白色长胡须 |
| 体型 | 中大型长毛猫，蓬松 |
| 主装 | 美军 M1 钢盔（耳部开口露耳）+ 橄榄绿野战夹克 + 红领巾 + 帆布腰带 |
| 场景 | 1944 诺曼底登陆艇内 / 沙滩，硝烟与冷灰天光 |
| 参考图位 | [`refs/cats/A/`](refs/cats/A/) · 期望 `cat-A-ginger-white.jpg` 或 `front.jpg` |

**固定英文提示词前缀（A）**

```text
anthropomorphic orange-and-white long-haired cat, the same individual cat in every shot: orange tabby patches on head, back and tail, white muzzle, chest and paws, long fluffy fur, amber-copper eyes, large upright tufted ears clearly visible through a US M1 helmet with ear cutouts, olive-drab WWII US infantry jacket, red neckerchief, empty-handed or holding a flag, binoculars or map case, no rifle by default, SFW, photoreal cinematic still
```

---

## B · 银宝（苏军 / 斯大林格勒）

| 字段 | 锁定值 |
| --- | --- |
| 代号 / 名字 | B / **银宝** |
| 外观 | 银虎斑折耳 |
| 毛色与花纹 | 银灰底配深灰虎斑条纹；口鼻与胸口较浅 |
| 瞳色 | 浅绿色 |
| 耳形 | 折耳，小耳向前折下；船形帽 / 毛帽耳部开口必须露耳 |
| 胡须 | 白色长胡须 |
| 体型 | 中小型短毛猫，紧凑 |
| 主装 | 苏军船形帽或毛帽（耳部开口露出折耳）+ 红星帽徽 + 卡其色制服 + 腰带 |
| 场景 | 1942–43 斯大林格勒废墟 / 破窗与火光剪影 |
| 参考图位 | [`refs/cats/B/`](refs/cats/B/) · 期望 `cat-B-silver-fold.jpg` 或 `front.jpg` |

**固定英文提示词前缀（B）**

```text
anthropomorphic silver tabby Scottish Fold cat, the same individual cat in every shot: silver-gray coat with dark tabby stripes, lighter muzzle and chest, pale green eyes, small folded ears clearly emerging from the ear openings of a Soviet side cap or ushanka, red star cap badge, khaki WWII Soviet uniform, empty-handed or holding a flag, binoculars or map case, no rifle by default, SFW, photoreal cinematic still
```

---

## C · 墨墨（飞行员 / 中途岛）

| 字段 | 锁定值 |
| --- | --- |
| 代号 / 名字 | C / **墨墨** |
| 外观 | 全黑折耳 |
| 毛色与花纹 | 通体纯黑，无白斑；强光下允许极轻微暖棕反光，不得出现白袜 / 白胸 |
| 瞳色 | 金琥珀色 |
| 耳形 | 折耳，小耳向前折下；飞行帽耳部开口必须露耳 |
| 胡须 | 黑色 / 深色胡须 |
| 体型 | 中小型短毛猫，紧凑 |
| 主装 | 棕色皮飞行帽（耳部开口露折耳）+ 风镜 + 白围巾 + 皮夹克；机徽一律不入画 |
| 场景 | 1942 中途岛航母甲板 / 海天背景，起飞或返航定格 |
| 参考图位 | [`refs/cats/C/`](refs/cats/C/) · 期望 `cat-C-black-fold.jpg` 或 `front.jpg` |

**固定英文提示词前缀（C）**

```text
anthropomorphic solid-black Scottish Fold cat pilot, the same individual cat in every shot: jet-black short fur with no white markings, gold-amber eyes, small folded ears clearly visible through the ear openings of a brown leather flight helmet, goggles, white scarf, brown leather jacket, no aircraft insignia in frame, empty-handed or holding a map case or binoculars, no rifle by default, SFW, photoreal cinematic still
```

---

## 参考图目录与 Comfy 输入

| 代号 | 仓库图像位 | 期望文件 | Comfy 运行时 |
| --- | --- | --- | --- |
| A | `refs/cats/A/` | `cat-A-ginger-white.jpg`（或 `front.jpg`） | `$INPUT_ROOT/cats/A/raw/` |
| B | `refs/cats/B/` | `cat-B-silver-fold.jpg`（或 `front.jpg`） | `$INPUT_ROOT/cats/B/raw/` |
| C | `refs/cats/C/` | `cat-C-black-fold.jpg`（或 `front.jpg`） | `$INPUT_ROOT/cats/C/raw/` |

- `refs/cats/` 是仓库内唯一参考图入口；索引见 [`refs/cats/README.md`](refs/cats/README.md)。
- `scripts/restore.sh` 会把 `refs/cats/{A,B,C}/front.jpg` 或 `cat-*.jpg` **硬拷贝**到 `$INPUT_ROOT/cats/{A,B,C}/raw/`；目标已存在则跳过。
- 三张 jpg 已入库（首选名 + `front.jpg` 共六张，均非空），见 [`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)。
- 参考图仅用于本 SFW 宠物拟人项目；不得转投 `ai-realistic-comic/` 或任何 NSFW 管线。

---

## 双机实体（仅登记，未开机）

| 角色 | 实体 | 实例 ID | 区域 | GPU | 策略 |
| --- | --- | --- | --- | --- | --- |
| 母-Comfy定妆 | 025机 | `9b4c40bda6-dad38bb9` | 重庆A | RTX 4090D | shutdown 留盘 |
| 克隆-Wan | 003机 | `bb8c4f8e12-00c8bdac` | 重庆A | RTX 4090D | shutdown 留盘 |

- 任意时刻只开一台；两台当前均未开机，**不代表已开机或已跑 GPU**。
- 余额约 ¥17.25、未充值；开机 / 租卡 / 充值必须由用户明确授权。
- 详见 [`DUAL-CREATE-RESULT-2026-10-24.md`](DUAL-CREATE-RESULT-2026-10-24.md) 与 [`scripts/race_boot.md`](scripts/race_boot.md)。

---

## SFW 隔离与锁定纪律

- **仅 SFW**：禁止引用 `ai-realistic-comic/` 或任何去衣 / NSFW 资产、工作流、LoRA、提示词。
- 固定前缀开跑后不得逐条改写毛色、瞳色、耳形；只改动作、镜头、场景。
- 露耳优先：A 用钢盔耳洞，B/C 用帽 / 飞行帽耳部开口；不得用毛发或帽子完全遮耳。
- 少持枪：默认空手、旗、望远镜、地图包；叙事确需枪械时用远景 / 背影，枪口不对镜头。
- 群演、敌方均不得长得像 A/B/C；敌方只载具 / 剪影。
- 参考图必须保持为非空 jpg；文件名优先保持上表期望值。

## 互链

- 定妆卡：[`prompts/look_cards.md`](prompts/look_cards.md)
- 参考图索引：[`refs/cats/README.md`](refs/cats/README.md)
- 原图入库状态：[`refs/cats/MISSING-UPLOADS.md`](refs/cats/MISSING-UPLOADS.md)
- 双机结果：[`DUAL-CREATE-RESULT-2026-10-24.md`](DUAL-CREATE-RESULT-2026-10-24.md)
- 管线 SOP：[`README-PIPELINE.md`](README-PIPELINE.md)
- 进度日志：[`PROGRESS.md`](PROGRESS.md)
