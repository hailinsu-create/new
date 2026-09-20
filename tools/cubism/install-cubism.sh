#!/usr/bin/env bash
# Download + silent-install Cubism Editor 5.3 into a Wine prefix.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
VERSION="${CUBISM_VERSION:-5.3.03}"
INSTALLER="$ROOT/Live2D_Cubism_Setup_${VERSION}.exe"
URL="https://cubism.live2d.com/editor/bin/Live2D_Cubism_Setup_${VERSION}.exe"

export WINEPREFIX="${WINEPREFIX:-$ROOT/wineprefix}"
export WINEARCH=win64
export DISPLAY="${DISPLAY:-:1}"

if ! command -v wine >/dev/null; then
  echo "wine is required. On Ubuntu: sudo apt install wine wine64 wine32:i386 winetricks" >&2
  exit 1
fi

mkdir -p "$ROOT" "$WINEPREFIX"
wineboot -u >/dev/null 2>&1 || true

if [[ ! -f "$INSTALLER" ]]; then
  echo "Downloading $URL"
  curl -L --fail -o "$INSTALLER" "$URL"
fi

echo "Installing into $WINEPREFIX (C:\\Live2D_Cubism)"
wine "$INSTALLER" /S /D=C:\\Live2D_Cubism
echo "Done. Launch with: $ROOT/launch-editor.sh"
