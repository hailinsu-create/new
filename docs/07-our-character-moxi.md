# 咱们的角色：墨汐

Haru 是 Live2D 官方样例，只用来测播放器。项目目标角色是原创的 **墨汐**。

## 现在完成到哪

| 阶段 | 状态 |
| --- | --- |
| 设定与主视觉 | 完成（`characters/moxi/art/00_master_reference.png`） |
| 分层参考稿 | 有草稿（`art/layers*`，需在 PS/CSP 按主视觉重拆） |
| Cubism Editor 安装 | 完成（Wine 非官方，`tools/cubism/`，5.3.03） |
| Cubism 网格/参数 | 进行中（Editor 可启动，待拆 PSD 后绑定） |
| `public/models/moxi/*.moc3` | 未完成 |
| 研究台默认展示墨汐 | 完成（静帧预览 + 待绑定提示） |

Linux 上无官方 Cubism，当前用 Wine 跑 Windows 版。启动：

```bash
./tools/cubism/launch-editor.sh
```

细节见 `tools/cubism/README.md`。

## 你这边下一步（最短路径）

1. 启动 Editor：`./tools/cubism/launch-editor.sh`（选 FREE 即可）
2. 打开 `characters/moxi/cubism/BINDING_CHECKLIST.md`
3. 用主视觉拆 PSD → Cubism 网格/参数 → 导出 moc3
4. 复制到 `public/models/moxi/`
5. `npm run check-model -- public/models/moxi` 后，在研究台选「墨汐（本地）」

## 和 Haru 的关系

- Haru：别人的版权，对照用
- 墨汐：咱们的角色，主路径
