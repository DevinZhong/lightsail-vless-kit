#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'USAGE'
Usage: scripts/lightsail-proxy.sh [preflight|generate-secrets|create|rebuild|delete]

Cross-platform entry for the currently supported Bash actions. Run with no
argument for an interactive menu. Region migration, v2rayN helpers, and SSH
key-pair management remain PowerShell-only at this stage.
USAGE
}

run_action() {
  case "$1" in
    preflight)
      command -v aws >/dev/null || { echo '[ERROR] AWS CLI is required.' >&2; return 1; }
      [[ -f "$ROOT_DIR/.env.local" ]] || { echo '[ERROR] Missing .env.local.' >&2; return 1; }
      echo '[INFO] Checking AWS CLI identity...'
      (cd "$ROOT_DIR" && source scripts/internal/common.sh && load_env && check_aws_identity)
      [[ -f "$ROOT_DIR/secrets.local.env" ]] || echo '[WARN] Missing secrets.local.env; run generate-secrets.' >&2
      ;;
    generate-secrets) "$ROOT_DIR/scripts/bash/generate-secrets.sh" ;;
    create) "$ROOT_DIR/scripts/bash/create-lightsail.sh" ;;
    rebuild) "$ROOT_DIR/scripts/bash/rebuild-proxy.sh" ;;
    delete) "$ROOT_DIR/scripts/bash/delete-lightsail.sh" --yes ;;
    *) usage; return 2 ;;
  esac
}

case "${1:-}" in
  -h|--help) usage ;;
  preflight|generate-secrets|create|rebuild|delete) run_action "$1" ;;
  '')
    echo '1. 环境预检 / Preflight'
    echo '2. 生成密钥 / Generate secrets'
    echo '3. 创建节点 / Create node'
    echo '4. 重建节点 / Rebuild node'
    echo '5. 删除节点 / Delete node'
    read -r -p 'Select [1-5]: ' choice
    case "$choice" in 1) run_action preflight;; 2) run_action generate-secrets;; 3) run_action create;; 4) run_action rebuild;; 5) run_action delete;; *) echo 'Invalid choice.' >&2; exit 2;; esac
    ;;
  *) usage; exit 2 ;;
esac
