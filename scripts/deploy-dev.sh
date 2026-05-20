#!/usr/bin/env bash
set -euo pipefail

ENV="${ENV:-dev}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

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

print_next_steps() {
  cat <<EOF

==> What happens next

- foundation and platform/infra are ready for the CI/GitOps pipeline
- platform/addons is applied through the bastion/SSM path in CI
- ingress and app rollout are driven by GitOps, not this local helper
- edge is intentionally disabled in the current setup and kept only as commented future config

EOF
}

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

cat <<EOF

==> Local Terraform complete for:
- foundation
- platform/infra

Stopping here by design.
- platform/addons uses Kubernetes/Helm providers against a private EKS API and should be applied from the bastion.
- edge is not part of the active path right now.

EOF

print_next_steps
