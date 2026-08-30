# 自建 Live2D：墨汐

目标不是套官方样例，而是做出**咱们自己的**角色，并在网页里跑起来。

当前原创角色：**墨汐**。立绘与设定在 `characters/moxi/`。Cubism Editor 已通过 Wine 装好；**墨汐 moc3 已导出**到 `public/models/moxi/`，研究台默认加载。

## 现在能做什么

```bash
npm install
npm run fetch-core
npm run dev
```

打开研究台会默认进入**墨汐立绘预览**（原创静帧 + 轻微视差）。Haru 仍留在预设里，仅作播放器对照。

## Cubism Editor（已装）

Linux 上通过 Wine 安装了 Cubism Editor 5.3.03（非官方）：

```bash
./tools/cubism/launch-editor.sh
```

可从免费版启动。说明见 `tools/cubism/README.md`。

## 做成真 Live2D 的最短路径

1. 读 `characters/moxi/cubism/BINDING_CHECKLIST.md`
2. 用主视觉拆 PSD → Cubism 网格/参数 → 导出 moc3
3. 复制到 `public/models/moxi/`
4. `npm run check-model -- public/models/moxi`
5. 研究台选「墨汐（本地 moc3）」

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/07-our-character-moxi.md](docs/07-our-character-moxi.md) | 墨汐进度与边界 |
| [docs/02-creation-pipeline.md](docs/02-creation-pipeline.md) | 通用制作流程 |
| [docs/03-runtime-package.md](docs/03-runtime-package.md) | moc3 包结构 |
| [docs/04-web-selfhost.md](docs/04-web-selfhost.md) | Web 自托管 |
| [docs/05-license-and-compliance.md](docs/05-license-and-compliance.md) | 授权 |

## 版权

- 墨汐：本项目原创角色资产
- Haru 等官方样例：Live2D Inc.，仅对照
- Cubism Core：专有库，`npm run fetch-core` 本地拉取，不进 git
