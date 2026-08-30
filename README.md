# 自建 Live2D 角色研究

从分层立绘到浏览器可播的 moc3 包：流程笔记 + 本地验证台。

## 这项目解决什么

自建 Live2D 角色会卡在三件事上：Cubism 怎么做、导出包缺什么、网页怎么加载。本仓库把这三段拆开写清楚，并给一个 PixiJS 研究台，用来加载官方样例或你自己的模型。

## 快速开始

```bash
npm install
npm run fetch-core   # 下载 Cubism Core 到 public/（不进 git）
npm run dev
```

打开提示的本地地址。先点「加载模型」跑远程 Haru，确认播放器正常；再把自建导出包放进 `public/models/local/`，把路径改成你的 `*.model3.json`。

检查导出包：

```bash
npm run check-model -- public/models/local
```

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/01-overview.md](docs/01-overview.md) | 结论与仓库地图 |
| [docs/02-creation-pipeline.md](docs/02-creation-pipeline.md) | 立绘 → 建模 → 导出 |
| [docs/03-runtime-package.md](docs/03-runtime-package.md) | moc3 / model3 文件说明 |
| [docs/04-web-selfhost.md](docs/04-web-selfhost.md) | Web 自托管 |
| [docs/05-license-and-compliance.md](docs/05-license-and-compliance.md) | 授权红线 |
| [docs/06-research-log.md](docs/06-research-log.md) | 已验证结论与下一步 |

## 技术要点

- Cubism Editor 产出嵌入包；浏览器用 Cubism Core 解析 `moc3`
- 研究台：`pixi.js@6` + `pixi-live2d-display/cubism4`
- Core 专有，本仓库不托管该二进制；用 `fetch-core` 按需拉取
- 远程样例仅供链路验证，上线角色请用你自有授权的模型

## 许可

仓库内原创文档与代码按仓库 LICENSE（若未添加则为研究草稿，使用前自行明确）。Live2D Cubism Editor / SDK / Core / Sample 模型遵循 Live2D 官方许可，与本仓库条款分离。
