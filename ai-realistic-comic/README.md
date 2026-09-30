# ai-realistic-comic

云端 AI **真人质感**漫画最小生成流水线（CLI）。题材预设：仙侠 / 奇幻 / 科幻。用角色卡 + 定妆参考图维持跨格一致性。

> 本目录当前暂存在 [`hailinsu-create/new`](https://github.com/hailinsu-create/new) 仓库内（Cloud Agent token 无法 `gh repo create`）。你在 GitHub 建好空仓库 `ai-realistic-comic` 后，可把本目录迁出为独立 repo。

## 快速开始（Mock，无需 API Key）

```bash
cd ai-realistic-comic
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env   # COMIC_MOCK=1
comic run demo-xianxia
# 输出：output/demo-xianxia/panels/*.png 与 pages/page_01.png
pytest -q
```

## 实网出图

1. 在 `.env` 设置 `COMIC_MOCK=0`、`FAL_KEY`、`OPENAI_API_KEY`（可选自定义 `OPENAI_BASE_URL`）。
2. 为角色生成/放入定妆图：`comic cast demo-xianxia --id lin_zhuiguang --name 林追光 ...`（默认 `make_ref`）。
3. `comic run demo-xianxia` 或分步：`plan` → `generate` → `assemble`。

## CLI

| 命令 | 作用 |
|------|------|
| `comic init <slug> --genre xianxia` | 新建项目 |
| `comic cast <project> --id ...` | 角色卡 + 可选定妆图 |
| `comic plan <project>` | `story.md` → `episode.yaml` |
| `comic generate <project>` | 逐格出图（带缓存） |
| `comic assemble <project>` | 2×3 拼页或竖条漫 |
| `comic run <project>` | 上面三步一条龙 |

## 一致性策略（MVP）

- 角色圣经字段强制写入每格 prompt，服装默认锁定。
- 每格携带角色参考图（fal img2img / mock 占位）。
- 题材风格锚固定「电影级真人摄影，非二次元」。
- 同 panel 内容 hash 命中缓存，避免重复扣费。

## 迁出独立仓库

```bash
# 在 GitHub 创建空仓库 hailinsu-create/ai-realistic-comic 之后：
cd ai-realistic-comic
git init -b main
git add .
git commit -m "Initial AI realistic comic pipeline"
git remote add origin https://github.com/hailinsu-create/ai-realistic-comic.git
git push -u origin main
```
