# 旁窗（Android）

开源桌面伴侣：悬浮窗里的二次元角色「小旁」会看看你正在用的屏幕，用可爱的口吻陪你说一句。灵感接近 Animates 一类陪伴窗，但整条链路开源、可自建视觉模型。

## 真机怎么用（主路径）

1. 开 **悬浮窗** 权限  
2. **关掉「演示陪伴语」**，填视觉模型（SiliconFlow / Ollama 等 OpenAI 兼容接口）  
3. 点 **「召唤小旁陪看屏幕」** → 允许系统「屏幕录制」  
4. 去刷微信 / 浏览器 / 短视频；小旁截当前画面 → 说一句陪伴  
5. **长按头像**立刻再说一句；短按显隐气泡  

「仅演示悬浮窗」只验证小窗形态，**不看真屏**。

```
你刷其它 App
    ↓
MediaProjection 截帧（截前隐藏头像）
    ↓
画面变化？ → Vision API（Qwen-VL 等）
    ↓
SYSTEM_ALERT_WINDOW 气泡 + 动态头像
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
| API Key | 真陪伴必填；空则只能演示陪伴语 |
| Vision Model | 如 `Qwen/Qwen3-VL-8B-Instruct` |
| 陪伴间隔 | 默认 12 秒；画面几乎没变会跳过 |
| 演示陪伴语 | 不调 API |

## 模拟器（可选）

云 VM 嵌套 KVM 常不可用，需 `EMU_ACCEL=off`：

```bash
./scripts/setup-android-sdk.sh
EMU_ACCEL=off ./scripts/start-android-emulator.sh
./scripts/e2e-overlay-demo.sh
```

## License

MIT
