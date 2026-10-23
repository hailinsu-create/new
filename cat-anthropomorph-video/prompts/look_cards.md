# 三猫定妆卡（已锁定 · SFW）

锁定日：**2026-10-24（Asia/Shanghai）**。以下名字 / 毛色 / 瞳色 / 耳形 / 主装 / 场景为量产锁定值；未经确认不得临时改毛色或瞳色。

> **参考图路径约定**：仓库内优先使用 `refs/cats/{A,B,C}/`（期望 `cat-A-ginger-white.jpg` / `cat-B-silver-fold.jpg` / `cat-C-black-fold.jpg`，兼容 `front.jpg`）；运行时可从 refs 复制到 ComfyUI 的 `$INPUT_ROOT/cats/{A,B,C}/raw/`。三张实拍 jpg 当前**待重传**，见 `refs/cats/MISSING-UPLOADS.md`。
>
> **权威总锁**：[`../CHARACTER-LOCK-2026-10-24.md`](../CHARACTER-LOCK-2026-10-24.md)（角色表、固定前缀、双机 ID、SFW 隔离）。
>
> **用法**：先粘贴该猫「固定提示词前缀」，再接动作/镜头句（`prompts/positive_fragments.md`）；负向整段使用 `prompts/negative.txt`。露耳优先，少持枪。

## A · 小橘（美军 / 诺曼底）

| 字段 | 值 |
| --- | --- |
| 代号 / 名字 | A / **小橘** |
| 毛色 | 橘白长毛 |
| 花纹位置 | 头顶、背脊、尾巴为橘色虎斑块；口鼻、胸口、四爪为白色 |
| 瞳色 | 琥珀铜色 |
| 耳形 | 直立大耳，耳尖有长毛簇，耳内粉色 |
| 胡须 | 白色长胡须 |
| 体型 | 中大型长毛猫，蓬松 |
| 主装 | 美军 M1 钢盔（耳部开口露耳）+ 橄榄绿野战夹克 + 红领巾 + 帆布腰带 |
| 场景 | 1944 诺曼底登陆艇内 / 沙滩，硝烟与冷灰天光 |
| 参考图路径 | `refs/cats/A/`（`cat-A-ginger-white.jpg` 或 `front.jpg`；运行时同步到 `$INPUT_ROOT/cats/A/raw/`） |
| 固定提示词前缀 | `anthropomorphic orange-and-white long-haired cat, the same individual cat in every shot: orange tabby patches on head, back and tail, white muzzle, chest and paws, long fluffy fur, amber-copper eyes, large upright tufted ears clearly visible through a US M1 helmet with ear cutouts, olive-drab WWII US infantry jacket, red neckerchief, empty-handed or holding a flag, binoculars or map case, no rifle by default, SFW, photoreal cinematic still` |

## B · 银宝（苏军 / 斯大林格勒）

| 字段 | 值 |
| --- | --- |
| 代号 / 名字 | B / **银宝** |
| 毛色 | 银虎斑 |
| 花纹位置 | 银灰底配深灰虎斑条纹；口鼻与胸口较浅 |
| 瞳色 | 浅绿色 |
| 耳形 | 折耳，小耳向前折下 |
| 胡须 | 白色长胡须 |
| 体型 | 中小型短毛猫，紧凑 |
| 主装 | 苏军船形帽或毛帽（耳部开口露出折耳）+ 红星帽徽 + 卡其色制服 + 腰带 |
| 场景 | 1942–43 斯大林格勒废墟 / 破窗与火光剪影 |
| 参考图路径 | `refs/cats/B/`（`cat-B-silver-fold.jpg` 或 `front.jpg`；运行时同步到 `$INPUT_ROOT/cats/B/raw/`） |
| 固定提示词前缀 | `anthropomorphic silver tabby Scottish Fold cat, the same individual cat in every shot: silver-gray coat with dark tabby stripes, lighter muzzle and chest, pale green eyes, small folded ears clearly emerging from the ear openings of a Soviet side cap or ushanka, red star cap badge, khaki WWII Soviet uniform, empty-handed or holding a flag, binoculars or map case, no rifle by default, SFW, photoreal cinematic still` |

## C · 墨墨（飞行员 / 中途岛）

| 字段 | 值 |
| --- | --- |
| 代号 / 名字 | C / **墨墨** |
| 毛色 | 全黑 |
| 花纹位置 | 通体纯黑，无白斑；强光下允许极轻微暖棕反光，但不得出现白袜/白胸 |
| 瞳色 | 金琥珀色 |
| 耳形 | 折耳，小耳向前折下 |
| 胡须 | 黑色 / 深色胡须 |
| 体型 | 中小型短毛猫，紧凑 |
| 主装 | 棕色皮飞行帽（耳部开口露折耳）+ 风镜 + 白围巾 + 皮夹克；机徽一律不入画 |
| 场景 | 1942 中途岛航母甲板 / 海天背景，起飞或返航定格 |
| 参考图路径 | `refs/cats/C/`（`cat-C-black-fold.jpg` 或 `front.jpg`；运行时同步到 `$INPUT_ROOT/cats/C/raw/`） |
| 固定提示词前缀 | `anthropomorphic solid-black Scottish Fold cat pilot, the same individual cat in every shot: jet-black short fur with no white markings, gold-amber eyes, small folded ears clearly visible through the ear openings of a brown leather flight helmet, goggles, white scarf, brown leather jacket, no aircraft insignia in frame, empty-handed or holding a map case or binoculars, no rifle by default, SFW, photoreal cinematic still` |

## 锁定与隔离

- 每猫固定前缀一旦开跑不得逐条改写毛色 / 瞳色 / 耳形；只改动作、镜头、场景。
- 露耳：A 用钢盔耳洞，B/C 用帽/飞行帽耳部开口；不得用毛发或帽子完全遮耳。
- 少持枪：默认空手、旗、望远镜、地图包；叙事确需枪械时用远景/背影且枪口不对镜头。
- **SFW only**：禁止引用 `ai-realistic-comic/` 或任何去衣 / NSFW 资产。

## 关联

- 权威定妆锁定：[`../CHARACTER-LOCK-2026-10-24.md`](../CHARACTER-LOCK-2026-10-24.md)
- 参考图索引：[`../refs/cats/README.md`](../refs/cats/README.md)
- 缺失附件与重传：[`../refs/cats/MISSING-UPLOADS.md`](../refs/cats/MISSING-UPLOADS.md)
