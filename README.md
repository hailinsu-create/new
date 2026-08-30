# 旁窗（Android）

悬浮窗盯着你正在用的手机屏幕，用视觉模型按画面内容吐槽。

## 真机怎么用（主路径）

1. 开 **悬浮窗** 权限  
2. **关掉「演示段子」**，填视觉模型（SiliconFlow / Ollama 等 OpenAI 兼容接口）  
3. 点 **「开始看屏吐槽」** → 允许系统「屏幕录制」  
4. 去刷微信 / 浏览器 / 短视频；旁窗截当前画面 → 模型吐槽  
5. **长按「旁」球**立刻再吐一句；短按显隐气泡  

「仅演示悬浮窗」只验证小窗形态，**不看真屏**。

```
你刷其它 App
    ↓
MediaProjection 截帧（截前隐藏悬浮球）
    ↓
画面变化？ → Vision API（Qwen-VL 等）
    ↓
SYSTEM_ALERT_WINDOW 气泡
```

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
| API Key | 真吐槽必填；空则只能演示段子 |
| Vision Model | 如 `Qwen/Qwen2.5-VL-7B-Instruct` |
| 吐槽间隔 | 默认 12 秒；画面几乎没变会跳过 |
| 演示段子 | 不调 API（假吐槽） |

## 模拟器（可选）

云 VM 嵌套 KVM 常不可用，需 `EMU_ACCEL=off`：

```bash
./scripts/setup-android-sdk.sh
EMU_ACCEL=off ./scripts/start-android-emulator.sh
./scripts/e2e-overlay-demo.sh
```

## License

MIT
