# 动画技术路线：Live2D 不成时怎么办

结论：**可以换，而且旁窗已经半成品。** Live2D 不是唯一路径；产品先要「悬浮窗里会眨眼、会张嘴说话的角色」，不必绑死 Cubism。

## 当前现状

| 路线 | 状态 | 适用 |
| --- | --- | --- |
| **Cubism Live2D**（墨汐 moc3 / Mao 样例） | 能加载；墨汐口型观感未过关；Editor/FREE 参数上限、Wine 建模成本高 | 目标质感最高，制作链路最重 |
| **PNG 帧动画**（`companion_avatar_*.png`） | 旁窗已有加载失败兜底；本分支升为可选主引擎 | **推荐 Plan B / 近程主路径** |
| **肖像网格**（研究仓 `moxiRig.ts`） | Web 对照用；非 Cubism | Web 验证表情，不直接进 Android 悬浮窗 |
| Spine / Rive | 未接入 | 中长期备选，不急 |

## 为什么可以换

旁窗真正依赖的能力只有：

1. 半身/头像常驻悬浮窗  
2. 按文案情绪切表情  
3. 说话时口型动起来  
4. 失败时不能白屏  

这些用 **多张 PNG + Handler 切帧** 就能做。现成资源：

- `companion_avatar_idle / think / happy / care / surprise / shy / talk`
- `companion_avatar_blink`
- `companion_avatar_mouth_mid / mouth_open`

Live2D WebView 挂了时，本来就会落到 `ImageView`；差的是说话时没有口型循环。Plan B 把这块补上，并允许用户**主动关掉 Live2D**。

## 选型建议

### 近程（旁窗能卖、能演示）

用 **帧动画引擎** 作为默认或可选主路径：

- 无 WebView / WebGL / Cubism Core  
- 包体小、OEM 兼容好  
- 换脸=换图，不需要 Cubism Editor  
- 口型用 closed → mid → open 三档抖动即可  

设置里开关：**「使用帧动画（不加载 Live2D）」**。未勾选时仍先试 Live2D；多次失败后自动锁到帧动画。

### 中程（质感要上去、但仍可控）

继续打磨 **墨汐 Cubism**（研究仓），过关后再替换 Mao / 帧图。口型必须走网格形变，不要半透明贴片叠嘴。

### 不优先

| 方案 | 原因 |
| --- | --- |
| Spine | 授权与骨骼制作成本接近再开一条生产线 |
| Rive | 适合 UI 动效，二次元立绘管线不如帧图/Live2D 成熟 |
| 纯 Canvas 覆盖层变形 | 产品侧已明确不想当默认；研究台对照即可 |

## 决策规则（给后续 agent）

1. **Live2D 口型/建模短期过不了关 → 不阻塞旁窗发版**，切帧动画。  
2. Live2D 与帧动画共用 `CompanionMood` / `speak(text, mood)` 接口，上层 Overlay 不感知引擎。  
3. 墨汐 Live2D 研究继续独立推进；过关后再接回 `assets/live2d/model/`。  
4. 不要为了「换技术」同时上 Spine + Rive；一次只保一条可交付路径。

## 本仓库开关

- Pref：`prefer_frame_avatar`  
- UI：设置页「使用帧动画（不加载 Live2D）」  
- 运行时：Live2D 连续失败后自动 `lockToFrames()`  
