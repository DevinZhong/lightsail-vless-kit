#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/internal/common.sh"

usage() {
  cat <<'USAGE'
Usage: scripts/create-lightsail.sh

Creates one AWS Lightsail instance and injects rendered cloud-init.
Requires AWS CLI to be authenticated before running.
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

load_env
check_aws_identity
require_env AWS_REGION AWS_AZ LIGHTSAIL_INSTANCE_NAME LIGHTSAIL_BUNDLE_ID LIGHTSAIL_BLUEPRINT_ID
require_env VLESS_UUID REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY REALITY_SHORT_ID

existing="$(aws_cli lightsail get-instance --instance-name "$LIGHTSAIL_INSTANCE_NAME" --query 'instance.name' --output text 2>/dev/null || true)"
if [[ "$existing" == "$LIGHTSAIL_INSTANCE_NAME" ]]; then
  die "Lightsail instance already exists: $LIGHTSAIL_INSTANCE_NAME. Delete it first or choose another name."
fi

"$ROOT_DIR/scripts/internal/render-cloud-init.sh"

create_args=(lightsail create-instances
  --instance-names "$LIGHTSAIL_INSTANCE_NAME"
  --availability-zone "$AWS_AZ"
  --blueprint-id "$LIGHTSAIL_BLUEPRINT_ID"
  --bundle-id "$LIGHTSAIL_BUNDLE_ID"
  --user-data "file://$OUTPUT_DIR/cloud-init.sh"
  --ip-address-type ipv4)

if [[ -n "${SSH_KEY_NAME:-}" ]]; then
  create_args+=(--key-pair-name "$SSH_KEY_NAME")
fi

info "Creating Lightsail instance $LIGHTSAIL_INSTANCE_NAME in $AWS_AZ..."
aws_cli "${create_args[@]}" >/dev/null

if bool_is_true "${USE_STATIC_IP:-false}"; then
  require_env LIGHTSAIL_STATIC_IP_NAME
  static_exists="$(aws_cli lightsail get-static-ip --static-ip-name "$LIGHTSAIL_STATIC_IP_NAME" --query 'staticIp.name' --output text 2>/dev/null || true)"
  if [[ "$static_exists" != "$LIGHTSAIL_STATIC_IP_NAME" ]]; then
    info "Allocating Static IP $LIGHTSAIL_STATIC_IP_NAME..."
    aws_cli lightsail allocate-static-ip --static-ip-name "$LIGHTSAIL_STATIC_IP_NAME" >/dev/null
  fi
  info "Attaching Static IP $LIGHTSAIL_STATIC_IP_NAME..."
  aws_cli lightsail attach-static-ip --static-ip-name "$LIGHTSAIL_STATIC_IP_NAME" --instance-name "$LIGHTSAIL_INSTANCE_NAME" >/dev/null
fi

"$ROOT_DIR/scripts/internal/open-ports.sh"

info "Waiting for instance to expose a public IP..."
for _ in {1..60}; do
  SERVER_IP="$("$ROOT_DIR/scripts/internal/get-instance-ip.sh" 2>/dev/null || true)"
  if [[ -n "$SERVER_IP" ]]; then
    break
  fi
  sleep 5
done
[[ -n "${SERVER_IP:-}" ]] || die "Instance did not get a public IP in time."

"$ROOT_DIR/scripts/internal/wait-ssh.sh" "$SERVER_IP" 22 || warn "SSH was not reachable yet. cloud-init may still be running."

SERVER_IP="$SERVER_IP" "$ROOT_DIR/scripts/internal/render-client-configs.sh"

cat <<EOF
Instance created.
Public IP: $SERVER_IP

Client files:
  output/vless-reality-url.txt
  output/subscription.txt
EOF
if bool_is_true "${HYSTERIA_ENABLED:-false}"; then
  cat <<EOF
  output/hysteria2-url.txt
EOF
fi

cat <<'EOF'

Server checks after SSH is ready:
  sudo systemctl status xray
  sudo journalctl -u xray -e
  sudo tail -n 200 /var/log/proxy-bootstrap.log
EOF
