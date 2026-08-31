# 旁窗（Android）

开源桌面伴侣：悬浮窗里的角色会从屏幕认出你在用什么 App、在干什么，再用扫地僧那种点到为止的口吻说两句。灵感接近 Animates 一类陪伴窗，整条链路开源、可自建视觉模型。

## 动画技术：Live2D 不成也能用

**可以换路线。** Live2D（Cubism WebView）是默认引擎；若加载失败或墨汐模型口型未过关，旁窗会落到 **PNG 帧动画**（眨眼 + 口型 mid/open），产品不堵死。

设置页开关：**「使用帧动画（不加载 Live2D）」** —— 主动跳过 Cubism。未勾选时仍先试 Live2D，连续失败后自动锁帧动画。

选型说明见 [docs/animation-tech-routes.md](docs/animation-tech-routes.md)。墨汐 Cubism 精修在独立研究分支继续；过关后再接回 `assets/live2d/model/`。

## 真机怎么用（主路径）

1. 开 **悬浮窗** 权限  
2. （可选）开 **使用情况访问**，前台 App 提示更准；不开也能单靠截图识别  
3. **关掉「演示陪伴语」**，填视觉模型（SiliconFlow / Ollama 等 OpenAI 兼容接口）  
4. （可选）Live2D 不稳时打开 **「使用帧动画」**  
5. 点 **「召唤小旁陪看屏幕」** → 允许系统「屏幕录制」  
6. 去刷微信 / 浏览器 / 短视频；小旁截当前画面 → 认出场景 → 说两句相关的  
7. **长按头像**立刻再说一句；短按显隐气泡  

「仅演示悬浮窗」只验证小窗形态，**不看真屏**。

```
你刷其它 App
    ↓
MediaProjection 截帧（截前隐藏头像）
    ↓
（可选）UsageStats 前台包名提示
    ↓
画面变化？ → Vision API（Qwen-VL 等）识别 App + 正在做的事
    ↓
扫地僧语气一两句 → 悬浮气泡 + Live2D 或帧动画
```

锁屏或仍在锁机界面时会自动暂停截屏和视觉 API 调用（省 token）；解锁后恢复，并马上再看一眼。

Live2D 用透明 WebView + Cubism 4（`pixi-live2d-display`）渲染；说话时驱动口型参数，并按文案情绪切换 expression。样例模型来自 [CubismWebSamples](https://github.com/Live2D/CubismWebSamples) 的 Mao，受 Live2D 样例素材许可约束。帧动画用 `res/drawable-xxhdpi/companion_avatar_*.png`。

## 本机 USB 安装

```bash
git pull
cd android
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell appops set com.pangchuang.app SYSTEM_ALERT_WINDOW allow
adb shell am start -n com.pangchuang.app/.MainActivity
```

最低 Android 8.0（API 26），target 34。

## 设置项

| 项 | 说明 |
|----|------|
| Base URL | 如 `https://api.siliconflow.cn/v1` 或 `http://127.0.0.1:11434/v1` |
| API Key | 真陪伴必填；空则只能演示陪伴语 |
| Vision Model | 推荐 `Qwen/Qwen3-VL-8B-Instruct`（快）或 `Qwen/Qwen3-VL-32B-Instruct`（更准、更慢，偶发 500 会自动重试） |
| 陪伴间隔 | 默认 12 秒；画面几乎没变会跳过 |
| 演示陪伴语 | 不调 API |
| 使用帧动画 | 不加载 Live2D；PNG 表情 + 口型切帧 |
| 使用情况访问 | 可选；开启后把前台 App 名一并交给模型 |

## 模拟器（可选）

云 VM 嵌套 KVM 常不可用，需 `EMU_ACCEL=off`：

```bash
./scripts/setup-android-sdk.sh
EMU_ACCEL=off ./scripts/start-android-emulator.sh
./scripts/e2e-overlay-demo.sh
```

## License

MIT
