# 咱们的角色：墨汐

Haru 是 Live2D 官方样例，只用来测播放器。项目目标角色是原创的 **墨汐**。

## 现在完成到哪

| 阶段 | 状态 |
| --- | --- |
| 设定与主视觉 | 完成（`characters/moxi/art/00_master_reference.png`） |
| 分层参考稿 | 有草稿（精修拆分仍建议在 PS/CSP 做） |
| Cubism Editor 安装 | 完成（Wine，`tools/cubism/`，5.3.03 FREE） |
| Cubism 网格 / 导出 | MVP 完成：单网格，导出 **SDK 5.0** 兼容 moc3 |
| `public/models/moxi/*.moc3` | 完成，研究台可加载 |
| 研究台默认角色 | 墨汐 Live2D |

启动 Editor：

```bash
./tools/cubism/launch-editor.sh
```

## 运行时包

```text
public/models/moxi/
  moxi.model3.json
  moxi.moc3          # moc3 v5（SDK 5.0 导出目标）
  moxi.cdi3.json
  moxi.1024/texture_00.png
```

验收：

```bash
npm run check-model -- public/models/moxi
npm run fetch-core && npm run dev
```

默认预设加载 `/models/moxi/moxi.model3.json`。

## 已知边界（MVP）

- 当前是**单 ArtMesh**，不是精细五官分层；转头/眨眼/口型还可以继续加
- Cubism 5.3 默认导出 moc3 v6，网页 Core 读不了；导出时选 **For SDK 5.0 / Cubism5.0**
- Wine + FREE 可用，复杂工程可能卡；正式制作也可换 Windows/macOS 官方 Editor

## 下一步

1. PS/CSP 按主视觉精拆 PSD（眼、嘴、前后发）
2. Cubism 里加 Angle / EyeOpen / Mouth / Breath 与物理
3. 导出动作 `Idle`，再写入 `model3.json`
