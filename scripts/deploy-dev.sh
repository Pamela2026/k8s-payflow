#!/usr/bin/env bash
set -euo pipefail

ENV="${ENV:-dev}"
REGION="${REGION:-us-east-1}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

RDS_PASSWORD="${TF_VAR_rds_password:-}"
JWT_SECRET="${TF_VAR_jwt_secret:-}"
MQ_PASSWORD="${TF_VAR_mq_password:-}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found in PATH" >&2
  exit 1
fi
if ! command -v aws >/dev/null 2>&1; then
  echo "aws not found in PATH" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq not found in PATH (required for terraform output -json parsing)" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOUNDATION_DIR="$ROOT_DIR/terraform/environments/$ENV/foundation"
PLATFORM_INFRA_DIR="$ROOT_DIR/terraform/environments/$ENV/platform/infra"
WORKLOADS_DIR="$ROOT_DIR/terraform/environments/$ENV/workloads"
PLATFORM_ADDONS_DIR="$ROOT_DIR/terraform/environments/$ENV/platform/addons"

tf_apply() {
  local dir="$1"
  echo "==> Terraform in $dir"
  terraform -chdir="$dir" init
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    terraform -chdir="$dir" apply -auto-approve || terraform -chdir="$dir" apply -auto-approve
  else
    terraform -chdir="$dir" apply || terraform -chdir="$dir" apply
  fi
}

tf_apply "$FOUNDATION_DIR"
tf_apply "$PLATFORM_INFRA_DIR"

if [[ -z "$RDS_PASSWORD" || -z "$JWT_SECRET" || -z "$MQ_PASSWORD" ]]; then
  echo "Missing required env vars. Set TF_VAR_rds_password, TF_VAR_jwt_secret, TF_VAR_mq_password" >&2
  exit 1
fi
# Workloads depend on platform/infra outputs and require secrets.
tf_apply "$WORKLOADS_DIR"

# Addons should run after workloads if they depend on Secrets Manager values.
tf_apply "$PLATFORM_ADDONS_DIR"
