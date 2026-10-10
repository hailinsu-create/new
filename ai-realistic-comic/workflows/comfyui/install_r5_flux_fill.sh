#!/usr/bin/env bash
# Download R5 Flux Fill stack. Probe gated Fill FIRST — on login wall exit 41 with URL.
set -uo pipefail

COMFY="${COMFY:-/root/autodl-tmp/comfyui}"
HF_ENDPOINT="${HF_ENDPOINT:-https://huggingface.co}"
export HF_ENDPOINT
OUT_JSON="${OUT_JSON:-/root/autodl-tmp/fox-semantic-out-r5/MODEL_HOST.json}"
STUCK_SEC="${STUCK_SEC:-900}"
GATED_URL="https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev"

mkdir -p \
  "$COMFY/models/diffusion_models" \
  "$COMFY/models/unet" \
  "$COMFY/models/text_encoders" \
  "$COMFY/models/vae" \
  "$COMFY/models/clip" \
  "$(dirname "$OUT_JSON")"

if [[ -f /etc/network_turbo ]]; then
  # shellcheck disable=SC1091
  source /etc/network_turbo || true
fi

# Optional HF token from env or common files (never print token).
if [[ -z "${HF_TOKEN:-}" ]]; then
  for f in /root/.cache/huggingface/token /root/.huggingface/token \
           /cursor/stores/user/hf-token.env /workspace/cred-handoff/hf-token.env; do
    if [[ -f "$f" ]]; then
      # shellcheck disable=SC1090
      if grep -q '^HF_TOKEN=' "$f" 2>/dev/null; then
        # shellcheck disable=SC1090
        set -a; source "$f"; set +a
      else
        HF_TOKEN="$(tr -d ' \n\r' < "$f")"
        export HF_TOKEN
      fi
      break
    fi
  done
fi

AUTH_HDR=()
if [[ -n "${HF_TOKEN:-}" ]]; then
  AUTH_HDR=(-H "Authorization: Bearer ${HF_TOKEN}")
  echo "HF_TOKEN_PRESENT yes"
else
  echo "HF_TOKEN_PRESENT no"
fi

echo "DF_BEFORE"
df -h /root/autodl-tmp | tail -1 || true

# --- Probe gated Fill BEFORE any large ungated download ---
FILL_DEST="$COMFY/models/diffusion_models/flux1-fill-dev.safetensors"
FILL_URL="${HF_ENDPOINT}/black-forest-labs/FLUX.1-Fill-dev/resolve/main/flux1-fill-dev.safetensors"
# also try comfy split path name variants
FILL_URL_ALT="${HF_ENDPOINT}/black-forest-labs/FLUX.1-Fill-dev/resolve/main/flux1-fill-dev.safetensors"

probe_gated() {
  local url="$1"
  echo "PROBE_GATED $url"
  local code
  code=$(curl -sS -o /tmp/r5-fill-probe.hdr -w '%{http_code}' -L --max-redirs 0 \
    "${AUTH_HDR[@]}" -A "fox-r5" -I "$url" 2>/tmp/r5-fill-probe.err || true)
  # follow once to catch 302->login
  if [[ -z "$code" || "$code" == "000" ]]; then
    code=$(curl -sS -o /tmp/r5-fill-probe.body -w '%{http_code}' -L --max-redirs 3 \
      "${AUTH_HDR[@]}" -A "fox-r5" -r 0-1023 "$url" 2>/tmp/r5-fill-probe.err || true)
  fi
  echo "PROBE_HTTP $code"
  head -c 400 /tmp/r5-fill-probe.body 2>/dev/null | tr '\n' ' '; echo
  if [[ "$code" == "401" || "$code" == "403" ]]; then
    echo "HF_GATED_LOGIN_WALL"
    echo "GATED_URL $GATED_URL"
    echo "NEED_HF_TOKEN accept model + set HF_TOKEN"
    return 41
  fi
  if grep -qiE 'gated|access to model|agree|login|unauthorized|authentication' /tmp/r5-fill-probe.body 2>/dev/null; then
    echo "HF_GATED_LOGIN_WALL"
    echo "GATED_URL $GATED_URL"
    return 41
  fi
  if [[ "$code" == "302" || "$code" == "303" || "$code" == "307" ]]; then
    loc=$(grep -i '^location:' /tmp/r5-fill-probe.hdr 2>/dev/null | head -1 | awk '{print $2}' | tr -d '\r')
    echo "PROBE_REDIRECT $loc"
    if echo "$loc" | grep -qiE 'login|authorize|oauth|gate'; then
      echo "HF_GATED_LOGIN_WALL"
      echo "GATED_URL $GATED_URL"
      return 41
    fi
  fi
  # 200 with tiny body that is HTML login
  if [[ "$code" == "200" ]] && head -c 200 /tmp/r5-fill-probe.body 2>/dev/null | grep -qiE '<html|login|gated'; then
    echo "HF_GATED_LOGIN_WALL"
    echo "GATED_URL $GATED_URL"
    return 41
  fi
  return 0
}

