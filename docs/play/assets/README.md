# 商店图形

| 文件 | Play 字段 | 规格 |
|------|-----------|------|
| `play_icon_512.png` | 高清图标 | 512×512 PNG |
| `feature_graphic_1024x500.png` | 特色图形 | 1024×500 PNG |
| `screenshot_settings.png` | 手机截图 1 | 1080×1920，设置页（含语言与解锁） |
| `screenshot_consent.png` | 手机截图 2 | 1080×1920，首次隐私同意 |
| `screenshot_overlay.png` | 手机截图 3 | 1080×1920，小旁浮在其它画面上（墨汐拼图） |
| `screenshot_overlay_closeup.png` | 手机截图 4 | 1080×1920，角色与气泡特写 |
| `moxi_face.png` | 生成用素材 | 原创国风角色墨汐脸部截取，不上架 |

`screenshot_settings.png` / `screenshot_consent.png` 按文案重建（陪伴首页，不是调试表单）。悬浮窗两张用 `moxi_face.png`（0.13.1 起为 Live2D 圆窗同款 bust crop）按约 **96dp** 头像框拼出来，并带关闭角标，给 Console 先垫上「有 Live2D」的图。**这些不是真机照片。提交前请用真机演示模式换掉**（云端模拟器 System UI 会 ANR，截不到真悬浮窗）。真机至少拍：

1. 陪伴首页（演示召唤 / 完整陪伴）
2. 演示模式：小旁浮在另一个 App 上（含关闭角标）
3. 完整陪伴：锁屏后截屏已停
