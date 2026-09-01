# 旁窗（Android）

开源桌面伴侣：悬浮窗里的 Live2D 角色「小旁」（官方虹色 Mao 样例）会从屏幕认出你在用什么 App、在干什么，再用扫地僧那种点到为止的口吻说两句。

**默认视觉模型：`Qwen/Qwen3-VL-8B-Instruct`（稳定推荐）**

**定价：演示免费；完整真屏陪伴通过 Google Play 一次性解锁（约 $0.99）。Debug 包侧载测试时自动解锁。**

## 真机怎么用（主路径）

1. 开 **悬浮窗** 权限
2. 阅读并 **同意隐私政策**（首次启动）
3. （可选）开 **使用情况访问**
4. **关掉「演示陪伴语」**，填视觉 API（SiliconFlow 等 HTTPS 接口）
5. 点 **「召唤小旁陪看屏幕」** → 确认录屏说明 → 允许系统「屏幕录制」
6. 去刷其它 App；小旁截当前画面 → 说两句相关的

锁屏自动暂停截屏与 API。本地 Ollama 请用 `http://127.0.0.1:11434/v1`。

完整陪伴在 Play 上架版需一次性解锁。GitHub debug APK 为方便测试会自动解锁。

## Google Play 上架

- 你要亲自办的事：[docs/play/YOU-MUST-DO.md](docs/play/YOU-MUST-DO.md)
- 清单：[docs/play-store-checklist.md](docs/play-store-checklist.md)
- 填表包：[docs/play/](docs/play/)
- 隐私政策：[docs/privacy-policy.md](docs/privacy-policy.md) / [docs/privacy.html](docs/privacy.html)

## 设置项

| 项 | 说明 |
|----|------|
| Base URL | 默认 `https://api.siliconflow.cn/v1`；本地仅 127.0.0.1 |
| API Key | 真陪伴必填；仅存本机，不进云备份 |
| Vision Model | 默认 **Qwen3-VL-8B**；可点「恢复推荐 8B」 |
| 陪伴间隔 | 默认 15 秒 |
| 解锁 | Play 一次性内购 `full_unlock`（约 $0.99） |
| 隐私与合规 | 应用内政策、条款与 Live2D 许可 |

## 本机 USB 安装

```bash
git pull
cd android
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell appops set com.pangchuang.app SYSTEM_ALERT_WINDOW allow
adb shell am start -n com.pangchuang.app/.MainActivity
```

最低 Android 8.0（API 26），target 36。

## 模拟器（可选）

云 VM 嵌套 KVM 常不可用，需 `EMU_ACCEL=off`：

```bash
./scripts/setup-android-sdk.sh
EMU_ACCEL=off ./scripts/start-android-emulator.sh
./scripts/e2e-overlay-demo.sh
```

## License

MIT
