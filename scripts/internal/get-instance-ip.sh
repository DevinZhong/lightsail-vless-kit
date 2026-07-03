#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

load_env
check_aws_identity

require_env LIGHTSAIL_INSTANCE_NAME

ip="$(aws_cli lightsail get-instance \
  --instance-name "$LIGHTSAIL_INSTANCE_NAME" \
  --query 'instance.publicIpAddress' \
  --output text 2>/dev/null || true)"

if [[ -z "$ip" || "$ip" == "None" ]]; then
  die "Could not find public IP for instance: $LIGHTSAIL_INSTANCE_NAME"
fi

printf '%s\n' "$ip"
