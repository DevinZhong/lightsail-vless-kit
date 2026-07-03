#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

load_env
host="${1:-}"
if [[ -z "$host" ]]; then
  host="$("$ROOT_DIR/scripts/internal/get-instance-ip.sh")"
fi
port="${2:-22}"
timeout_seconds="${WAIT_SSH_TIMEOUT:-300}"

info "Waiting for TCP $host:$port for up to ${timeout_seconds}s..."
end=$((SECONDS + timeout_seconds))
while (( SECONDS < end )); do
  if command -v nc >/dev/null 2>&1; then
    if nc -z -w 3 "$host" "$port" >/dev/null 2>&1; then
      info "TCP $host:$port is reachable."
      exit 0
    fi
  else
    if timeout 3 bash -c "</dev/tcp/$host/$port" >/dev/null 2>&1; then
      info "TCP $host:$port is reachable."
      exit 0
    fi
  fi
  sleep 5
done

die "Timed out waiting for TCP $host:$port"
