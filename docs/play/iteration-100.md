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
