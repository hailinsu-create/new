# 旁窗（Android）

开源悬浮窗伴侣：原创国风 Live2D 角色「小旁」（墨汐）停在屏幕一角，认出你在用什么 App、在干什么，再用扫地僧那种点到为止的口吻说两句。

**产品是 Android 应用**（包名 `com.pangchuang.app`）。最低 Android 8.0（API 26），target 36。

**默认视觉模型：`Qwen/Qwen3-VL-8B-Instruct`（稳定推荐）**

**当前版本：0.13.1**（debug APK：`dist/pangchuang-0.13.1-debug.apk`）。`dist/pangchuang-0.13.0-debug.apk` 与 `dist/pangchuang-0.12.0-debug.apk` 仍保留。

**定价：演示免费；完整真屏陪伴通过 Google Play 一次性解锁（约 $0.99）。Debug 包侧载测试时自动解锁。**

## 真机怎么用

1. 开 **悬浮窗** 权限
2. 阅读并 **同意隐私政策**（首次启动）
3. 点 **「演示召唤」** 免费体验角色与气泡（不看真屏、不调视觉 API）
4. 要完整陪伴：在「完整陪伴设置」里填视觉 API（SiliconFlow 等 HTTPS 接口），点 **「完整陪伴」** → 确认录屏说明 → 允许系统「屏幕录制」
5. 去刷其它 App；小旁截当前画面 → 说两句相关的

锁屏会**真正停止截屏**：释放 VirtualDisplay，丢掉已缓存的帧，不会把锁屏或 PIN 画面送去 API。解锁后，若陪伴仍在运行，才重新开始截屏。可选「使用情况访问」时，键盘、密码管理器、验证器和银行类应用会跳过这一拍（名单见 `SensitiveApps.kt`）。

本地 Ollama 请用 `http://127.0.0.1:11434/v1`。完整陪伴在 Play 上架版需一次性解锁。GitHub debug APK 为方便测试会自动解锁。

## Google Play 上架

- 你要亲自办的事：[docs/play/YOU-MUST-DO.md](docs/play/YOU-MUST-DO.md)
- 清单：[docs/play-store-checklist.md](docs/play-store-checklist.md)
- 填表包：[docs/play/](docs/play/)
- 隐私政策：[docs/privacy-policy.md](docs/privacy-policy.md) / [docs/privacy.html](docs/privacy.html) / [docs/privacy-en.html](docs/privacy-en.html)
- 问卷总表：[docs/play/console-app-content.md](docs/play/console-app-content.md)
- 封闭测试：[docs/play/closed-testing.md](docs/play/closed-testing.md)

隐私政策网页需要你在仓库 Settings 里启用 GitHub Pages（Actions 源）。**在你点开之前，`https://hailinsu-create.github.io/new/privacy.html` 仍是 404**，不要把它当已上线的最终 URL。

## 设置项

主界面默认是陪伴首页（演示召唤 / 完整陪伴 / 状态）。API、权限、语言、法律和内购在 **「完整陪伴设置」** 里。

| 项 | 说明 |
|----|------|
| Base URL | 默认 `https://api.siliconflow.cn/v1`；本地仅 127.0.0.1 |
| API Key | 真陪伴必填；仅存本机，不进云备份 |
| Vision Model | 默认 **Qwen3-VL-8B**；可点「恢复推荐 8B」 |
| 试连接 | 立刻对你填的 URL/Key/模型发一条短文本 ping |
| 陪伴间隔 | 默认 15 秒 |
| 画面变化阈值 | 画面几乎没变时少说话 |
| 界面语言 | 设置里可切换；也可跟随系统。14 种常用语言 |
| 解锁 | Play 一次性内购 `full_unlock`（约 $0.99） |
| 隐私与合规 | 应用内政策、条款与 Live2D 许可 |

演示召唤**不会**把「演示陪伴语」开关永久打开。完整陪伴在该开关仍开着时会拒绝启动，避免截真屏却只讲现成笑话。

## 本机 USB 安装

```bash
git pull
cd android
./gradlew :app:assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell appops set com.pangchuang.app SYSTEM_ALERT_WINDOW allow
adb shell am start -n com.pangchuang.app/.MainActivity
```

设置里可选界面语言，也可跟随系统：简体中文、繁体中文、英语、日语、韩语、西班牙语、巴西葡萄牙语、法语、德语、俄语、印尼语、越南语、泰语、阿拉伯语。

## 模拟器（可选）

云 VM 嵌套 KVM 常不可用，需 `EMU_ACCEL=off`：

```bash
./scripts/setup-android-sdk.sh
EMU_ACCEL=off ./scripts/start-android-emulator.sh
./scripts/e2e-overlay-demo.sh
```

## 桌面原型（不是产品）

仓库里还有一个早期 **PySide6** 桌面实验（`pangchuang/`）。那不是上架应用，也不再是主路径。产品是上面的 Android 包。

## License

MIT
