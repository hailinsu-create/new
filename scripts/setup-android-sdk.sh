#!/usr/bin/env bash
# Install Android SDK pieces needed for 旁窗 + emulator (idempotent).
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export ANDROID_HOME ANDROID_SDK_ROOT="$ANDROID_HOME"
mkdir -p "$ANDROID_HOME/cmdline-tools"

if [[ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]]; then
  tmp=$(mktemp -d)
  curl -fsSL -o "$tmp/cmdtools.zip" \
    https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
  unzip -q -o "$tmp/cmdtools.zip" -d "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp"
fi

export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

# KVM access for this VM (nested virt may still need -accel off; chmod helps either way)
sudo groupadd -r kvm 2>/dev/null || true
sudo usermod -aG kvm "$(whoami)" 2>/dev/null || true
sudo chmod 666 /dev/kvm 2>/dev/null || true

yes | sdkmanager --licenses >/tmp/sdk-licenses.log 2>&1 || true
sdkmanager \
  "platform-tools" \
  "platforms;android-34" \
  "build-tools;34.0.0" \
  "emulator" \
  "system-images;android-34;google_apis;x86_64"

AVD_NAME="${AVD_NAME:-pangchuang_api34}"
if ! avdmanager list avd 2>/dev/null | grep -q "Name: ${AVD_NAME}"; then
  echo no | avdmanager create avd \
    -n "$AVD_NAME" \
    -k "system-images;android-34;google_apis;x86_64" \
    -d "pixel_6" \
    --force
fi

CFG="$HOME/.android/avd/${AVD_NAME}.avd/config.ini"
if [[ -f "$CFG" ]]; then
  grep -q '^hw.keyboard=' "$CFG" && sed -i 's/^hw.keyboard=.*/hw.keyboard=yes/' "$CFG" || echo 'hw.keyboard=yes' >> "$CFG"
  grep -q '^hw.ramSize=' "$CFG" && sed -i 's/^hw.ramSize=.*/hw.ramSize=3072/' "$CFG" || echo 'hw.ramSize=3072' >> "$CFG"
  grep -q '^hw.gpu.enabled=' "$CFG" && sed -i 's/^hw.gpu.enabled=.*/hw.gpu.enabled=yes/' "$CFG" || echo 'hw.gpu.enabled=yes' >> "$CFG"
  grep -q '^hw.gpu.mode=' "$CFG" && sed -i 's/^hw.gpu.mode=.*/hw.gpu.mode=swiftshader_indirect/' "$CFG" || echo 'hw.gpu.mode=swiftshader_indirect' >> "$CFG"
fi

echo "Android SDK ready at $ANDROID_HOME (AVD=$AVD_NAME)"
