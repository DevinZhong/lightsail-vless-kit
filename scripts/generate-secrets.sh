#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/internal/common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/generate-secrets.sh [--force]

Generates VLESS Reality secrets into secrets.local.env.
Requires xray in PATH to generate REALITY x25519 keys.
USAGE
}

force=false
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
elif [[ "${1:-}" == "--force" ]]; then
  force=true
elif [[ $# -gt 0 ]]; then
  usage
  exit 1
fi

cd "$ROOT_DIR"
secrets_file="$ROOT_DIR/secrets.local.env"

existing_vless=""
existing_private=""
existing_public=""
existing_short=""
if [[ -f "$secrets_file" ]]; then
  # shellcheck disable=SC1090
  source "$secrets_file"
  existing_vless="${VLESS_UUID:-}"
  existing_private="${REALITY_PRIVATE_KEY:-}"
  existing_public="${REALITY_PUBLIC_KEY:-}"
  existing_short="${REALITY_SHORT_ID:-}"
fi

make_uuid() {
  if command -v xray >/dev/null 2>&1; then
    xray uuid
  elif command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
  fi
}

make_hex() {
  openssl rand -hex "$1"
}

require_cmd openssl
if ! command -v xray >/dev/null 2>&1; then
  die "xray is required in PATH to generate REALITY key pair. Install Xray locally or paste REALITY keys into secrets.local.env manually."
fi

if [[ "$force" == false && -f "$secrets_file" && -n "$existing_vless$existing_private$existing_public$existing_short" ]]; then
  warn "$secrets_file already has values. Reusing existing non-empty values. Use --force to rotate."
fi

VLESS_UUID_OUT="$existing_vless"
REALITY_PRIVATE_KEY_OUT="$existing_private"
REALITY_PUBLIC_KEY_OUT="$existing_public"
REALITY_SHORT_ID_OUT="$existing_short"

if [[ "$force" == true || -z "$VLESS_UUID_OUT" ]]; then
  VLESS_UUID_OUT="$(make_uuid)"
fi

if [[ "$force" == true || -z "$REALITY_PRIVATE_KEY_OUT" || -z "$REALITY_PUBLIC_KEY_OUT" ]]; then
  key_output="$(xray x25519)"
  REALITY_PRIVATE_KEY_OUT="$(printf '%s\n' "$key_output" | awk -F': ' '/Private key/ {print $2}')"
  REALITY_PUBLIC_KEY_OUT="$(printf '%s\n' "$key_output" | awk -F': ' '/Public key/ {print $2}')"
  [[ -n "$REALITY_PRIVATE_KEY_OUT" && -n "$REALITY_PUBLIC_KEY_OUT" ]] || die "Could not parse xray x25519 output."
fi

if [[ "$force" == true || -z "$REALITY_SHORT_ID_OUT" ]]; then
  REALITY_SHORT_ID_OUT="$(make_hex 8)"
fi

umask 077
cat > "$secrets_file" <<EOF
# Local proxy secrets. Do not commit.
VLESS_UUID=$VLESS_UUID_OUT
REALITY_PRIVATE_KEY=$REALITY_PRIVATE_KEY_OUT
REALITY_PUBLIC_KEY=$REALITY_PUBLIC_KEY_OUT
REALITY_SHORT_ID=$REALITY_SHORT_ID_OUT
EOF
chmod 600 "$secrets_file" 2>/dev/null || true

info "Wrote secrets.local.env with restricted permissions where supported."
info "Do not commit or share this file."
