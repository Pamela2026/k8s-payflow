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

# Bastion-only inputs (do not require locally)
ADMIN_ROLE_ARN="${TF_VAR_admin_role_arn:-}"
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

BASTION_ID="$(terraform -chdir="$FOUNDATION_DIR" output -json | jq -r '.bastion_instance_id.value')"
if [[ -z "$BASTION_ID" || "$BASTION_ID" == "null" ]]; then
  echo "bastion_instance_id not found in foundation outputs" >&2
  exit 1
fi

if [[ -z "$RDS_PASSWORD" || -z "$JWT_SECRET" || -z "$MQ_PASSWORD" ]]; then
  echo "Missing required env vars. Set TF_VAR_rds_password, TF_VAR_jwt_secret, TF_VAR_mq_password" >&2
  exit 1
fi
if [[ -z "$ADMIN_ROLE_ARN" ]]; then
  echo "TF_VAR_admin_role_arn not set. Continuing local applies; bastion addons will run without this export." >&2
fi

ADDON_DIR="$BASTION_REPO/terraform/environments/$ENV/platform/addons"
KCFG_SCRIPT="$BASTION_REPO/terraform/environments/$ENV/platform/infra/scripts/kcfg.sh"
SERVICES_DIR="$BASTION_REPO/terraform/environments/$ENV/workloads"
DNS_DIR="$BASTION_REPO/terraform/environments/$ENV/platform/infra"

BASTION_CMDS=$(cat <<EOF
set -euo pipefail
if [ ! -d "$BASTION_REPO/.git" ]; then git clone "$REPO_URL" "$BASTION_REPO"; fi
cd "$BASTION_REPO"
git fetch origin
git checkout "$BASTION_BRANCH"
git pull
export TF_CLI_ARGS="-no-color"
if [[ -n "$ADMIN_ROLE_ARN" ]]; then
  export TF_VAR_admin_role_arn="$ADMIN_ROLE_ARN"
fi
export TF_VAR_rds_password="$RDS_PASSWORD"
export TF_VAR_jwt_secret="$JWT_SECRET"
export TF_VAR_mq_password="$MQ_PASSWORD"
bash "$KCFG_SCRIPT" || true
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
cd "$ADDON_DIR"
terraform init
EOF
)

BASTION_CMDS+=$'\n'"terraform apply -auto-approve"

if [[ "$SKIP_KUSTOMIZE" != "true" ]]; then
  BASTION_CMDS+=$'\n'"cd \"$BASTION_REPO\""
  BASTION_CMDS+=$'\n'"bash k8s/scripts/render-eks-overlay.sh --env $ENV --services-dir \"$SERVICES_DIR\" --dns-dir \"$DNS_DIR\" || true"
  BASTION_CMDS+=$'\n'"kubectl apply -k overlays/$ENV"
fi

PARAMS_JSON="$(printf '%s\n' "$BASTION_CMDS" | jq -Rs '{commands: (split("\n")[:-1])}')"
aws ssm send-command \
  --document-name "AWS-RunShellScript" \
  --instance-ids "$BASTION_ID" \
  --parameters "$PARAMS_JSON" \
  --region "$REGION" >/tmp/ssm-cmd.json

CMD_ID="$(jq -r '.Command.CommandId' /tmp/ssm-cmd.json)"
echo "==> SSM command id: $CMD_ID"
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$BASTION_ID" --region "$REGION"
aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$BASTION_ID" --region "$REGION" \
  --query 'StandardOutputContent' --output text

# Run workloads after addons are applied
tf_apply "$WORKLOADS_DIR"
