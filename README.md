# 墨汐 · 庭前对口

国风立绘演示：默认全身站姿，也可切回半身。输入文字后按 viseme 对口型，能眨眼/浅笑等表情；刘海、侧发、披肩、裙摆和腰间流苏带弹簧二次运动。

角色底板是仓库里的原创立绘 **墨汐**——青绿短发 bob、琥珀色眼睛、黑色旗袍立领盘扣、水墨灰披肩、胸口纸鹤别针。全身版把旗袍接到中裙开衩、绣花布鞋，仍站在月下庭院里。

## 怎么用

```bash
npm install
npm test
npm run dev
```

浏览器打开终端里的本地地址（默认 `http://localhost:5173`）。

- 右上角切换 **半身 / 全身**（默认全身）。半身仍是原来的头像构图
- 在下方写台词，点 **开口**（或 `Ctrl/⌘ + Enter`）
- 语音优先用浏览器 `speechSynthesis`；没有中文语音时自动改成模拟声纹，也可选「仅口型」
- 点表情：平静 / 浅笑 / 开怀 / 讶异 / 低眉 / 含羞 / 眨眼 / 困倦
- 点口型芯片可单独卡住某个 viseme（啊衣乌诶哦…）看嘴形
- 拖「发丝」滑杆改变风力；鼠标在画布上移动会带动视线、头发和裙摆

构建：

```bash
npm run build
npm run preview
```

## 对口型怎么做

1. 中文按拼音拆声母/韵母，英文按字母簇，映射到 viseme：`A E I O U WQ M F L S rest`
2. 生成带时间戳的口型轴，说话时每帧采样并在原画嘴上覆盖对应形状
3. 开口瞬间给侧发和流苏一个冲量，形成说话时的连带摆动

## 目录

| 路径 | 作用 |
| --- | --- |
| `public/characters/moxi/base-plate.png` | 角色底板（透明半身） |
| `public/characters/moxi/portrait-rig/` | 半身：眼、刘海、侧发、流苏 |
| `public/characters/moxi/fullbody-rig/` | 全身底板 + 裙/披肩/腿/纸鹤等图层 |
| `public/bg/courtyard.jpg` | 月下庭院背景 |
| `src/avatar/viseme.ts` | 文字 → viseme 时间轴 |
| `src/avatar/speech.ts` | TTS / 模拟声纹 / 仅口型 |
| `src/avatar/motion.ts` | 眨眼 / 发丝 / 呼吸 / 全身二次运动 |
| `src/avatar/layout.ts` | 半身/全身坐标与资源 |
| `src/avatar/rig.ts` | Canvas 分层绑定与物理 |
| `src/main.ts` | 庭院界面 |

查询参数（截图/录屏用）：`?mute=1&expr=smile&hold=A&say=月色入庭&view=full`

- `view=full`（默认）全身站姿
- `view=bust` 半身头像
