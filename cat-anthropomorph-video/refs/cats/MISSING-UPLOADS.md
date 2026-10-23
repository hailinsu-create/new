# 待重传附件记录 · MISSING UPLOADS

记录日：**2026-10-24（Asia/Shanghai）**

## 结论

用户声称已上传的二进制附件**未在本机落地**。已按文件名全盘搜索（含 `/workspace` 与 `find / -xdev` 范围），均无匹配；仓库内也没有对应 jpg。  
因此本轮**只完成文档锁定与目录占位**，没有伪造、生成或下载任何猫照片。

## 缺失清单

| 用户所称附件 | 期望落点 | 当前状态 |
| --- | --- | --- |
| `CHARACTER-LOCK-2026-10-24_64b7.md` | 仓库根（任意） | **未找到**；已由权威字段重建为 [`../../CHARACTER-LOCK-2026-10-24.md`](../../CHARACTER-LOCK-2026-10-24.md) |
| `cat-A-ginger-white_2d3a.jpg` | `refs/cats/A/cat-A-ginger-white.jpg` | **未找到**；可用 `front.jpg` 替代 |
| `cat-B-silver-fold_0680.jpg` | `refs/cats/B/cat-B-silver-fold.jpg` | **未找到**；可用 `front.jpg` 替代 |
| `cat-C-black-fold_3796.jpg` | `refs/cats/C/cat-C-black-fold.jpg` | **未找到**；可用 `front.jpg` 替代 |
| `DUAL-CREATE-RESULT-2026-10-24_d231.md` | 仓库根 | **未找到**；已有同内容口径 [`../../DUAL-CREATE-RESULT-2026-10-24.md`](../../DUAL-CREATE-RESULT-2026-10-24.md) |

> 附件 ID 仅作为来源标记保留，不代表文件已存在于仓库或本机。

## 重传方法

把三张真实 jpg 放到对应目录，文件名二选一：

```text
refs/cats/A/cat-A-ginger-white.jpg   或   refs/cats/A/front.jpg
refs/cats/B/cat-B-silver-fold.jpg    或   refs/cats/B/front.jpg
refs/cats/C/cat-C-black-fold.jpg     或   refs/cats/C/front.jpg
```

重传后自检（必须全部为**非空文件**，且确实是用户家的猫）：

```bash
for f in refs/cats/{A,B,C}/front.jpg refs/cats/{A,B,C}/cat-*.jpg; do
  [ -e "$f" ] && { [ -s "$f" ] || echo "EMPTY: $f"; file "$f"; }
done
bash scripts/smoke_test.sh --dry-run
bash scripts/restore.sh --dry-run
```

`restore.sh` 会硬拷贝到 `$INPUT_ROOT/cats/{A,B,C}/raw/`；目标已有同名文件时跳过。

## 影响

- **不阻塞**：文档锁定、双机登记、离线 smoke dry-run。
- **阻塞**：P2 定妆真实出图 / 盲测 ≥80% 需要三张参考图实际到位。
- 缺图期间 `smoke_test.sh --dry-run` 会打印 `[smoke][WARN] 参考图待重传` 并仍 `exit 0`；若存在但为空文件则失败。

## 边界

- 仅 SFW；禁止从 `ai-realistic-comic/` 或任何 NSFW / 去衣目录取图。
- 不声称已开机、已跑 GPU 或已产生计费。
- 不提交他人猫图或网络图冒充用户猫咪。
