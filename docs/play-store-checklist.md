# Google Play 上架清单（旁窗）

## 已完成（仓库内，0.10.0）

- [x] 默认视觉模型：`Qwen/Qwen3-VL-8B-Instruct`
- [x] `targetSdk` / `compileSdk` **36**（2026-08-31 起新应用硬性要求）
- [x] 首次启动隐私同意 + 录屏前二次披露
- [x] 应用内隐私政策、使用条款、开源许可
- [x] 网页版隐私政策 / 条款：`docs/privacy.html` `docs/terms.html`，英文 `privacy-en.html` `terms-en.html`
- [x] GitHub Actions 发布 `/docs` 到 Pages（你只需在仓库 Settings 里把 Pages 源改成 GitHub Actions）
- [x] 默认禁止明文 HTTP（仅 localhost / 127.0.0.1 / 模拟器 10.0.2.2）
- [x] 关闭云备份（避免 API Key 进 Google Backup）
- [x] Adaptive 图标 + Play 512 图标 + 1024×500 特色图
- [x] 商店截图草稿含设置、隐私同意、Live2D 悬浮窗
- [x] Google Play Billing 一次性内购 `full_unlock`（约 $0.99）
- [x] Release 签名脚手架；上传密钥脚本 `android/scripts/generate-upload-keystore.sh`
- [x] 14 种界面语言；设置页可切换；Play AAB 关闭语言分包以免选语言缺资源
- [x] 清单里去掉广告 ID / 相册权限（即使以后有库想合并进来）
- [x] 完整陪伴的前台服务同时带 `mediaProjection` 与 `specialUse`（悬浮窗还在）
- [x] 无 `.so`，16 KB 页大小规则对纯 Kotlin 包不适用
- [x] Console 填表包：`docs/play/`（含封闭测试 12 人 / 14 天）

## 你必须亲自完成

见 **[YOU-MUST-DO.md](./play/YOU-MUST-DO.md)**。摘要：

- [ ] Google Play 开发者账号（$25）
- [ ] GitHub Pages 源选 GitHub Actions，确认隐私政策 URL 能打开
- [ ] 下载并保管上传 keystore（不要提交 Git）
- [ ] Console 创建免费应用 + 内购 `full_unlock` @ $0.99
- [ ] 上传 AAB 到内部测试，License testers 验证购买
- [ ] 真机录制悬浮窗 / 录屏权限视频，并用真机换商店截图
- [ ] 封闭测试：至少 12 人连续 opt-in 14 天（个人账号）
- [ ] 确认 Live2D Mao 样例许可适合你的主体
- [ ] 申请生产权限并提交审核

## 填表文件索引

| 用途 | 文件 |
|------|------|
| 你要办的事 | [play/YOU-MUST-DO.md](./play/YOU-MUST-DO.md) |
| 按页面点下去 | [play/console-app-content.md](./play/console-app-content.md) |
| 封闭测试 | [play/closed-testing.md](./play/closed-testing.md) |
| 测试员邀请 | [play/tester-invite.md](./play/tester-invite.md) |
| 生产权限问卷 | [play/production-access.md](./play/production-access.md) |
| 商店文案（中/英） | [play/listing.md](./play/listing.md) |
| 其它语言商店文案 | [play/listing-i18n.md](./play/listing-i18n.md) |
| 本版最新动态 | [play/release-notes.md](./play/release-notes.md) |
| Data safety | [play/data-safety.md](./play/data-safety.md) |
| 内容分级 | [play/content-rating.md](./play/content-rating.md) |
| 权限声明 | [play/permission-declarations.md](./play/permission-declarations.md) |
| 图标/宣传图 | [play/assets/](./play/assets/) |

## 版本

| 版本 | 说明 |
|------|------|
| 0.6.0 | $0.99 一次性内购解锁真屏陪伴 |
| 0.7.0 | targetSdk 36、录屏二次披露、Play 图形草稿 |
| 0.8.0 | 14 种常用语言；陪伴语跟系统语言 |
| 0.9.0 | 设置页语言开关；英文政策页；Console 问卷总表与多语言商店文案 |
| 0.10.0 | 封闭测试说明；Pages 工作流；Live2D 商店悬浮窗图；完整陪伴 FGS 同时声明 overlay+录屏 |
