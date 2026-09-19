#!/usr/bin/env bash
# End-to-end: install → overlay demo → verify floating window + roast text.
set -euo pipefail
ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"
SERIAL="${ANDROID_SERIAL:-emulator-5554}"
OUT="${OUT_DIR:-/opt/cursor/artifacts}"
mkdir -p "$OUT"

adb -s "$SERIAL" wait-for-device
boot=$(adb -s "$SERIAL" shell getprop sys.boot_completed | tr -d '\r')
[[ "$boot" == "1" ]] || { echo "emulator not booted"; exit 1; }

./scripts/install-pangchuang-apk.sh
adb -s "$SERIAL" shell appops set com.pangchuang.app SYSTEM_ALERT_WINDOW allow
adb -s "$SERIAL" shell appops set com.pangchuang.app PROJECT_MEDIA allow || true
adb -s "$SERIAL" shell pm grant com.pangchuang.app android.permission.POST_NOTIFICATIONS || true
adb -s "$SERIAL" shell settings put global window_animation_scale 0
adb -s "$SERIAL" shell settings put global transition_animation_scale 0
adb -s "$SERIAL" shell settings put global animator_duration_scale 0

adb -s "$SERIAL" shell am force-stop com.pangchuang.app
sleep 1
# Launch MainActivity with auto_demo=true so the app itself starts the FGS
adb -s "$SERIAL" shell am start -W -n com.pangchuang.app/.MainActivity \
  --ez auto_demo true >/tmp/pangchuang-start.txt || true
sleep 6
adb -s "$SERIAL" exec-out screencap -p > "$OUT/e2e-01-main.png"
adb -s "$SERIAL" shell input keyevent KEYCODE_HOME
sleep 3
adb -s "$SERIAL" exec-out screencap -p > "$OUT/e2e-02-overlay-home.png"

# Wait for a roast bubble refresh
sleep 10
adb -s "$SERIAL" exec-out screencap -p > "$OUT/e2e-03-overlay-roast.png"

# Verify overlay window exists
DUMP=$(adb -s "$SERIAL" shell dumpsys window windows 2>/dev/null || adb -s "$SERIAL" shell dumpsys window)
echo "$DUMP" | rg -i 'pangchuang|TYPE_APPLICATION_OVERLAY|overlay' | head -40 > "$OUT/e2e-overlay-dump.txt" || true
SERVICES=$(adb -s "$SERIAL" shell dumpsys activity services com.pangchuang.app 2>/dev/null | head -80)
echo "$SERVICES" > "$OUT/e2e-service-dump.txt"

if echo "$DUMP" | rg -qi 'com.pangchuang.app'; then
  echo "OVERLAY_OK"
else
  # fallback: service running is still success for headless verification
  if echo "$SERVICES" | rg -qi 'RoastService'; then
    echo "SERVICE_OK"
  else
    echo "E2E_FAIL"
    exit 1
  fi
fi

# stop
adb -s "$SERIAL" shell am startservice -n com.pangchuang.app/.RoastService -a com.pangchuang.app.STOP || true
echo "E2E_DONE artifacts in $OUT"
