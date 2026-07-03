#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/internal/common.sh"

yes=false
if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
  yes=true
elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  cat <<'USAGE'
Usage: scripts/delete-lightsail.sh [--yes]

Deletes the configured Lightsail instance. Stopping an instance is not enough to avoid all costs.
USAGE
  exit 0
fi

load_env
check_aws_identity
require_env LIGHTSAIL_INSTANCE_NAME

if [[ "$yes" != true && "${CONFIRM_DELETE:-}" != "1" ]]; then
  die "Refusing to delete without --yes or CONFIRM_DELETE=1. Target: $LIGHTSAIL_INSTANCE_NAME"
fi

info "Deleting Lightsail instance $LIGHTSAIL_INSTANCE_NAME..."
aws_cli lightsail delete-instance --instance-name "$LIGHTSAIL_INSTANCE_NAME" >/dev/null || warn "Delete instance request failed or instance did not exist."

if bool_is_true "${USE_STATIC_IP:-false}" && bool_is_true "${RELEASE_STATIC_IP_ON_DELETE:-false}"; then
  require_env LIGHTSAIL_STATIC_IP_NAME
  info "Releasing Static IP $LIGHTSAIL_STATIC_IP_NAME..."
  aws_cli lightsail release-static-ip --static-ip-name "$LIGHTSAIL_STATIC_IP_NAME" >/dev/null || warn "Static IP release failed or IP did not exist."
else
  info "Static IP release skipped. USE_STATIC_IP=${USE_STATIC_IP:-false}, RELEASE_STATIC_IP_ON_DELETE=${RELEASE_STATIC_IP_ON_DELETE:-false}"
fi

info "Delete request submitted. Check Lightsail console or AWS CLI for final state."
