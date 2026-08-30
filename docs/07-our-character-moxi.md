# 咱们的角色：墨汐

Haru 是 Live2D 官方样例，只用来测播放器。项目目标角色是原创的 **墨汐**。

## 现在完成到哪

| 阶段 | 状态 |
| --- | --- |
| 设定与主视觉 | 完成（`characters/moxi/art/00_master_reference.png`） |
| 分层参考稿 | 有草稿（`art/layers*`，需在 PS/CSP 按主视觉重拆） |
| Cubism 网格/参数 | 未完成（需本机 Cubism Editor） |
| `public/models/moxi/*.moc3` | 未完成 |
| 研究台默认展示墨汐 | 完成（静帧预览 + 待绑定提示） |

云端环境装不了 Cubism GUI，所以 **moc3 这一步要在你自己的电脑上做**。立绘包和验收台已经按「加载自有模型」备好。

## 你本机下一步（最短路径）

1. 打开 `characters/moxi/cubism/BINDING_CHECKLIST.md`
2. 用主视觉拆 PSD → Cubism 绑定 → 导出 moc3
3. 把导出包放进 `public/models/moxi/`
4. `npm run check-model -- public/models/moxi` 后，在研究台选「墨汐（本地）」

## 和 Haru 的关系

- Haru：别人的版权，对照用
- 墨汐：咱们的角色，主路径
