# 旁窗 APK 角色包

研究台和 Android 读同一份目录：`public/models/moxi/`。

复制到 APK：

```text
public/models/moxi/  →  assets/live2d/model/moxi/
```

贴图在 `moxi.2048/texture_00.png`，以 `moxi.model3.json` 为准。不要改路径名。旁窗只读 `character.json`，不要再为 Mao 写死 `ParamA` / `exp_01`。

## character.json

| 字段 | 给谁用 |
| --- | --- |
| `layout.scale` / `anchorX` / `anchorY` | 悬浮窗半身肖像。禁止 `min/3000` |
| `lipSync.parameter` | 口型。墨汐是 `ParamMouthOpenY` |
| `lipSync.group` | SDK LipSync 组名 |
| `idle.motionGroup` | `Idle` |
| `moods` | 7 种心情 → 现有 4 个表情。难过/生气先并到 `talk`，害羞并到 `smile`，困倦并到 `idle` |

表情文件只要这四个：`idle` / `talk` / `smile` / `surprise`。十种肖像网格表情不当 moc3 映射。

网格、物理、关键形只在 Cubism 里改，不要在旁窗仓库里画一套墨汐。
