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
PLATFORM_ADDONS_DIR="$ROOT_DIR/terraform/environments/$ENV/platform/addons"
EDGE_DIR="$ROOT_DIR/terraform/environments/$ENV/edge"

print_next_steps() {
  cat <<EOF

==> Next steps (run from bastion via SSM)

1) Start an SSM session to the bastion (example):
   aws ec2 describe-instances --filters "Name=tag:Name,Values=*-bastion" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].InstanceId' --output text
   aws ssm start-session --target <bastion-instance-id> --region ${REGION}

2) On the bastion (repo checkout assumed at /home/ssm-user/k8s-payflow):
   cd /home/ssm-user/k8s-payflow/terraform/environments/${ENV}/platform/addons
   terraform init
   terraform apply -var-file=terraform.tfvars

3) Configure kubectl (on the bastion):
   bash /home/ssm-user/k8s-payflow/terraform/environments/${ENV}/platform/infra/scripts/kcfg.sh
   kubectl get nodes

4) Deploy workloads (on the bastion):
   cd /home/ssm-user/k8s-payflow
   bash k8s/scripts/render-eks-overlay.sh --dns-dir terraform/environments/${ENV}/platform/infra
   bash scripts/deploy-eks-apps.sh

==> Edge (run LAST, after the ALB exists)

CloudFront/Route53 depend on the ALB being created by the ingress controller.
Run from your local machine:
   cd ${EDGE_DIR}
   terraform init
   terraform apply -var-file=terraform.tfvars

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

if [[ -z "$RDS_PASSWORD" || -z "$JWT_SECRET" || -z "$MQ_PASSWORD" ]]; then
  echo "Missing required env vars. Set TF_VAR_rds_password, TF_VAR_jwt_secret, TF_VAR_mq_password" >&2
  exit 1
fi

cat <<EOF

==> Local Terraform complete for:
- foundation
- platform/infra

Stopping here by design.
- platform/addons uses Kubernetes/Helm providers against a private EKS API and should be applied from the bastion.
- edge should be applied last, after the ALB exists (created by the ingress controller).

EOF

print_next_steps
