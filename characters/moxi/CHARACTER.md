# 墨汐（Mo Xi）

本仓库的原创 Live2D 角色。画稿与设定归本项目。

## 设定

| 项 | 内容 |
| --- | --- |
| 名字 | 墨汐 |
| 定位 | 研究台看板娘 / 自托管演示角色 |
| 气质 | 冷静、带一点墨色幽默；话不多，眼神先到 |
| 视觉 | 墨青短发、琥珀色眼睛、炭灰高领，呼应站点的海墨配色 |
| 用途 MVP | 半身 Cubism：idle + 张嘴。表情先 idle / talk / smile / surprise |

## 版权

- 角色原创，服务本仓库「自建 Live2D」目标
- **不是** Live2D 官方 Haru / Hiyori 等样例
- 研究台里的 Haru 仅作播放器对照

## 目录

```text
characters/moxi/
  CHARACTER.md
  art/                  主视觉与分层参考
  cubism/               绑定清单与 import 素材
public/models/moxi/     可加载 moc3 运行包
```

## 当前进度

- [x] 角色设定
- [x] 主视觉参考图
- [x] Cubism Editor（Wine）可启动
- [x] `character.json`（旁窗读缩放 / 口型 / 心情表）
- [x] 研究台默认加载本地墨汐 Cubism 包
- [x] 七层 ArtMesh moc3（body / 发 / 眼 / 嘴 / 流苏）+ 图集
- [x] `ParamMouthOpenY` 绑 `mouth_open` 透明度（Idle 闭嘴，Talk 张开）
- [ ] Editor 里补眨眼与其余表情关键形（不挡旁窗接入）
- [ ] 精细物理与十表情 moc3（不挡旁窗接入）
