#!/usr/bin/env bash
# assemble_v0.3.3.sh — Normandy v0.3.3 ¥0 包装（docs stub）
# 完整滤镜链曾在拼装机跑通；本仓库只保留参数契约，勿在此编造大二进制。
# 成片 RESULT: reviews 旁 RESULT-v0.3.3-ASSEMBLE-2026-10-28.md
# 切刀: reviews/CONTENT-CUTLIST-v0.3.3-2026-10-28.md
# 边界: 不开机默认；禁 NSFW；大 mp4/wav 不入库。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/outputs/v0.3.3-b0-01-2026-10-28"
FINAL="$OUT_DIR/out/B0-01-normandy-v0.3.3.mp4"

cat <<EOF
assemble_v0.3.3.sh (stub)
=========================
Target : $FINAL
Spec   : 14.958s · 1080x1920 · h264+AAC
DROP   : wade first frame @ 3.583s
Build  : door-drop demoted (pre-black)
Black  : 0.375s before DROP (~3.208-3.583)
Crop   : S05/S08 knee-up
Flag   : S10 -ss 2.00 shaped in
BGM    : Determined Pursuit (Emma_MA, CC0)

If FINAL already exists on the assemble host, do not re-encode blindly.
To rebuild: extend this stub from CONTENT-CUTLIST-v0.3.3 (same sources as
assemble_v0.3.2.sh: h3-phase4 clips + looklock-v0.3.1 stills + CC0 BGM bed).
EOF

if [[ -f "$FINAL" ]]; then
  echo "FOUND_LOCAL_FINAL $FINAL"
  echo ASSEMBLE_V033_STUB_OK
  exit 0
fi

echo "MISSING_FINAL (expected; binaries not in git): $FINAL"
echo "See RESULT-v0.3.3-ASSEMBLE-2026-10-28.md for PASS metrics."
echo ASSEMBLE_V033_STUB_DOCS_ONLY
exit 0
