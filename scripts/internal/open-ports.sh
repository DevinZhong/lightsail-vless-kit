#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

load_env
check_aws_identity
require_env LIGHTSAIL_INSTANCE_NAME SSH_ALLOWED_CIDR

open_port() {
  local protocol="$1"
  local from_port="$2"
  local to_port="$3"
  local cidr="$4"
  local port_info
  info "Opening $protocol $from_port-$to_port for $cidr on $LIGHTSAIL_INSTANCE_NAME"
  port_info=$(printf '{"fromPort":%s,"toPort":%s,"protocol":"%s","cidrs":["%s"]}' "$from_port" "$to_port" "$protocol" "$cidr")
  aws_cli lightsail open-instance-public-ports \
    --instance-name "$LIGHTSAIL_INSTANCE_NAME" \
    --port-info "$port_info" >/dev/null
}

open_port tcp 443 443 0.0.0.0/0
open_port tcp 22 22 "$SSH_ALLOWED_CIDR"

info "Requested Lightsail firewall updates."