if [[ -f "$FILL_DEST" ]]; then
  sz=$(stat -c%s "$FILL_DEST" 2>/dev/null || echo 0)
  if [[ "$sz" -ge 20000000000 ]]; then
    echo "SKIP flux1-fill-dev.safetensors size=$sz"
  else
    probe_gated "$FILL_URL" || exit $?
  fi
else
  probe_gated "$FILL_URL" || exit $?
fi

download_one() {
  local url="$1" dest="$2" min_bytes="$3"
  if [[ -f "$dest" ]]; then
    local sz
    sz=$(stat -c%s "$dest" 2>/dev/null || echo 0)
    if [[ "$sz" -ge "$min_bytes" ]]; then
      echo "SKIP $(basename "$dest") size=$sz"
      return 0
    fi
    echo "REDOWNLOAD $(basename "$dest") size=$sz < $min_bytes"
  fi
  echo "GET $url -> $dest"
  local tmp="${dest}.part"
  rm -f "$tmp"
  curl -L --fail --retry 5 --retry-delay 5 -A "fox-r5" \
    "${AUTH_HDR[@]}" -o "$tmp" "$url" &
  local pid=$!
  local last=0 last_t now sz
  last_t=$(date +%s)
  while kill -0 "$pid" 2>/dev/null; do
    sleep 20
    now=$(date +%s)
    sz=$(stat -c%s "$tmp" 2>/dev/null || echo 0)
    echo "PROG $(basename "$dest") bytes=$sz"
    # detect HTML error page mid-download (gated)
    if [[ "$sz" -gt 200 && "$sz" -lt 50000 ]]; then
      if head -c 200 "$tmp" | grep -qiE '<html|gated|unauthorized|login'; then
        echo "HF_GATED_LOGIN_WALL"
        echo "GATED_URL $GATED_URL"
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
        rm -f "$tmp"
        return 41
      fi
    fi
    if [[ "$sz" -gt "$last" ]]; then
      last=$sz
      last_t=$now
    elif [[ $((now - last_t)) -ge $STUCK_SEC ]]; then
      echo "STUCK_DOWNLOAD $(basename "$dest") no growth >${STUCK_SEC}s"
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      rm -f "$tmp"
      return 42
    fi
  done
  if ! wait "$pid"; then
    echo "CURL_FAIL $(basename "$dest")"
    # check body for gate
    if [[ -f "$tmp" ]] && head -c 400 "$tmp" | grep -qiE 'gated|unauthorized|login|agree to share'; then
      echo "HF_GATED_LOGIN_WALL"
      echo "GATED_URL $GATED_URL"
      rm -f "$tmp"
      return 41
    fi
    rm -f "$tmp"
    return 1
  fi
  mv -f "$tmp" "$dest"
  local final
  final=$(stat -c%s "$dest")
  if [[ "$final" -lt "$min_bytes" ]]; then
    echo "TOO_SMALL $(basename "$dest") $final < $min_bytes"
    if head -c 400 "$dest" | grep -qiE 'gated|unauthorized|login'; then
      echo "HF_GATED_LOGIN_WALL"
      echo "GATED_URL $GATED_URL"
      rm -f "$dest"
      return 41
    fi
    return 43
  fi
  echo "OK $(basename "$dest") $final"
  return 0
}

