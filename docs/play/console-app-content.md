# Play Console 填表（按页面点下去）

默认语言：**中文（简体）**。应用类型：**应用**。定价：**免费**（内购另计）。

隐私政策 URL（启用 Pages 后优先用这个）：

`https://hailinsu-create.github.io/new/privacy.html`

英文页：`https://hailinsu-create.github.io/new/privacy-en.html`

Pages 未开时，公开仓库可用：

`https://github.com/hailinsu-create/new/blob/cursor/phone-roast-small-window-b0b5/docs/privacy.html`

联系邮箱、联系网址填你自己的。网站可填 GitHub 仓库。

---

## Store listing 商店上架

见 `listing.md`（中/英）和 `listing-i18n.md`（其它语言短说明与完整说明）。

- 类别：**工具 (Tools)**
- 标签：个性化、效率
- 高清图标：`assets/play_icon_512.png`
- 特色图形：`assets/feature_graphic_1024x500.png`
- 手机截图：至少 2 张，建议 4 张。草稿在 `assets/screenshot_*.png`（含 Live2D 悬浮窗拼图），**请用真机换掉**。
- 平板截图：可选。未锁方向，平板能开；没有真机可先空着。
- 最新动态：`release-notes.md`

## 商店设置

- 本应用包含广告？**否**
- 新闻类应用？**否**
- 针对儿童？**否**
- 应用访问权限（登录墙）？**否**，没有账号系统

## App content → 广告

Does your app contain ads? **No**

## App content → 内容分级

问卷答案见 `content-rating.md`。类别选 Utility / Application，不要选游戏。

## App content → 目标受众和内容

- 目标年龄：**18 岁及以上**
- 不要勾选「专为儿童设计」
- 应用可能对儿童不适宜：可选「是」（会截取任意屏幕内容，并由模型生成文本）
- 商店列出年龄：随 IARC 问卷结果

## App content → 新闻应用

**不是**新闻应用。

## App content → COVID-19

**否**，与疫情无关。

## App content → 政府应用

**否**。

## App content → 金融功能

- 本应用是否提供金融功能？选 **「数字商品的应用内购买 / Google Play 结算」** 这一类即可。
- 不是银行、钱包、贷款、加密货币交易。
- 商品：一次性 `full_unlock`，约 $0.99。

## App content → 健康

**否**。不是健康、健身或医疗应用。不接 Health Connect。

## App content → Data safety

逐项勾选见 `data-safety.md`。

## App content → 广告 ID

本应用是否使用广告 ID？**否**。没有广告 SDK。

## App content → 照片和视频权限

本应用是否使用照片/视频**权限**（`READ_MEDIA_*` / `READ_EXTERNAL_STORAGE`）？**否**。

完整陪伴用的是系统 **MediaProjection（屏幕录制）**，不是读取相册。不要把录屏填成「访问照片和视频」。

## App content → 前台服务

会弹出前台服务用途表。对照填写：

| 类型 | 选？ | 说明（可粘贴英文） |
|------|------|---------------------|
| `mediaProjection` | 是 | Captures the current screen so a user-configured vision API can write a 1–2 line companion comment. Pauses on lock screen. Not used in demo mode. |
| `specialUse` | 是 | Keeps the floating Live2D overlay alive while the user is in other apps. Persistent notification is always shown. |
| 其它 FGS 类型 | 否 | |

视频脚本见 `permission-declarations.md`。

## App content → 敏感权限 / 特殊权限

| 权限 | 填 |
|------|----|
| 显示在其他应用上层 | 核心功能：悬浮角色和气泡。不用于广告或劫持点击。 |
| 使用情况访问 | 可选。只读前景应用名，作为视觉提示。 |
| 屏幕录制 | 完整陪伴截取当前帧。应用内两次披露后再走系统对话框。 |

## 美国出口法规（上传 AAB 时）

- 应用是否使用加密？**是**，仅标准 HTTPS。
- 是否符合 EAR 豁免（公开可用的 SSL/TLS）？**是**。
- 不要勾选自研军用加密。

## 内购商品文案

| 语言 | 名称 | 说明 |
|------|------|------|
| 中文 | 完整陪伴解锁 | 永久解锁真屏陪伴。演示模式始终免费。视觉 API 费用需自行承担。 |
| English | Full companion unlock | Permanently unlocks real-screen companion. Demo stays free. You pay your own vision API. |
| 日本語 | フル機能の解除 | 本物の画面を永久解除。デモは無料。ビジョン API 料金は別。 |
| 한국어 | 전체 동반 잠금 해제 | 실제 화면 기능을 영구 해제. 데모는 무료. 비전 API 요금은 별도. |

其它语言可先用英文商品名。Product ID 必须是 `full_unlock`。

## 测试

1. 内部测试轨道上传 AAB（产物 `pangchuang-0.10.0.aab`）
2. Settings → License testing 加入你的 Gmail
3. 用测试链接安装 **Release** 包，不要用 GitHub debug APK 测购买
4. 测：演示免费 → 购买 → 恢复购买 → 锁屏暂停

## 封闭测试

新个人开发者账号（2023-11-13 之后）必须封闭测试：**至少 12 人 opt-in，连续 14 天**。内部测试不算。详见 `closed-testing.md`。
