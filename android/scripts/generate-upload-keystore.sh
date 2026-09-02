#!/usr/bin/env bash
# Generate a Play upload keystore in android/keystore/ (gitignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/keystore"
mkdir -p "$DIR"
STORE="$DIR/pangchuang-upload.jks"
PASS_FILE="$DIR/pangchuang-upload-keystore.txt"

if [[ -f "$STORE" ]]; then
  echo "keystore already exists: $STORE"
  exit 0
fi

PASS="$(python3 - <<'PY'
import secrets, string
alphabet = string.ascii_letters + string.digits
print("".join(secrets.choice(alphabet) for _ in range(24)))
PY
)"

keytool -genkeypair -v \
  -keystore "$STORE" \
  -alias pangchuang \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$PASS" \
  -keypass "$PASS" \
  -dname "CN=Pangchuang, OU=Pangchuang, O=Pangchuang, L=Unknown, ST=Unknown, C=US"

cat > "$PASS_FILE" <<EOF
RELEASE_STORE_FILE=$STORE
RELEASE_STORE_PASSWORD=$PASS
RELEASE_KEY_ALIAS=pangchuang
RELEASE_KEY_PASSWORD=$PASS
EOF

# Merge into local.properties without printing the password.
PROP="$ROOT/local.properties"
touch "$PROP"
python3 - <<PY
from pathlib import Path
prop = Path("$PROP")
text = prop.read_text() if prop.exists() else ""
lines = [ln for ln in text.splitlines() if not ln.startswith("RELEASE_")]
extra = Path("$PASS_FILE").read_text().strip().splitlines()
prop.write_text("\n".join(lines + extra) + "\n")
PY

echo "Wrote $STORE and updated local.properties. Keep $PASS_FILE offline; never commit it."
