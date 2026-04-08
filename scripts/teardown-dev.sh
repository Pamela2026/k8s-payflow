#!/usr/bin/env bash
set -euo pipefail

ENV="${ENV:-dev}"
REGION="${REGION:-us-east-1}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
SKIP_FOUNDATION="${SKIP_FOUNDATION:-false}"
K8S_TEARDOWN="${K8S_TEARDOWN:-false}"
K8S_ENV_DIR="${K8S_ENV_DIR:-overlays/${ENV}}"

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
PLATFORM_ADDONS_DIR="$ROOT_DIR/terraform/environments/$ENV/platform/addons"
WORKLOADS_DIR="$ROOT_DIR/terraform/environments/$ENV/workloads"

confirm_destroy() {
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    return 0
  fi
  echo "You are about to DESTROY resources for env '$ENV'."
  echo "Type 'destroy' to continue:"
  read -r reply
  [[ "$reply" == "destroy" ]]
}

tf_destroy() {
  local dir="$1"
  echo "==> Terraform destroy in $dir"
  terraform -chdir="$dir" init
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    terraform -chdir="$dir" destroy -auto-approve
  else
    terraform -chdir="$dir" destroy
  fi
}

confirm_destroy || { echo "Aborted."; exit 1; }

# Optional Kubernetes teardown (k8s resources only).
if [[ "$K8S_TEARDOWN" == "true" ]]; then
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl not found in PATH (required for K8S_TEARDOWN)" >&2
    exit 1
  fi
  if [[ -d "$ROOT_DIR/$K8S_ENV_DIR" ]]; then
    kubectl delete -k "$ROOT_DIR/$K8S_ENV_DIR" || true
  else
    echo "K8S_ENV_DIR not found: $ROOT_DIR/$K8S_ENV_DIR (skipping k8s teardown)"
  fi
fi

# Local destroys (reverse order)
tf_destroy "$PLATFORM_ADDONS_DIR"
tf_destroy "$WORKLOADS_DIR"
tf_destroy "$PLATFORM_INFRA_DIR"
if [[ "$SKIP_FOUNDATION" != "true" ]]; then
  tf_destroy "$FOUNDATION_DIR"
else
  echo "Skipping foundation destroy (SKIP_FOUNDATION=true)"
fi
