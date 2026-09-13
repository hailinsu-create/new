#!/usr/bin/env bash
# Boot the 旁窗 AVD. Prefers KVM; falls back to TCG if nested virt hangs.
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:$PATH"
AVD_NAME="${AVD_NAME:-pangchuang_api34}"
TMUXC="${TMUXC:-/exec-daemon/tmux.portal.conf}"
SESSION="${SESSION:-android-emulator}"

sudo chmod 666 /dev/kvm 2>/dev/null || true

accel=on
if ! "$ANDROID_HOME/emulator/emulator-check" accel 2>/dev/null | grep -q 'is installed and usable'; then
  accel=off
fi
# Nested KVM often reports usable but guest stalls; allow override.
accel="${EMU_ACCEL:-$accel}"

rm -f "$HOME/.android/avd/${AVD_NAME}.avd/"*.lock

if tmux -f "$TMUXC" has-session -t "=$SESSION" 2>/dev/null; then
  echo "tmux session $SESSION already running"
else
  window_args=(-no-window)
  if [[ "${EMU_WINDOW:-0}" == "1" ]]; then
    export DISPLAY="${DISPLAY:-:1}"
    window_args=()
  fi
  tmux -f "$TMUXC" new-session -d -s "$SESSION" -c "$HOME" -- bash -lc \
    "export ANDROID_HOME=$ANDROID_HOME ANDROID_SDK_ROOT=$ANDROID_HOME PATH=$ANDROID_HOME/emulator:$ANDROID_HOME/platform-tools:\$PATH DISPLAY=\${DISPLAY:-:1}; \
     exec emulator -avd $AVD_NAME -accel $accel -gpu swiftshader_indirect \
     ${window_args[*]} -no-audio -no-boot-anim -no-snapshot -memory \${EMU_MEMORY:-3072} -cores \${EMU_CORES:-4} -port 5554"
  echo "started emulator session=$SESSION accel=$accel"
fi

echo "Waiting for adb device (TCG cold boot can take ~10–20 min)..."
adb start-server >/dev/null
for i in $(seq 1 180); do
  boot=$(adb -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)
  if [[ "$boot" == "1" ]]; then
    echo "emulator booted"
    adb devices -l
    exit 0
  fi
  sleep 5
done
echo "timed out waiting for boot (accel=$accel). Try EMU_ACCEL=off $0" >&2
exit 1
