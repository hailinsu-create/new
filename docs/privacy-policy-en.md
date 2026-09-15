# Pangchuang privacy policy

Last updated: 2026-09-15 (0.14.0)

Pangchuang (`com.pangchuang.app`) is an open-source Android floating companion. Web copy: https://hailinsu-create.github.io/new/privacy-en.html (after GitHub Pages is on).

Chinese: https://hailinsu-create.github.io/new/privacy.html

## What we collect

The app does not run an account server. Data is processed on device, or sent to a third-party API you choose.

| Data | Use | Destination |
|------|-----|-------------|
| Screen JPEG | Recognize the current screen and write a companion line | The vision API you configure |
| Foreground app name (optional) | Hint which app is in front | Same API, as a text hint |
| API key, base URL, model name | Call the vision API | On device. Cloud backup is off. |
| Unlock state | Whether full companion is purchased | On device. Payment is handled by Google Play. |

Screenshots are not saved to the gallery and are not uploaded to a server we control. Locking the phone releases the capture surface and stops API calls, so lock or PIN frames are not sent. If usage access is on, keyboards, password managers, authenticators, and banking apps skip that tick (best-effort; see `SensitiveApps.kt`).

The GitHub Pages URL is 404 until Pages is enabled in repo Settings.

## Third parties

- You choose an OpenAI-compatible vision API (for example SiliconFlow).
- Google Play Billing for the one-time product `full_unlock`. We do not collect card numbers.

## Permissions

- Overlay: character and bubble.
- Screen capture (MediaProjection): full companion and the 6-glance trial. Demo overlay does not capture. A second in-app disclosure runs before the system dialog. The JPEG sent to vision masks the overlay character.
- Usage access (optional): foreground package name.
- Notifications (optional): foreground service status, so you can stop from the shade. The app still runs if you skip them.

## In-app purchase

Demo overlay is free. Before unlock, your own key gets 6 successful real-screen glances. Full companion is a Google Play one-time unlock (about $0.99). Refunds follow Google Play policy. Restore after a device change. The trial counter and unlock flag are on-device and forgeable the same way.

## Children

Not directed at children under 13. Play target age should be 18+ because full companion may capture whatever is on screen.

## Your choices

- Stop the companion at any time.
- Delete the API key and uninstall to clear local settings.
- Use demo mode only.
- Pick a UI language in settings, or follow the system.

## Live2D

The character is original Chinese-style Live2D Moxi (墨汐), not a Live2D sample. Cubism Core still follows Live2D SDK terms. See in-app open-source licenses.

## Contact

https://github.com/hailinsu-create/new
