#!/usr/bin/env bash
set -euo pipefail

ENV="${ENV:-dev}"
REGION="${REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-payflow-eks-dev}"
REPO_URL="${REPO_URL:-https://github.com/Pamela2026/k8s-payflow.git}"
BASTION_REPO="${BASTION_REPO:-/home/ssm-user/k8s-payflow}"
BASTION_BRANCH="${BASTION_BRANCH:-test}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"
SKIP_KUSTOMIZE="${SKIP_KUSTOMIZE:-false}"
SKIP_FOUNDATION="${SKIP_FOUNDATION:-false}"

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

BASTION_ID="$(terraform -chdir="$FOUNDATION_DIR" output -json | jq -r '.bastion_instance_id.value')"
if [[ -z "$BASTION_ID" || "$BASTION_ID" == "null" ]]; then
  echo "bastion_instance_id not found in foundation outputs" >&2
  exit 1
fi

ADDON_DIR="$BASTION_REPO/terraform/environments/$ENV/platform/addons"

BASTION_CMDS=$(cat <<EOF
set -euo pipefail
if [ ! -d "$BASTION_REPO/.git" ]; then git clone "$REPO_URL" "$BASTION_REPO"; fi
cd "$BASTION_REPO"
git fetch origin
git checkout "$BASTION_BRANCH"
git pull
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
EOF
)

if [[ "$SKIP_KUSTOMIZE" != "true" ]]; then
  BASTION_CMDS+=$'\n'"kubectl delete -k overlays/$ENV || true"
fi

BASTION_CMDS+=$'\n'"cd \"$ADDON_DIR\""
BASTION_CMDS+=$'\n'"terraform init"
if [[ "$AUTO_APPROVE" == "true" ]]; then
  BASTION_CMDS+=$'\n'"terraform destroy -auto-approve"
else
  BASTION_CMDS+=$'\n'"terraform destroy"
fi

aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --instance-ids "$BASTION_ID" \
  --parameters "commands=$BASTION_CMDS" \
  --region "$REGION" >/tmp/ssm-cmd.json

CMD_ID="$(jq -r '.Command.CommandId' /tmp/ssm-cmd.json)"
echo "==> SSM command id: $CMD_ID"
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$BASTION_ID" --region "$REGION"
aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$BASTION_ID" --region "$REGION" \
  --query 'StandardOutputContent' --output text

# Local destroys (reverse order)
tf_destroy "$WORKLOADS_DIR"
tf_destroy "$PLATFORM_INFRA_DIR"
if [[ "$SKIP_FOUNDATION" != "true" ]]; then
  tf_destroy "$FOUNDATION_DIR"
else
  echo "Skipping foundation destroy (SKIP_FOUNDATION=true)"
fi
