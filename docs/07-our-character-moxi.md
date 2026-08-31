# 咱们的角色：墨汐

Haru 只用来测播放器。项目角色是原创的 **墨汐**。

旁窗那条线不在这个仓库里改。这里交出一份能丢进 APK 的 Cubism 包。

## 现在完成到哪

| 阶段 | 状态 |
| --- | --- |
| 设定与主视觉 | 完成（`characters/moxi/art/00_master_reference.png`） |
| Cubism Editor | Wine 5.3.03，`./tools/cubism/launch-editor.sh`，选 FREE |
| PSD | `python3 scripts/build-moxi-psd.py` → `characters/moxi/cubism/import/moxi.psd` |
| 运行包 | `public/models/moxi/`，含 `character.json` |
| 研究台默认 | 墨汐 Cubism moc3 |
| 张嘴 | `ParamMouthOpenY` 绑 `mouth_open` 透明度。Idle 闭嘴，Talk 张开 |

## 交给旁窗的目录

```text
public/models/moxi/          →  assets/live2d/model/moxi/
  character.json             # 缩放、锚点、ParamMouthOpenY、心情→表情
  moxi.model3.json
  moxi.moc3                  # SDK 5.0（moc3 v5），七层 ArtMesh
  moxi.2048/texture_00.png   # Cubism 图集名，不要改成 Mao 的路径
  expressions /              # idle talk smile surprise
  motions /                  # Idle + Talk
```

`character.json` 由 app 定义、这边填。没有这份表，Android 会继续为 Mao 写死 `ParamA` / `exp_01`。

口型参数是 `ParamMouthOpenY`，不是 Mao 的 `ParamA`。缩放走 `layout.scaleMode: portraitBust`，不要 `min(view, 3000)`。

心情：sad/angry → talk，shy → smile，sleepy → idle。肖像网格那十张脸不当 moc3 映射。

验收：

```bash
npm run check-model -- public/models/moxi
npm run fetch-core && npm run dev
```

## 已知边界

- 导出必须选 **For SDK 5.0 / Cubism5.0**。5.3 默认 moc3 v6，网页 Core 读不了
- FREE：每个 ArtMesh 最多 2 个参数。嘴、眼各自一层
- 肖像网格（`src/moxiRig.ts`）只作对照。覆盖型不好看，产品默认不要走那条
- 眨眼、难过/生气关键形还没进 moc3。旁窗先把多出来的 mood 并到 talk / smile / idle

## 重新导出之后

```bash
python3 scripts/pack-moxi-atlas.py
python3 scripts/bind-mouth-keyforms.py
python3 scripts/merge-cubism-export.py
```
