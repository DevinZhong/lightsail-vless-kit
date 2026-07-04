#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

insert_file_at_token() {
  local target="$1"
  local token="$2"
  local insert_file="$3"
  local tmp="${target}.tmp"
  awk -v token="{{$token}}" -v insert_file="$insert_file" '
    index($0, token) {
      while ((getline line < insert_file) > 0) print line
      close(insert_file)
      next
    }
    { print }
  ' "$target" > "$tmp"
  mv "$tmp" "$target"
}

render_child_template() {
  local src="$1"
  local out="$2"
  shift 2
  cp "$src" "$out"
  replace_tokens "$out" "$@"
  validate_no_unrendered_tokens "$out"
}

load_env
ensure_output_dir

require_env AWS_REGION AWS_AZ LIGHTSAIL_INSTANCE_NAME LIGHTSAIL_BUNDLE_ID LIGHTSAIL_BLUEPRINT_ID
require_env VLESS_UUID REALITY_PRIVATE_KEY REALITY_PUBLIC_KEY REALITY_SHORT_ID

workdir="$OUTPUT_DIR/rendered"
rm -rf "$workdir"
mkdir -p "$workdir"

render_child_template "$ROOT_DIR/server-config/xray-config.tpl.json" "$workdir/xray-config.json" \
  VLESS_UUID REALITY_PRIVATE_KEY REALITY_SHORT_ID REALITY_SERVER_NAME REALITY_DEST
cp "$ROOT_DIR/server-config/xray.service" "$workdir/xray.service"

src="$ROOT_DIR/cloud-init/cloud-init.tpl.sh"
out="$OUTPUT_DIR/cloud-init.sh"
[[ -f "$src" ]] || die "Missing template: $src"
cp "$src" "$out"
chmod 600 "$out" 2>/dev/null || true

replace_tokens "$out" XRAY_VERSION
insert_file_at_token "$out" XRAY_CONFIG "$workdir/xray-config.json"
insert_file_at_token "$out" XRAY_SERVICE "$workdir/xray.service"

validate_no_unrendered_tokens "$out"
info "Rendered sensitive cloud-init to $out"
info "This file contains proxy secrets. It is ignored by git."
