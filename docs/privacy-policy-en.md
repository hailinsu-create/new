# Pangchuang privacy policy

Last updated: 2026-09-01 (0.9.0)

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

Screenshots are not saved to the gallery and are not uploaded to a server we control. Capture and API calls stop when the phone is locked.

## Third parties

- You choose an OpenAI-compatible vision API (for example SiliconFlow).
- Google Play Billing for the one-time product `full_unlock`. We do not collect card numbers.

## Permissions

- Overlay: character and bubble.
- Screen capture (MediaProjection): full companion. Demo does not capture. A second in-app disclosure runs before the system dialog.
- Usage access (optional): foreground package name.
- Notifications: foreground service status.

## In-app purchase

Demo is free. Full companion is a Google Play one-time unlock (about $0.99). Refunds follow Google Play policy. Restore after a device change.

## Children

Not directed at children under 13. Play target age should be 18+ because full companion may capture whatever is on screen.

## Your choices

- Stop the companion at any time.
- Delete the API key and uninstall to clear local settings.
- Use demo mode only.
- Pick a UI language in settings, or follow the system.

## Live2D

The character is the official Mao sample. See in-app open-source licenses.

## Contact

https://github.com/hailinsu-create/new
