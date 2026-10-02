#!/usr/bin/env bash
# Install debug 旁窗 APK onto the running emulator/device.
set -euo pipefail
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
SERIAL="${ANDROID_SERIAL:-emulator-5554}"
APK="${1:-/workspace/android/app/build/outputs/apk/debug/app-debug.apk}"
if [[ ! -f "$APK" ]]; then
  (cd /workspace/android && ./gradlew :app:assembleDebug)
fi
adb -s "$SERIAL" wait-for-device
adb -s "$SERIAL" shell settings put global verifier_verify_adb_installs 0 || true
adb -s "$SERIAL" shell settings put global package_verifier_enable 0 || true
adb -s "$SERIAL" install -r -t "$APK"
adb -s "$SERIAL" shell appops set com.pangchuang.app SYSTEM_ALERT_WINDOW allow || true
adb -s "$SERIAL" shell pm grant com.pangchuang.app android.permission.POST_NOTIFICATIONS || true
echo "installed $APK on $SERIAL"
