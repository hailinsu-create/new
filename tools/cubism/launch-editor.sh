#!/usr/bin/env bash
# Launch Live2D Cubism Editor 5.3 via Wine (unofficial on Linux).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
export WINEPREFIX="${WINEPREFIX:-$ROOT/wineprefix}"
export WINEARCH=win64
export DISPLAY="${DISPLAY:-:1}"

EDITOR_EXE="$WINEPREFIX/drive_c/Live2D_Cubism/CubismEditor5.exe"
if [[ ! -f "$EDITOR_EXE" ]]; then
  echo "Cubism Editor not found at $EDITOR_EXE" >&2
  echo "Run: $ROOT/install-cubism.sh" >&2
  exit 1
fi

cd "$WINEPREFIX/drive_c/Live2D_Cubism"
exec wine CubismEditor5.exe "$@"
