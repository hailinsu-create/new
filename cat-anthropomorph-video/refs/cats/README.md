# 三猫参考图 · refs/cats

本目录是 `cat-anthropomorph-video/` 的**仓库内参考图唯一入口**，仅存放用户提供的 SFW 真猫照片。

## 目录结构

```text
refs/cats/
├── README.md
├── MISSING-UPLOADS.md  # 已入库状态页（文件名保留）
├── A/  # 小橘 · 橘白长毛 · 美军 / 诺曼底
│   ├── cat-A-ginger-white.jpg
│   └── front.jpg
├── B/  # 银宝 · 银虎斑折耳 · 苏军 / 斯大林格勒
│   ├── cat-B-silver-fold.jpg
│   └── front.jpg
└── C/  # 墨墨 · 全黑折耳 · 飞行员 / 中途岛
    ├── cat-C-black-fold.jpg
    └── front.jpg
```

## 已入库文件

| 代号 | 名字 | 首选文件名 | 兼容文件名 | 字节数 | 状态 |
| --- | --- | --- | --- | --- | --- |
| A | 小橘 | `A/cat-A-ginger-white.jpg` | `A/front.jpg` | 262169 | **已入库** |
| B | 银宝 | `B/cat-B-silver-fold.jpg` | `B/front.jpg` | 247783 | **已入库** |
| C | 墨墨 | `C/cat-C-black-fold.jpg` | `C/front.jpg` | 183198 | **已入库** |

六张 jpg 均已入库且非空；首选名与 `front.jpg` 为同一原图副本。入库状态与完整路径见 [`MISSING-UPLOADS.md`](MISSING-UPLOADS.md)。

## 命名与质量

- 只用 `.jpg`（小写扩展名）；必须是**非空真实文件**，不得用占位图、生成图或他人猫图冒充。
- 首选正脸清晰照：能看清毛色花纹、瞳色、耳形（A 直立耳 / B、C 折耳）。
- 侧脸 / 毛量 / 3/4 图可后续补充，命名如 `side_or_fur.jpg`、`three_quarter.jpg`。
- 单人单猫，避免多人、强烈滤镜、遮挡耳朵；不要包含任何 NSFW 内容。
- 是否将用户原图提交进 Git，以用户授权为准；未授权时只在本机保留。

## 运行时映射

`scripts/restore.sh` 会把本目录下的 `front.jpg` 或 `cat-*.jpg` **硬拷贝**到 ComfyUI 输入目录：

```text
refs/cats/A/...  ->  $INPUT_ROOT/cats/A/raw/
refs/cats/B/...  ->  $INPUT_ROOT/cats/B/raw/
refs/cats/C/...  ->  $INPUT_ROOT/cats/C/raw/
```

目标已存在则跳过，不覆盖用户在 GPU 机上手工放置的版本。`bash scripts/restore.sh --dry-run` 也会执行该本地同步，不会下载权重或开机。

## 权威文档

- 定妆锁定：[`../../CHARACTER-LOCK-2026-10-24.md`](../../CHARACTER-LOCK-2026-10-24.md)
- 提示词前缀：[`../../prompts/look_cards.md`](../../prompts/look_cards.md)
- 管线 SOP：[`../../README-PIPELINE.md`](../../README-PIPELINE.md)

## 隔离

仅限本项目 SFW 小猫拟人使用。**禁止**复制、链接或引用到 `ai-realistic-comic/`、任何 NSFW / 去衣资产或工作流。
