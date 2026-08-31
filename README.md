# 自建 Live2D：墨汐

目标不是套官方样例，而是做出**咱们自己的**角色，并在网页里跑起来。

当前原创角色：**墨汐**。立绘与设定在 `characters/moxi/`。研究台默认加载重制后的肖像网格；Cubism moc3 保留作运行时对照。

## 现在能做什么

```bash
npm install
npm run fetch-core
npm run dev
```

打开研究台默认进入**墨汐肖像网格重制版**：

- 保留完整原画，不再拼接粗切的脸部图层
- 眼睛局部变形，自动眨眼
- 指针驱动视线与头部透视
- `neutral` / `smile` / `surprise` 平滑切换

Haru 仍留在预设里，仅作播放器对照。

## Cubism Editor（已装）

Linux 上通过 Wine 安装了 Cubism Editor 5.3.03（非官方）：

```bash
./tools/cubism/launch-editor.sh
```

可从免费版启动。说明见 `tools/cubism/README.md`。

## Cubism moc3 对照

`public/models/moxi/` 是 Cubism FREE 导出的单网格模型。它能验证 SDK 加载，但关键形不足，不是默认展示效果。完整 Cubism 成品仍需手工绘制分层 PSD，再做眼、嘴、头发和物理绑定。

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
