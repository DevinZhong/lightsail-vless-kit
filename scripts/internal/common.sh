#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/output"

info() { printf '[INFO] %s\n' "$*" >&2; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

load_env() {
  local env_file="$ROOT_DIR/.env.local"
  local fallback_env="$ROOT_DIR/.env"
  local secrets_file="$ROOT_DIR/secrets.local.env"

  set -a
  if [[ -f "$env_file" ]]; then
    # shellcheck disable=SC1090
    source "$env_file"
  elif [[ -f "$fallback_env" ]]; then
    # shellcheck disable=SC1090
    source "$fallback_env"
  else
    die "Missing .env.local. Copy .env.example to .env.local and edit it first."
  fi

  if [[ -f "$secrets_file" ]]; then
    # shellcheck disable=SC1090
    source "$secrets_file"
  fi
  set +a
}

aws_args() {
  local args=(--region "${AWS_REGION:?AWS_REGION is required}")
  if [[ -n "${AWS_PROFILE:-}" ]]; then
    args+=(--profile "$AWS_PROFILE")
  fi
  printf '%q ' "${args[@]}"
}

aws_cli() {
  local args=(--region "${AWS_REGION:?AWS_REGION is required}")
  if [[ -n "${AWS_PROFILE:-}" ]]; then
    args+=(--profile "$AWS_PROFILE")
  fi
  aws "${args[@]}" "$@"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

require_env() {
  local name
  for name in "$@"; do
    [[ -n "${!name:-}" ]] || die "Required environment variable is empty: $name"
  done
}

ensure_output_dir() {
  mkdir -p "$OUTPUT_DIR"
}

replace_token() {
  local file="$1"
  local name="$2"
  local value="${!name:-}"
  local escaped
  escaped="$(printf '%s' "$value" | sed -e 's/[\/&]/\\&/g')"
  sed -i "s|{{$name}}|$escaped|g" "$file"
}

replace_tokens() {
  local file="$1"
  shift
  local name
  for name in "$@"; do
    replace_token "$file" "$name"
  done
}

validate_no_unrendered_tokens() {
  local file="$1"
  if grep -q '{{[A-Z0-9_]*}}' "$file"; then
    grep -n '{{[A-Z0-9_]*}}' "$file" >&2 || true
    die "Unrendered template token found in $file"
  fi
}

bool_is_true() {
  case "${1:-}" in
    true|TRUE|1|yes|YES|y|Y) return 0 ;;
    *) return 1 ;;
  esac
}

check_aws_identity() {
  require_cmd aws
  info "Checking AWS CLI identity..."
  aws_cli sts get-caller-identity >/dev/null || die "AWS CLI is not authenticated. Run aws configure sso or aws configure first."
}

