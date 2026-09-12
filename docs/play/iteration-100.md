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
