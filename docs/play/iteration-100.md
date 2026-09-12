# 0.13.0 · 100-round companion deepening

Each row is a user-visible, safety, a11y, i18n, performance, test, or shipping-honesty change. Skipped 0.12.0 items were replaced.

R01 | consent | Do not request POST_NOTIFICATIONS before privacy consent; rationale dialog only after accept | MainActivity.kt
R02 | consent | Viewing legal/policy no longer drops consent; onResume re-shows the dialog until granted | MainActivity.kt
R03 | consent | Settings: revoke privacy consent, clear privacyConsentAt, stop companion | MainActivity.kt, Prefs.kt, activity_main.xml
R04 | home | Split lock-pause status into demo vs full (idle/demo/full/lock already existed in 0.12.0) | MainActivity.kt, strings.xml
R05 | home | Visible debug auto-unlock chip on the home screen, not only buried in advanced | activity_main.xml, bg_debug_chip.xml, MainActivity.kt
R06 | home | Version footer on home (`versionName` + `versionCode`) | activity_main.xml, MainActivity.kt
R07 | permissions | Usage-access copy marked optional, caption + text-button so it is not visually equal to overlay | activity_main.xml, strings.xml
R08 | capture | Second capture disclosure matches lock behavior: VirtualDisplay released, frames dropped, no forced glance on unlock | strings.xml
R09 | a11y | Home primary buttons use minHeight 56dp and vertical padding so large font does not clip | activity_main.xml
R10 | Live2D | Unload home preview WebView while overlay is running so Cubism is not loaded twice | Live2DAvatarView.kt, MainActivity.kt
R11 | overlay | Close control is 48dp with ripple/pressed contrast against the pink border | overlay_bubble.xml, bg_overlay_close.xml
R12 | a11y | Distinct contentDescriptions for avatar, bubble, and close | OverlayController.kt, overlay_bubble.xml, strings.xml
R13 | overlay | Persist overlay X/Y and restore clamped on next show | OverlayController.kt, Prefs.kt, OverlayGeometry.kt
R14 | rtl | Overlay uses locale layoutDirection; close chip on start (outer) side for ar | overlay_bubble.xml, OverlayGeometry.kt
R15 | overlay | SCREEN_OFF pauses Live2D WebView rendering; SCREEN_ON resumes if still running | RoastService.kt, OverlayController.kt, Live2DAvatarView.kt
R16 | overlay | Bubble sits above the avatar so it cannot cover the close chip | overlay_bubble.xml
R17 | notification | Distinct notification titles for demo vs full companion | RoastService.kt, strings.xml
R18 | notification | Stop action uses rest wording consistent with overlay close | RoastService.kt, strings.xml
R19 | overlay | Clamp and persist position on configuration change / rotation | OverlayController.kt, OverlayGeometry.kt
R20 | overlay | Permissionless long-press haptic via performHapticFeedback | OverlayController.kt
R21 | capture | Sensitive apps pause VirtualDisplay like lock, not only skip JPEG/API | RoastService.kt, CapturePolicy.kt, ScreenCaptor.kt
R22 | capture | Recreate mirroring when leaving a sensitive app if companion still running | RoastService.kt, CapturePolicy.kt
R23 | capture | Clear latestBitmap / lastFrame on lock, sensitive, and stop | ScreenCaptor.kt, RoastService.kt
R24 | capture | Do not force-roast after leaving a sensitive app (same as unlock) | RoastService.kt, CapturePolicy.kt
R25 | privacy | Expand SensitiveApps with more IME, password, bank, authenticator packages; tests kept | SensitiveApps.kt, SensitiveAppsTest.kt
R26 | battery | Low battery lengthens interval or skips a tick; missing battery info does not crash | BatteryPolicy.kt, RoastService.kt
R27 | capture | Drop capture to 540p on low-RAM devices or low battery | ScreenCaptor.kt, BatteryPolicy.kt, RoastService.kt
R28 | tests | CapturePolicy lock + sensitive + demo combinations, including mirroring pause/resume | CapturePolicyTest.kt
R29 | safety | Redact Bearer/API keys in remaining logs | VisionClient.kt, EndpointPolicy.kt
R30 | safety | Block non-HTTPS endpoints except loopback, with a visible overlay/home error | VisionClient.kt, EndpointPolicy.kt, strings.xml
R31 | Live2D | Auto-blink when ParamEyeLOpen / ParamEyeROpen exist | live2d/index.html
R32 | Live2D | Idle micro-motion on ParamAngleY / ParamBodyAngleX / ParamBreath | live2d/index.html
R33 | Live2D | CARE / SHY / THINK map to distinct params (not all smile/idle) | live2d/index.html, CompanionMoodMatcher.kt
R34 | Live2D | Humanize Live2D failures; only surface after retries, never WebGL stack traces | Live2DAvatarView.kt, OverlayController.kt
R35 | Live2D | verify-live2d.mjs still PASS; now asserts blink close and THINK ParamAngleY | scripts/verify-live2d.mjs
R36 | Live2D | Fallback PNGs stay distinct hashes; CARE uses talk PNG instead of happy alias | companion_avatar_*.png, CompanionMoodMatcher.kt
R37 | Live2D | Tighten WebView: no mixed content, no extra windows, JS only because Cubism needs it | Live2DAvatarView.kt
R38 | Live2D | Home preview uses the same overlay face crop as the floating window | character.json, Live2DAvatarView.kt
R39 | Live2D | Unload home engine so Cubism Core is not kept twice; liveEngineCount tracks hosts | Live2DAvatarView.kt, MainActivity.kt
R40 | copy | Sweep remaining Mao/sample user copy (none in strings); close-chip copy no longer says top-right | strings.xml
R41 | i18n | ar: leftover purchase_*, data_disclosure, overlay errors, new 0.13 keys | locales_013.py, values-ar/strings.xml
R42 | i18n | de: leftover purchase_* and 0.13 keys in natural German | locales_013.py, values-de/strings.xml
R43 | i18n | es: leftover purchase_* and 0.13 keys | locales_013.py, values-es/strings.xml
R44 | i18n | fr: leftover English purchase_summary/status and 0.13 keys | locales_013.py, values-fr/strings.xml
R45 | i18n | in: leftover purchase_* and 0.13 keys | locales_013.py, values-in/strings.xml
R46 | i18n | ja: app_name 傍窓, natural consent (no glued 旁窗), leftover keys | locales_013.py, values-ja/strings.xml
R47 | i18n | ko: app_name 곁창 (not 旁窗), natural consent, leftover keys | locales_013.py, values-ko/strings.xml
R48 | i18n | pt-rBR: leftover purchase_* and 0.13 keys | locales_013.py, values-pt-rBR/strings.xml
R49 | i18n | ru: leftover purchase_* and 0.13 keys | locales_013.py, values-ru/strings.xml
R50 | i18n | th+vi: th app_name ข้างหน้าต่าง and natural consent; vi leftover purchase_* | locales_013.py, values-th/strings.xml, values-vi/strings.xml
