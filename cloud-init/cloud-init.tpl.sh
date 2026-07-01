#!/usr/bin/env bash
set -euo pipefail

# Cloud-init bootstrap for personal fixed-exit node.
# This rendered file contains proxy secrets. Do not commit rendered output.

exec > >(tee -a /var/log/proxy-bootstrap.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

XRAY_VERSION="{{XRAY_VERSION}}"
HYSTERIA_VERSION="{{HYSTERIA_VERSION}}"
HYSTERIA_ENABLED="{{HYSTERIA_ENABLED}}"

log() { printf '[bootstrap] %s\n' "$*"; }
fatal() { printf '[bootstrap][ERROR] %s\n' "$*"; exit 1; }

arch_xray() {
  case "$(uname -m)" in
    x86_64|amd64) printf '64' ;;
    aarch64|arm64) printf 'arm64-v8a' ;;
    *) fatal "Unsupported architecture for Xray: $(uname -m)" ;;
  esac
}

arch_hysteria() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *) fatal "Unsupported architecture for Hysteria: $(uname -m)" ;;
  esac
}

latest_github_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name'
}

install_base() {
  log "Installing base packages..."
  apt-get update
  apt-get install -y curl wget unzip jq ca-certificates openssl ufw
}

install_xray() {
  local version="$XRAY_VERSION"
  local asset_arch
  asset_arch="$(arch_xray)"
  if [[ -z "$version" ]]; then
    version="$(latest_github_tag XTLS/Xray-core | sed 's/^v//')"
  fi
  log "Installing Xray-core v${version}..."
  tmpdir="$(mktemp -d)"
  url="https://github.com/XTLS/Xray-core/releases/download/v${version}/Xray-linux-${asset_arch}.zip"
  curl -fL "$url" -o "$tmpdir/xray.zip"
  unzip -q "$tmpdir/xray.zip" -d "$tmpdir/xray"
  install -m 0755 "$tmpdir/xray/xray" /usr/local/bin/xray
  mkdir -p /usr/local/share/xray /usr/local/etc/xray /var/log/xray
  [[ -f "$tmpdir/xray/geoip.dat" ]] && install -m 0644 "$tmpdir/xray/geoip.dat" /usr/local/share/xray/geoip.dat
  [[ -f "$tmpdir/xray/geosite.dat" ]] && install -m 0644 "$tmpdir/xray/geosite.dat" /usr/local/share/xray/geosite.dat
  rm -rf "$tmpdir"
}

install_hysteria() {
  [[ "$HYSTERIA_ENABLED" == "true" ]] || { log "Hysteria2 disabled."; return 0; }
  local version="$HYSTERIA_VERSION"
  local asset_arch
  asset_arch="$(arch_hysteria)"
  if [[ -z "$version" ]]; then
    version="$(latest_github_tag apernet/hysteria | sed 's#^app/v##; s#^v##')"
  fi
  log "Installing Hysteria2 v${version}..."
  url="https://github.com/apernet/hysteria/releases/download/app/v${version}/hysteria-linux-${asset_arch}"
  curl -fL "$url" -o /usr/local/bin/hysteria
  chmod 0755 /usr/local/bin/hysteria
  mkdir -p /etc/hysteria /var/log/hysteria
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

  if [[ "$HYSTERIA_ENABLED" == "true" ]]; then
    log "Writing Hysteria2 config and self-signed certificate..."
    mkdir -p /etc/hysteria
    openssl req -x509 -newkey rsa:2048 \
      -keyout /etc/hysteria/server.key \
      -out /etc/hysteria/server.crt \
      -days 3650 \
      -nodes \
      -subj "/CN={{HYSTERIA_SNI}}"
    chmod 600 /etc/hysteria/server.key

    cat > /etc/hysteria/config.yaml <<'HYSTERIA_CONFIG'
{{HYSTERIA_CONFIG}}
HYSTERIA_CONFIG
    chmod 600 /etc/hysteria/config.yaml

    cat > /etc/systemd/system/hysteria-server.service <<'HYSTERIA_SERVICE'
{{HYSTERIA_SERVICE}}
HYSTERIA_SERVICE
  fi
}

configure_firewall() {
  log "Configuring UFW..."
  ufw allow 22/tcp || true
  ufw allow 443/tcp || true
  if [[ "$HYSTERIA_ENABLED" == "true" ]]; then
    ufw allow 443/udp || true
  fi
  ufw --force enable || true
}

start_services() {
  log "Validating Xray config..."
  /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
  systemctl daemon-reload
  systemctl enable --now xray
  if [[ "$HYSTERIA_ENABLED" == "true" ]]; then
    systemctl enable --now hysteria-server
  fi
  systemctl --no-pager status xray || true
  if [[ "$HYSTERIA_ENABLED" == "true" ]]; then
    systemctl --no-pager status hysteria-server || true
  fi
}

install_base
install_xray
install_hysteria
write_configs
configure_firewall
start_services
log "Bootstrap complete."
