# ai-realistic-comic

云端 AI **真人质感**漫画最小生成流水线（CLI）。题材预设：仙侠 / 奇幻 / 科幻。用角色卡 + 定妆参考图维持跨格一致性。

> 本目录当前暂存在 [`hailinsu-create/new`](https://github.com/hailinsu-create/new) 仓库内（Cloud Agent token 无法 `gh repo create`）。你在 GitHub 建好空仓库 `ai-realistic-comic` 后，可把本目录迁出为独立 repo。

## 主路径：fal.ai（角色一致性）

默认 `IMAGE_PROVIDER=fal`：
- 定妆 / 无参考：`fal-ai/flux/dev`
- 有角色参考图：`fal-ai/flux-pulid`（锁脸）

以后切 AutoDL/ComfyUI 只需改 `IMAGE_PROVIDER=comfy` + `COMFY_API_URL`（角色卡/分镜/定妆图不用动）。见 [docs/provider-switch.md](docs/provider-switch.md)。

```bash
cd ai-realistic-comic
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
# 写入 FAL_KEY=...（Cloud Agent Secrets 或本地 export）
comic doctor
comic cast demo-spider-wukong --id zhizhu --name 蜘蛛精 --make-ref
comic generate demo-spider-wukong --force
comic assemble demo-spider-wukong
```

也可用 `comic run <project>` 一条龙（分镜无 `OPENAI_API_KEY` 时用内置 mock episode）。

## 离线 Mock（仅 CI / 无 Key）

```bash
COMIC_MOCK=1 comic run demo-xianxia
pytest -q
```

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
