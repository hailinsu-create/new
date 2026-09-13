# 0.13.0 · 100-round companion deepening

Landed **100** real rounds. `versionName` 0.13.0 / `versionCode` 22.
Debug APK: `dist/pangchuang-0.13.0-debug.apk`. Previous `dist/pangchuang-0.12.0-debug.apk` is unchanged.
Release AAB was built locally and **not** committed.

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
R51 | companion | Model presets: recommended 8B + custom field | activity_main.xml, MainActivity.kt
R52 | companion | Interval presets 10/15/30/60s + custom | activity_main.xml, MainActivity.kt, IntervalPolicy.kt
R53 | companion | Ping shows success/fail plus latency ms | VisionClient.kt, strings.xml
R54 | companion | Last vision/companion error stays on home until the next success | RoastService.kt, MainActivity.kt, Prefs.kt
R55 | companion | API key is a password field with visibility toggle | activity_main.xml
R56 | companion | Interval rejects 0 and out-of-range with a toast instead of silent clamp | MainActivity.kt, IntervalPolicy.kt, IntervalPolicyTest.kt
R57 | companion | changeThreshold has a one-line explanation under the field | activity_main.xml, strings.xml
R58 | companion | Restore-purchases hint sits above the restore button in advanced settings | activity_main.xml, strings.xml
R59 | companion | Empty API key shows a dialog explaining what is missing before Play overlay | MainActivity.kt
R60 | companion | SiliconFlow / OpenAI-compatible one-liner under base URL | activity_main.xml, strings.xml
R61 | tests | OverlayGeometry: rotation, 96dp avatar, off-screen clamp, tablet/tiny phone, snap geometry | OverlayGeometryTest.kt
R62 | tests | MarkdownHtml: headings, links, empty, zh bold | MarkdownHtmlTest.kt
R63 | tests | SensitiveApps: WeChat not skipped; IME/bank/authenticator skipped | SensitiveAppsTest.kt
R64 | shipping | ProGuard no longer keeps the entire app package; keep JS bridge + billing | proguard-rules.pro
R65 | copy | User-visible roast wording already gone; overlay comment no longer says roasted | OverlayController.kt
R66 | docs | README Android-first with 0.13.0 APK link; 0.12.0 APK link kept | README.md
R67 | docs | listing, listing-i18n, release-notes, YOU-MUST-DO, checklist updated honestly (composites ≠ device; Pages still user) | docs/play/*.md, docs/play-store-checklist.md
R68 | assets | Play icon and feature graphic remain 墨汐; overlay screenshots regenerated for 48dp close | docs/play/assets/
R69 | assets | Screenshot generator draws 48dp close and 96dp avatar and does not claim a device | generate-play-screenshots.py
R70 | about | App version shown on legal pages | LegalActivity.kt, activity_legal.xml
R71 | a11y | Remaining ImageViews have contentDescription; home static vs live are distinct | activity_main.xml, strings.xml
R72 | a11y | Legal title is a heading; close/up navigation has legal_up_cd | activity_legal.xml, LegalActivity.kt
R73 | overlay | Close chip tooltip plus white-stroke ripple pressed state | overlay_bubble.xml, bg_overlay_close.xml
R74 | a11y | Overlay XML accessibilityPaneTitle plus window title | overlay_bubble.xml, OverlayController.kt
R75 | a11y | Avatar, bubble, live preview, and still preview no longer share one string | strings.xml, overlay_bubble.xml, activity_main.xml
R76 | a11y | Close chip stroke is white on near-black for contrast against the pink avatar ring | bg_overlay_close.xml
R77 | overlay | Long German (and other) bubble text is capped at 140dp and scrolls | OverlayController.kt, overlay_bubble.xml
R78 | rtl | Overlay forces RTL layoutDirection when the configuration is RTL (ar) | OverlayController.kt, overlay_bubble.xml
R79 | a11y | Settings expand/collapse button exposes expanded/collapsed state description | MainActivity.kt
R80 | a11y | Home Live2D preview importantForAccessibility; hidden from TalkBack while overlay owns the engine | MainActivity.kt, activity_main.xml
R81 | billing | Pending Play purchases set purchasePending and show on home until they finish | BillingManager.kt, MainActivity.kt
R82 | billing | Acknowledge purchases with up to 3 retries | BillingManager.kt
R83 | billing | Reconnect BillingClient after disconnect (capped) | BillingManager.kt
R84 | Live2D | Hardware acceleration with software layer fallback after repeated WebGL failure | Live2DAvatarView.kt
R85 | capture | Foreground hint skips launchers, System UI, and this app | ForegroundAppResolver.kt
R86 | capture | Rotation pauses and recreates the VirtualDisplay with fresh metrics | RoastService.kt, ScreenCaptor.kt
R87 | companion | Home status warns when the demo-lines switch is on | MainActivity.kt, strings.xml
R88 | demo | Demo interval follows the user setting, capped 5–30s (no silent 8s) | RoastService.kt
R89 | consent | Notification permission status and optional button after privacy consent | activity_main.xml, MainActivity.kt
R90 | Live2D | WebView console logs only in debug builds | Live2DAvatarView.kt
R91 | service | Reset in-flight roast flag on teardown so a stuck tick cannot block the next session | RoastService.kt
R92 | ux | Persist advanced settings expanded/collapsed across rotation | MainActivity.kt
R93 | content | Extra grounded demo lines in mock_generic and mock_notes | arrays.xml
R94 | capture | ScreenCaptor refreshes width/height on resumeMirroring | ScreenCaptor.kt
R95 | consent | Capture grant is ignored if privacy was revoked while the system sheet was open | MainActivity.kt
R96 | shipping | Network security config comments document emulator 10.0.2.2 vs blocked LAN | network_security_config.xml
R97 | Live2D | Mood matcher understands extra ja/ko/de/fr/es care/shy/think words | CompanionMoodMatcher.kt
R98 | ux | Stop button enabled only while companion is running | MainActivity.kt
R99 | legal | Legal WebView clears history and still refuses JS/HTTP navigations | LegalActivity.kt
R100 | tests | ForegroundAppResolver ignores launchers; WeChat still not ignorable | ForegroundAppResolverTest.kt
