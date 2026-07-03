#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/internal/common.sh"

load_env

if bool_is_true "${REBUILD_DELETE_OLD:-false}"; then
  info "REBUILD_DELETE_OLD=true, deleting existing instance first."
  CONFIRM_DELETE=1 "$ROOT_DIR/scripts/delete-lightsail.sh" --yes
  sleep 10
else
  info "REBUILD_DELETE_OLD is false. create-lightsail.sh will fail if the instance name already exists."
fi

"$ROOT_DIR/scripts/create-lightsail.sh"
