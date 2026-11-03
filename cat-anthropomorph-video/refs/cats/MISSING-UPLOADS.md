# 三猫原图已入库 · REFS LANDED

> 本文件保留 `MISSING-UPLOADS.md` 文件名以兼容既有链接，内容已更新为入库状态页。

记录日：**2026-10-24（Asia/Shanghai）**

入库 tip：`3abef51`（本轮仅文档收尾，未新增二进制）

## 结论

三猫原图已全部入库，共六张 jpg：每只猫同时提供首选文件名与 `front.jpg` 兼容副本，均为非空真实 jpg。`refs/cats/{A,B,C}/.gitkeep` 仅作空目录历史占位，不影响使用。

## 入库清单

| 猫 | 路径 | 字节数 |
| --- | --- | --- |
| A 小橘 | `refs/cats/A/cat-A-ginger-white.jpg` | 262169 |
| A 小橘 | `refs/cats/A/front.jpg` | 262169 |
| B 银宝 | `refs/cats/B/cat-B-silver-fold.jpg` | 247783 |
| B 银宝 | `refs/cats/B/front.jpg` | 247783 |
| C 墨墨 | `refs/cats/C/cat-C-black-fold.jpg` | 183198 |
| C 墨墨 | `refs/cats/C/front.jpg` | 183198 |

首选名与 `front.jpg` 字节数一致，互为同一原图副本。

## 校验

```bash
for f in refs/cats/{A,B,C}/front.jpg refs/cats/{A,B,C}/cat-*.jpg; do
  [ -s "$f" ] || echo "EMPTY: $f"
done
bash scripts/smoke_test.sh --dry-run
bash scripts/restore.sh --dry-run
```

- `smoke_test.sh --dry-run` 已通过，`refs/cats` 六张 jpg 非空，无缺图 WARN。
- `restore.sh` 会硬拷贝到 `$INPUT_ROOT/cats/{A,B,C}/raw/`；目标已有同名文件时跳过。

## 边界

- 仅 SFW；禁止从 `ai-realistic-comic/` 或任何 NSFW / 去衣目录取图。
- 不声称已开机、已跑 GPU 或已产生计费。
- 仅使用用户提供的三猫原图，不以他人猫图或网络图冒充。
