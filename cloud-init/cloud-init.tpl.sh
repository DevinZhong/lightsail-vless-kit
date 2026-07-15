#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi
set -euo pipefail

# Cloud-init bootstrap for personal fixed-exit node.
# This rendered file contains proxy secrets. Do not commit rendered output.

exec > >(tee -a /var/log/proxy-bootstrap.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

XRAY_VERSION="{{XRAY_VERSION}}"

log() { printf '[bootstrap] %s\n' "$*"; }
fatal() { printf '[bootstrap][ERROR] %s\n' "$*"; exit 1; }

arch_xray() {
  case "$(uname -m)" in
    x86_64|amd64) printf '64' ;;
    aarch64|arm64) printf 'arm64-v8a' ;;
    *) fatal "Unsupported architecture for Xray: $(uname -m)" ;;
  esac
}

install_base() {
  log "Installing base packages..."
  apt-get update
  apt-get install -y curl wget unzip jq ca-certificates ufw
}

install_xray() {
  local version="$XRAY_VERSION"
  local asset_arch asset_name checksum_url expected_sha actual_sha
  asset_arch="$(arch_xray)"
  [[ -n "$version" ]] || fatal 'XRAY_VERSION must be pinned to an explicit version.'
  log "Installing Xray-core v${version}..."
  tmpdir="$(mktemp -d)"
  asset_name="Xray-linux-${asset_arch}.zip"
  url="https://github.com/XTLS/Xray-core/releases/download/v${version}/${asset_name}"
  checksum_url="${url}.dgst"
  curl -fL "$url" -o "$tmpdir/xray.zip"
  curl -fL "$checksum_url" -o "$tmpdir/xray.zip.dgst"
  expected_sha="$(grep -Eio '[a-f0-9]{64}' "$tmpdir/xray.zip.dgst" | head -n 1 | tr '[:upper:]' '[:lower:]' || true)"
  [[ -n "$expected_sha" ]] || fatal "Could not parse SHA-256 from $checksum_url"
  actual_sha="$(sha256sum "$tmpdir/xray.zip" | awk '{print $1}')"
  [[ "$actual_sha" == "$expected_sha" ]] || fatal 'Xray release checksum verification failed.'
  log 'Xray release checksum verified.'
  unzip -q "$tmpdir/xray.zip" -d "$tmpdir/xray"
  install -m 0755 "$tmpdir/xray/xray" /usr/local/bin/xray
  mkdir -p /usr/local/share/xray /usr/local/etc/xray /var/log/xray
  [[ -f "$tmpdir/xray/geoip.dat" ]] && install -m 0644 "$tmpdir/xray/geoip.dat" /usr/local/share/xray/geoip.dat
  [[ -f "$tmpdir/xray/geosite.dat" ]] && install -m 0644 "$tmpdir/xray/geosite.dat" /usr/local/share/xray/geosite.dat
  rm -rf "$tmpdir"
}

write_configs() {
  log "Writing Xray config..."
  mkdir -p /usr/local/etc/xray
  cat > /usr/local/etc/xray/config.json <<'XRAY_CONFIG'
{{XRAY_CONFIG}}
XRAY_CONFIG
  chmod 600 /usr/local/etc/xray/config.json

  log "Writing Xray systemd service..."
  cat > /etc/systemd/system/xray.service <<'XRAY_SERVICE'
{{XRAY_SERVICE}}
XRAY_SERVICE
}

configure_firewall() {
  log "Configuring UFW..."
  ufw allow 22/tcp || true
  ufw allow 443/tcp || true
  ufw --force enable || true
}

start_services() {
  log "Validating Xray config..."
  /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
  systemctl daemon-reload
  systemctl enable --now xray
  systemctl --no-pager status xray || true
}

install_base
install_xray
write_configs
configure_firewall
start_services
log "Bootstrap complete."
