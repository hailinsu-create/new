# 动画技术路线：围绕墨汐

结论：**可以换，而且旁窗帧动画默认就是墨汐。** Live2D Cubism 继续精修；过关前用墨汐立绘 PNG 切帧撑产品。

## 角色

| 项 | 内容 |
| --- | --- |
| 角色 | **墨汐**（原创，不是粉发样例图） |
| 立绘源 | `characters/moxi/cubism/rig/00_full.png` |
| 生成 | `python3 scripts/build-moxi-frame-avatars.py` |
| 输出 | `android/.../drawable-xxhdpi/companion_avatar_*.png` |
| 预览 | `assets/moxi-frames/` |

资源名仍叫 `companion_avatar_*`，是为了兼容现有 Kotlin 引用；图面内容已换成墨汐。

## 帧表

| 资源 | 墨汐表现 |
| --- | --- |
| idle / talk / think / care | 立绘半身圆裁 |
| blink | 虹膜皮肤覆盖 + 闭眼弧线 |
| mouth_mid / mouth_open | 擦除原微笑后绘制口型 |
| happy / surprise | 半开 / 全开口型 |
| shy | 立绘 + 颊红 |

## 旁窗开关

设置：**「墨汐帧动画（不加载 Live2D）」**

- 打开 → 跳过 Cubism WebView，直接 `FrameAvatarAnimator`
- 关闭 → 仍先试 Live2D；连续失败自动锁回墨汐帧动画

## 与 Cubism 的关系

| 路线 | 用途 |
| --- | --- |
| 墨汐帧动画 | 旁窗近程可交付 |
| 墨汐 moc3 | 研究仓继续打磨口型网格；过关后再替换 WebView 模型 |
| Spine / Rive | 不优先 |

## 重导出

改了 `characters/moxi/cubism/rig/` 后：

```bash
python3 scripts/build-moxi-frame-avatars.py
cd android && ./gradlew :app:assembleDebug
```
