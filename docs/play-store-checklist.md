# Google Play 上架清单（旁窗）

## 已完成（仓库内，0.7.0）

- [x] 默认视觉模型：`Qwen/Qwen3-VL-8B-Instruct`
- [x] `targetSdk` / `compileSdk` **36**（2026-08-31 起新应用硬性要求）
- [x] 首次启动隐私同意 + 录屏前二次披露
- [x] 应用内隐私政策、使用条款、开源许可
- [x] 网页版隐私政策 / 条款：`docs/privacy.html` `docs/terms.html`
- [x] 默认禁止明文 HTTP（仅 localhost / 127.0.0.1 / 模拟器 10.0.2.2）
- [x] 关闭云备份（避免 API Key 进 Google Backup）
- [x] Adaptive 图标 + Play 512 图标 + 1024×500 特色图
- [x] Google Play Billing 一次性内购 `full_unlock`（约 $0.99）
- [x] Release 签名脚手架；上传密钥脚本 `android/scripts/generate-upload-keystore.sh`
- [x] Console 填表包：`docs/play/`

## 你必须亲自完成

见 **[YOU-MUST-DO.md](./play/YOU-MUST-DO.md)**。摘要：

- [ ] Google Play 开发者账号（$25）
- [ ] GitHub Pages（`/docs`）以便隐私政策 URL 可公开打开
- [ ] 下载并保管上传 keystore（不要提交 Git）
- [ ] Console 创建免费应用 + 内购 `full_unlock` @ $0.99
- [ ] 上传 AAB 到内部测试，License testers 验证购买
- [ ] 真机录制悬浮窗 / 录屏权限视频
- [ ] 确认 Live2D Mao 样例许可适合你的主体
- [ ] 提交审核

## 填表文件索引

| 用途 | 文件 |
|------|------|
| 你要办的事 | [play/YOU-MUST-DO.md](./play/YOU-MUST-DO.md) |
| 商店文案 | [play/listing.md](./play/listing.md) |
| Data safety | [play/data-safety.md](./play/data-safety.md) |
| 内容分级 | [play/content-rating.md](./play/content-rating.md) |
| 权限声明 | [play/permission-declarations.md](./play/permission-declarations.md) |
| 图标/宣传图 | [play/assets/](./play/assets/) |

## 版本

| 版本 | 说明 |
|------|------|
| 0.6.0 | $0.99 一次性内购解锁真屏陪伴 |
| 0.8.0 | 14 种常用语言；陪伴语跟系统语言 |