fail=0
# Fill first (gated)
download_one "$FILL_URL" "$FILL_DEST" 20000000000 || fail=$?
if [[ "$fail" -eq 41 ]]; then
  echo "R5_MODELS_FAIL gated"
  exit 41
fi
if [[ "$fail" -ne 0 ]]; then
  echo "R5_MODELS_FAIL fill_rc=$fail"
  exit "$fail"
fi

# Ungated companions (comfy org / BFL ae via mirror-friendly paths)
# Prefer huggingface.co; hf-mirror may also work for public files.
download_one \
  "${HF_ENDPOINT}/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors" \
  "$COMFY/models/text_encoders/t5xxl_fp16.safetensors" \
  9000000000 || fail=1
# FP8 T5 fallback if fp16 fails (smaller)
if [[ "$fail" -ne 0 ]]; then
  fail=0
  download_one \
    "${HF_ENDPOINT}/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
    "$COMFY/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors" \
    4000000000 || fail=1
fi
download_one \
  "${HF_ENDPOINT}/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
  "$COMFY/models/text_encoders/clip_l.safetensors" \
  200000000 || true
# also copy into clip/ if Comfy looks there
if [[ -f "$COMFY/models/text_encoders/clip_l.safetensors" && ! -f "$COMFY/models/clip/clip_l.safetensors" ]]; then
  cp -n "$COMFY/models/text_encoders/clip_l.safetensors" "$COMFY/models/clip/clip_l.safetensors" 2>/dev/null || true
fi
download_one \
  "${HF_ENDPOINT}/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
  "$COMFY/models/vae/ae.safetensors" \
  300000000 || fail=1

echo "DF_AFTER"
df -h /root/autodl-tmp | tail -1 || true

python3 - <<'PY'
import json, os
from pathlib import Path
comfy = Path(os.environ.get("COMFY", "/root/autodl-tmp/comfyui"))
out = Path(os.environ.get("OUT_JSON", "/root/autodl-tmp/fox-semantic-out-r5/MODEL_HOST.json"))
files = {}
candidates = {
  "fill": comfy/"models/diffusion_models/flux1-fill-dev.safetensors",
  "t5_fp16": comfy/"models/text_encoders/t5xxl_fp16.safetensors",
  "t5_fp8": comfy/"models/text_encoders/t5xxl_fp8_e4m3fn.safetensors",
  "clip_l": comfy/"models/text_encoders/clip_l.safetensors",
  "ae": comfy/"models/vae/ae.safetensors",
}
total = 0
for k,p in candidates.items():
  if p.is_file():
    b = p.stat().st_size
    files[k] = {"path": str(p), "bytes": b}
    total += b
payload = {
  "pipeline": "r5_flux_fill_models",
  "hostname": os.uname().nodename,
  "alias": os.environ.get("AUTODL_MACHINE_ALIAS", ""),
  "uuid": os.environ.get("AUTODL_INSTANCE_UUID", ""),
  "comfy": str(comfy),
  "df": os.popen("df -h /root/autodl-tmp | tail -1").read().strip(),
  "files": files,
  "total_bytes": total,
}
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
print("MODEL_HOST_JSON", out)
print(f"TOTAL_GB {total/1e9:.2f}")
need = ["fill", "ae"]
t5_ok = "t5_fp16" in files or "t5_fp8" in files
if all(k in files for k in need) and t5_ok:
  print("R5_MODELS_OK")
  print("R5_MODELS_DONE")
else:
  print("R5_MODELS_FAIL missing", [k for k in need if k not in files], "t5", t5_ok)
  raise SystemExit(2)
PY
rc=$?
exit $rc
