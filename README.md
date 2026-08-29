# 旁窗（Android）

安卓小窗 / 悬浮窗持续看屏，用开源视觉模型旁观吐槽。

## 核心流程

1. 打开 App，配置视觉模型（或开「演示段子」）
2. 授予 **悬浮窗** + **屏幕录制** 权限
3. 点「缩成小窗并开始吐槽」→ App 退到后台，右上角留下可拖拽的「旁」球
4. 前台服务定时截帧（截前会短暂隐藏悬浮球，避免自己入镜）→ 画面变化时调用视觉模型 → 气泡吐槽

```
你刷其它 App
    ↓
MediaProjection 截帧
    ↓
画面变化？ → Vision API（Qwen-VL / Ollama 等）
    ↓
SYSTEM_ALERT_WINDOW 小窗气泡
```

## 构建安装

```bash
export ANDROID_HOME=~/android-sdk   # 按本机路径改
cd android
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

最低 Android 8.0（API 26），target 34。

## 设置项

| 项 | 说明 |
|----|------|
| Base URL | OpenAI 兼容接口，如 SiliconFlow / 本地 Ollama |
| API Key | 不填则自动走演示段子 |
| Vision Model | 例如 `Qwen/Qwen2.5-VL-7B-Instruct` |
| 吐槽间隔 | 默认 15 秒；画面几乎没变会跳过 |
| 演示段子 | 不调 API，先验证小窗流程 |

## 权限说明

- **悬浮窗**：把吐槽球贴在其它 App 上层（安卓小窗机制）
- **MediaProjection**：官方屏幕录制授权，只把缩小后的 JPEG 发给你填的模型地址
- **前台服务通知**：系统要求，可从通知栏停止

## 桌面版（可选）

仓库里还有早期的桌面 Python 旁窗（`python -m pangchuang`），用 ADB 看手机。主路径已改为本 Android App。

## License

MIT
