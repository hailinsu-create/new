# 敏感权限声明（直接粘贴）

Play 审核员主要盯这三项：悬浮窗、MediaProjection 录屏、前台服务。用下面英文原文贴进 Console；视频按脚本用真机录。

## SYSTEM_ALERT_WINDOW（Display over other apps）

**Why?**
The core product is a floating Live2D companion that remains visible while the user is in other apps. The overlay shows the character and a short text bubble. It is not used for ads, phishing, or blocking other apps.

**Video script (20–40s)**
1. Open 旁窗.  
2. Grant overlay permission in system settings.  
3. Tap **演示召唤** (Summon demo).  
4. Switch to Chrome or Settings; show the character still floating.  
5. Tap the notification to return to 旁窗.  
6. Tap **让小旁先休息**.

## FOREGROUND_SERVICE / specialUse

**Why?**
A foreground service keeps the overlay alive after the settings activity goes to the background. Subtype: floating screen companion. A persistent notification is always shown. The service stops when the user taps stop.

## FOREGROUND_SERVICE_MEDIA_PROJECTION / screen capture

**Why?**
Full companion captures the current screen so a user-configured vision API can write a 1–2 line comment. Before the one-time unlock, the same path allows 6 successful real-screen glances with the user’s own API key. Captures are JPEG frames in memory, not saved to the gallery, and pause when the device is locked. Demo mode (演示召唤) does not capture the screen.

**Prominent disclosure**
The app shows an in-app consent dialog on first launch, and a second disclosure immediately before the system MediaProjection prompt.

**Video script (30–60s)**
1. Open 旁窗, accept privacy policy.  
2. Enter a vision API key (trial does not need Play unlock; Debug builds auto-unlock).  
3. Tap **完整陪伴**.  
4. Show the in-app disclosure, then the **system** screen-capture dialog, tap allow.  
5. Switch to another app; show a companion line that matches that screen.  
6. Lock the phone; mention capture pauses (optional: unlock and show it resumes).  
7. Stop the companion (**让小旁先休息**).

## PACKAGE_USAGE_STATS（可选）

**Why?**
Optional. If granted, the app reads the foreground package name and sends it as a text hint with the screenshot. Vision still uses the screenshot. The toggle is clearly optional in settings.

If Play asks for a video: open 旁窗 → tap the usage-access button → grant → return; no overlay spam.

## POST_NOTIFICATIONS

Optional. On Android 13+ the ongoing companion notification is easier to tap (stop from the shade). The in-app UI already marks this as optional; demo and full companion still run if the user skips it. No marketing notifications.

## Photos and videos policy

Do **not** claim gallery/photo access. We do not use `READ_MEDIA_IMAGES` / `READ_EXTERNAL_STORAGE`. Screen capture is MediaProjection only.

## 视频规格

- 横屏或竖屏均可，MP4，<(Play 上传上限)
- 不要加速到看不清系统权限框
- 用测试轨道安装的 **Release** 包录，避免 Debug 自动解锁造成审核员困惑（可在旁白说明 demo 免费）
