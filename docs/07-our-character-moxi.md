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


## 肖像网格重制版（当前默认）

上一版粗切眼、嘴后直接拼接，圆形遮罩和独立嘴层有明显贴纸感，已废弃。当前 `src/moxiRig.ts` 改为：

- 保留完整原画，只从底图中精确移除虹膜区域
- 开眼素材只覆盖眼睛本身，眨眼时做局部纵向变形
- 转头用 96 条连续图像带做轻量透视，位移收小，减少切片切穿
- 眼层画完后用刘海遮罩扣掉，避免眼睛画到刘海上
- 侧发用脸部椭圆裁切，并限制摆幅，减少扫进脸颊
- 表情切换会眨眼一下，通道用不同速度弹簧，大笑弹跳会衰减
- 底图眼窝、碎点、发梢黑边又清过一轮
- surprise 口型尺寸受控，并有皮肤渐变过渡
- 呼吸只影响胸肩区域，不再让整张海报大幅摇摆
- 青色侧发与腰间流苏从静态底图中拆出，使用弹簧惯性；方向变化后会滞后、过冲并回弹
- 表情按区块走：眼开合、下眼睑、眉形、嘴型、颊红、高光、泪和汗分开插值
- 表情：neutral / smile / laugh / surprise / sad / angry / shy / wink / talk / sleepy
- 嘴线按 3/4 视角倾斜，先用肤色盖住原嘴再画，避免叠出双唇线
- 眼窝残留虹膜已用肤色填平，闭眼时不再露出脏色块

这版没有黑眼洞、圆形遮罩或切片裂缝。它仍不是高规格 Cubism 成品：嘴角不会牵动脸颊，目前也只有一束侧发和一条流苏具备独立物理。Cubism moc3 保留作 SDK 对照。
