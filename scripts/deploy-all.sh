#!/usr/bin/env bash
set -euo pipefail

# ============================================
# DEPLOY ALL (FOUNDATION -> PLATFORM -> K8S -> EDGE)
# ============================================
# This script is a convenience orchestrator for a full environment bring-up.
#
# It will:
# 1) Apply Terraform foundation (local)
# 2) Apply Terraform platform/infra (local)
# 3) Run bastion-side steps via SSM (remote):
#    - Apply Terraform platform/addons (needs private EKS API)
#    - Configure kubectl
#    - Render overlays/<env>/alb-ingress.yaml from platform/infra outputs
#    - Deploy Kubernetes workloads
# 4) Apply Terraform edge (local, last)
#
# Requirements (local):
# - aws, terraform, jq
# Requirements (bastion):
# - aws, terraform, kubectl, jq
# - repo checked out at /home/ssm-user/k8s-payflow (or override BASTION_REPO_DIR)

ENV="${ENV:-dev}"
REGION="${REGION:-us-east-1}"
AUTO_APPROVE="${AUTO_APPROVE:-false}"

# If empty, we'll auto-discover by tag Name=*-${ENV}-bastion or *-bastion.
BASTION_INSTANCE_ID="${BASTION_INSTANCE_ID:-}"
BASTION_REPO_DIR="${BASTION_REPO_DIR:-/home/ssm-user/k8s-payflow}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FOUNDATION_DIR="$ROOT_DIR/terraform/environments/$ENV/foundation"
PLATFORM_INFRA_DIR="$ROOT_DIR/terraform/environments/$ENV/platform/infra"
EDGE_DIR="$ROOT_DIR/terraform/environments/$ENV/edge"

need_cmd() {
  local c="$1"
  command -v "$c" >/dev/null 2>&1 || { echo "$c not found in PATH" >&2; exit 1; }
}

tf_apply() {
  local dir="$1"
  echo "==> Terraform apply: $dir"
  terraform -chdir="$dir" init
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    terraform -chdir="$dir" apply -auto-approve || terraform -chdir="$dir" apply -auto-approve
  else
    terraform -chdir="$dir" apply || terraform -chdir="$dir" apply
  fi
}

discover_bastion() {
  # Try env-specific first, then fall back.
  local id
  id="$(aws ec2 describe-instances \
    --region "$REGION" \
    --filters "Name=tag:Name,Values=*-${ENV}-bastion" "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || true)"
  if [[ -z "$id" || "$id" == "None" ]]; then
    id="$(aws ec2 describe-instances \
      --region "$REGION" \
      --filters "Name=tag:Name,Values=*-bastion" "Name=instance-state-name,Values=running" \
      --query 'Reservations[0].Instances[0].InstanceId' \
      --output text 2>/dev/null || true)"
  fi
  [[ "$id" == "None" ]] && id=""
  echo "$id"
}

ssm_run() {
  local script="$1"

  # We use bash -lc to ensure login-ish behavior (PATH, profiles).
  local payload
  payload="$(jq -nc --arg s "$script" '{commands:["bash -lc " + ($s|tojson)]}')"

  local cmd_id
  cmd_id="$(aws ssm send-command \
    --region "$REGION" \
    --instance-ids "$BASTION_INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --comment "payflow deploy-all ($ENV)" \
    --parameters "$payload" \
    --query 'Command.CommandId' \
    --output text)"

  echo "==> SSM command started: $cmd_id"

  # Wait and then show stdout/stderr at the end (compact but useful).
  aws ssm wait command-executed \
    --region "$REGION" \
    --command-id "$cmd_id" \
    --instance-id "$BASTION_INSTANCE_ID"

  local status
  status="$(aws ssm list-command-invocations \
    --region "$REGION" \
    --command-id "$cmd_id" \
    --details \
    --query 'CommandInvocations[0].Status' \
    --output text)"

  echo "==> SSM command status: $status"

  local out err
  out="$(aws ssm list-command-invocations \
    --region "$REGION" \
    --command-id "$cmd_id" \
    --details \
    --query 'CommandInvocations[0].CommandPlugins[0].Output' \
    --output text)"
  err="$(aws ssm list-command-invocations \
    --region "$REGION" \
    --command-id "$cmd_id" \
    --details \
    --query 'CommandInvocations[0].CommandPlugins[0].StandardErrorContent' \
    --output text)"

  if [[ -n "$out" && "$out" != "None" ]]; then
    echo
    echo "==> Bastion stdout:"
    echo "$out"
  fi
  if [[ -n "$err" && "$err" != "None" ]]; then
    echo
    echo "==> Bastion stderr:"
    echo "$err" >&2
  fi

  if [[ "$status" != "Success" ]]; then
    echo "Bastion step failed (SSM status: $status)." >&2
    exit 1
  fi
}

main() {
  need_cmd aws
  need_cmd terraform
  need_cmd jq

  if [[ -z "${TF_VAR_rds_password:-}" || -z "${TF_VAR_mq_password:-}" || -z "${TF_VAR_jwt_secret:-}" ]]; then
    echo "Missing required env vars: TF_VAR_rds_password, TF_VAR_mq_password, TF_VAR_jwt_secret" >&2
    exit 1
  fi

  echo "==> Deploy-all starting (env=$ENV, region=$REGION)"

  tf_apply "$FOUNDATION_DIR"
  tf_apply "$PLATFORM_INFRA_DIR"

  if [[ -z "$BASTION_INSTANCE_ID" ]]; then
    BASTION_INSTANCE_ID="$(discover_bastion)"
  fi
  if [[ -z "$BASTION_INSTANCE_ID" ]]; then
    echo "Unable to discover bastion instance id. Set BASTION_INSTANCE_ID explicitly." >&2
    exit 1
  fi
  echo "==> Using bastion instance: $BASTION_INSTANCE_ID"

  # Bastion steps: addons -> kubectl -> workloads.
  local remote_auto_approve=()
  if [[ "$AUTO_APPROVE" == "true" ]]; then
    remote_auto_approve+=("-auto-approve")
  fi

  ssm_run "$(cat <<EOS
set -euo pipefail
cd "$BASTION_REPO_DIR"

echo "==> platform/addons"
cd "terraform/environments/$ENV/platform/addons"
terraform init
terraform apply -var-file=terraform.tfvars ${remote_auto_approve[*]}

echo "==> kubectl config"
bash "$BASTION_REPO_DIR/terraform/environments/$ENV/platform/infra/scripts/kcfg.sh"
kubectl get nodes

echo "==> render overlay"
cd "$BASTION_REPO_DIR"
bash k8s/scripts/render-eks-overlay.sh --env "$ENV" --dns-dir "terraform/environments/$ENV/platform/infra"

echo "==> deploy workloads"
bash scripts/deploy-eks-apps.sh
EOS
)"

  # Edge last (depends on ingress-created ALB existing).
  tf_apply "$EDGE_DIR"

  echo "==> Deploy-all complete."
}

# Export variables used inside the heredoc executed on the bastion.
export ENV REGION AUTO_APPROVE BASTION_REPO_DIR

main "$@"
