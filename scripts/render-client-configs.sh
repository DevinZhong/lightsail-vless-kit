#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

provided_server_ip="${SERVER_IP:-}"
load_env
ensure_output_dir
if [[ -n "$provided_server_ip" ]]; then
  SERVER_IP="$provided_server_ip"
fi

if [[ -z "${SERVER_IP:-}" ]]; then
  if [[ -n "${LIGHTSAIL_INSTANCE_NAME:-}" && -n "${AWS_REGION:-}" ]] && command -v aws >/dev/null 2>&1; then
    SERVER_IP="$("$ROOT_DIR/scripts/get-instance-ip.sh" 2>/dev/null || true)"
  fi
fi

require_env SERVER_IP NODE_NAME VLESS_UUID REALITY_PUBLIC_KEY REALITY_SHORT_ID REALITY_SERVER_NAME REALITY_FINGERPRINT

url_encoded_name="${NODE_NAME// /%20}"
VLESS_URL="vless://${VLESS_UUID}@${SERVER_IP}:443?encryption=none&security=reality&sni=${REALITY_SERVER_NAME}&fp=${REALITY_FINGERPRINT}&pbk=${REALITY_PUBLIC_KEY}&sid=${REALITY_SHORT_ID}&spx=%2F&type=tcp&flow=xtls-rprx-vision#${url_encoded_name}-reality"

printf '%s\n' "$VLESS_URL" > "$OUTPUT_DIR/vless-reality-url.txt"

cp "$ROOT_DIR/client-config/vless-reality.json.tpl" "$OUTPUT_DIR/vless-reality.json"
replace_tokens "$OUTPUT_DIR/vless-reality.json" SERVER_IP NODE_NAME VLESS_UUID REALITY_PUBLIC_KEY REALITY_SHORT_ID REALITY_SERVER_NAME REALITY_FINGERPRINT
validate_no_unrendered_tokens "$OUTPUT_DIR/vless-reality.json"

subscription_lines=("$VLESS_URL")

if bool_is_true "${HYSTERIA_ENABLED:-false}"; then
  require_env HYSTERIA_PASSWORD HYSTERIA_SNI
  HYSTERIA_URL="hysteria2://${HYSTERIA_PASSWORD}@${SERVER_IP}:443/?insecure=1&sni=${HYSTERIA_SNI}#${url_encoded_name}-hy2"
  printf '%s\n' "$HYSTERIA_URL" > "$OUTPUT_DIR/hysteria2-url.txt"

  cp "$ROOT_DIR/client-config/hysteria2.yaml.tpl" "$OUTPUT_DIR/hysteria2.yaml"
  replace_tokens "$OUTPUT_DIR/hysteria2.yaml" SERVER_IP NODE_NAME HYSTERIA_PASSWORD HYSTERIA_SNI
  validate_no_unrendered_tokens "$OUTPUT_DIR/hysteria2.yaml"
  subscription_lines+=("$HYSTERIA_URL")
else
  rm -f "$OUTPUT_DIR/hysteria2-url.txt" "$OUTPUT_DIR/hysteria2.yaml"
fi

printf '%s\n' "${subscription_lines[@]}" > "$OUTPUT_DIR/subscription.txt"
if command -v base64 >/dev/null 2>&1; then
  if base64 --help 2>&1 | grep -q -- '-w'; then
    base64 -w0 "$OUTPUT_DIR/subscription.txt" > "$OUTPUT_DIR/subscription.base64.txt"
  else
    base64 "$OUTPUT_DIR/subscription.txt" | tr -d '\n' > "$OUTPUT_DIR/subscription.base64.txt"
  fi
  printf '\n' >> "$OUTPUT_DIR/subscription.base64.txt"
fi

chmod 600 "$OUTPUT_DIR"/*.txt "$OUTPUT_DIR"/*.json "$OUTPUT_DIR"/*.yaml 2>/dev/null || true

info "Rendered local client files under output/."
info "These files contain proxy credentials and are ignored by git."

