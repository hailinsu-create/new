# 墨汐（Mo Xi）

本仓库的原创 Live2D 角色。画稿与设定归本项目；最终 `moc3` 需在 Cubism Editor 中由本立绘包绑定导出。

## 设定

| 项 | 内容 |
| --- | --- |
| 名字 | 墨汐 |
| 定位 | 研究台看板娘 / 自托管演示角色 |
| 气质 | 冷静、带一点墨色幽默；话不多，眼神先到 |
| 视觉 | 墨青短发、琥珀色眼睛、炭灰高领，呼应站点的海墨配色 |
| 用途 MVP | 半身、转头、眨眼、视线、张嘴、一条 idle |

## 版权

- 角色原创，服务本仓库「自建 Live2D」目标
- **不是** Live2D 官方 Haru / Hiyori 等样例
- 研究台里的 Haru 仅作播放器对照，默认不再作为主角色

## 目录

```text
characters/moxi/
  CHARACTER.md          ← 本文件
  art/                  ← 主视觉与分层 PNG
  cubism/               ← 给 Editor 用的导入说明与清单
public/models/moxi/     ← 导出 moc3 后放这里供网页加载
```

## 当前进度

- [x] 角色设定
- [x] 主视觉参考图
- [x] 分层 PNG 包（Cubism 导入用）
- [ ] Cubism Editor：网格 / 变形器 / 参数 / 物理
- [ ] 导出 `moxi.model3.json` + `moxi.moc3` + textures
- [ ] 研究台默认加载本地墨汐

没有 Cubism 之前，研究台用主视觉静帧占位，提醒「待绑定」。
