# Pangchuang privacy policy (in-app)

Last updated: 2026-09-15 (0.14.1)

Pangchuang is an open-source Android floating companion. We do not run an account server.

## Data

- Screen JPEGs are sent only to the vision API you configure, to write companion lines.
- Optional usage access reads the foreground app name as a hint.
- API keys stay on device. Cloud backup is off.
- Screenshots are not saved to the gallery. Locking the phone releases capture and stops API calls so lock or PIN frames are not sent.
- If usage access is on, keyboards, password managers, authenticators, and banking apps skip that tick (best-effort).

## Permissions

Overlay is required to show the character. Screen capture is needed for full companion and the 20-glance trial. Notifications are optional (they make stop-from-shade easier). Usage access is optional. Demo overlay does not capture the real screen. The JPEG sent to vision masks the overlay character so 小旁 is not in the model image.

## Third parties

You choose the vision API. Purchases go through Google Play.

## Demo mode

Demo lines do not send screenshots to a vision API.

## In-app purchase

Demo overlay stays free. Before unlock, your own key gets 20 successful real-screen glances. Full companion is a one-time Google Play unlock (about $0.99). The trial counter and unlock flag are on-device and forgeable the same way.

## Contact

https://github.com/hailinsu-create/new
