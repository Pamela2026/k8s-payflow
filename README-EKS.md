# PayFlow EKS Deployment Guide

This guide covers the standard deployment flow for the `payflow-dev` EKS environment.

## Prerequisites

Install and verify:

- AWS CLI
- Terraform `>= 1.6`
- `kubectl`
- Helm
- Docker
- `jq`
- AWS Session Manager plugin

Verify tools:

```bash
aws --version
terraform --version
kubectl version --client
helm version
docker --version
jq --version
session-manager-plugin
```

## Architecture Summary

PayFlow is deployed as a hub-and-spoke AWS layout:

- Hub VPC: bastion and control-plane access
- Spoke VPC: ALB, EKS, and managed services
- Public path: `Route 53 -> CloudFront -> ALB -> EKS workloads`
- Private operator path: `SSM -> bastion -> Transit Gateway -> private EKS API`
- Data path: EKS workloads -> RDS / Redis / RabbitMQ / Secrets Manager

For architecture details, see `docs/ARCHITECTURE.md`.

## Terraform Layers

| Layer | Directory | Purpose |
|-------|-----------|---------|
| Bootstrap | `terraform/bootstrap` | S3 backend and DynamoDB state locking |
| Foundation | `terraform/environments/dev/foundation` | Hub/spoke VPCs, subnets, NAT, TGW, bastion, FinOps alerts |
| Platform Infra | `terraform/environments/dev/platform/infra` | EKS, ECR, WAF, ALB ACM certificate |
| Platform Addons | `terraform/environments/dev/platform/addons` | ALB controller, External Secrets, observability, autoscaling |
| Workloads | `terraform/environments/dev/workloads` | RDS, Redis, RabbitMQ, Secrets Manager |
| Edge | `terraform/environments/dev/edge` | CloudFront and Route 53 records |

## Required Environment Variables

Set these before applying the workloads layer or running the deployment script:

```bash
export TF_VAR_rds_password='<strong-password>'
export TF_VAR_mq_password='<strong-password>'
export TF_VAR_jwt_secret='<strong-secret>'
```

Optional:

```bash
export TF_VAR_slack_webhook_url='<https://hooks.slack.com/...>'
```

## Standard Deployment Order

### 1. Bootstrap

```bash
cd terraform/bootstrap
terraform init
terraform apply -var-file=terraform.tfvars
```

### 2. Foundation

```bash
cd ../environments/dev/foundation
terraform init
terraform apply -var-file=terraform.tfvars
```

This creates the hub/spoke network, Transit Gateway, bastion, and FinOps resources.

### 3. Connect to the Bastion with SSM

The EKS API is private-only, so the remaining infrastructure and app deployment steps should be run from the bastion.

Find the bastion:

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=*-bastion" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text
```

Start an SSM session:

```bash
INSTANCE_ID=<bastion-instance-id>
aws ssm start-session --target "$INSTANCE_ID" --region us-east-1
```

### 4. Platform Infrastructure

From the bastion:

```bash
cd /home/ssm-user/k8s-payflow/terraform/environments/dev/platform/infra
terraform init
terraform apply -var-file=terraform.tfvars
```

Then configure `kubectl`:

```bash
bash /home/ssm-user/k8s-payflow/terraform/environments/dev/platform/infra/scripts/kcfg.sh
kubectl get nodes
```

### 5. Platform Addons

```bash
cd /home/ssm-user/k8s-payflow/terraform/environments/dev/platform/addons
terraform init
terraform apply -var-file=terraform.tfvars
```

Deploy the controllers and operators before the application workloads. This ensures the ALB controller, External Secrets, Metrics Server, and autoscaling components exist before the app deployment depends on them.

### 6. Workloads

From the bastion:

```bash
cd /home/ssm-user/k8s-payflow/terraform/environments/dev/workloads
terraform init
terraform apply -var-file=terraform.tfvars
```

### 7. Build and Push Images

```bash
cd /home/ssm-user/k8s-payflow
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REGION=us-east-1
bash scripts/push-ecr-images.sh
```

### 8. Render Overlay Files

```bash
cd /home/ssm-user/k8s-payflow
bash k8s/scripts/render-eks-overlay.sh \
  --dns-dir terraform/environments/dev/platform/infra
```

This writes:

- `overlays/dev/alb-ingress.yaml`

Managed-service endpoints in `dev` come from AWS Secrets Manager through External Secrets and `overlays/dev/aws-managed-services-patch.yaml` rather than Kubernetes `ExternalName` services.

### 9. Deploy the Application Workloads

```bash
cd /home/ssm-user/k8s-payflow
bash scripts/deploy-eks-apps.sh
```

This step deploys the EKS workloads and ingress resources. It should happen after platform add-ons and after the Terraform-managed services are available.

### 10. Edge

Run this after the ALB exists:

```bash
cd /home/ssm-user/k8s-payflow/terraform/environments/dev/edge
terraform init
terraform apply -var-file=terraform.tfvars
```

Current intended state:

- CloudFront -> ALB over HTTPS
- CloudFront forwards the viewer `Host` header to the ALB origin

## Verification

From the bastion:

```bash
kubectl get nodes
kubectl get pods -n payflow
kubectl get ingress -n payflow
kubectl get externalsecrets -n payflow
```

Health checks:

```bash
curl -I https://computehub.online/health
kubectl get ingress payflow-alb -n payflow -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Notes:

- `https://computehub.online/health` is the preferred external health check once edge is deployed.
- Direct testing against the raw ALB hostname can be misleading because the ALB certificate is for the application domain, not the ALB DNS name.

## Completion Checklist

- Prerequisites installed: AWS CLI, Terraform, Docker, `kubectl`, SSM plugin
- `TF_VAR_rds_password`, `TF_VAR_mq_password`, `TF_VAR_jwt_secret` set
- Terraform applies completed in order: foundation, platform infra, platform addons, workloads, edge
- Bastion SSM access works and `kubectl get nodes` shows Ready nodes
- Images built and pushed to ECR
- Application workloads deployed successfully
- Health check passes at `https://computehub.online/health`
- Observability stack deployed if desired
- Destroy workflow tested when the environment is no longer needed
- Deliverables updated: architecture doc, README, operations runbook

## Destroy Order

Destroy in reverse order. Delete the Kubernetes application workloads before tearing down the Terraform layers so the ALB controller can clean up ingress-backed resources and avoid orphaned load balancer artifacts.

```bash
cd /home/ssm-user/k8s-payflow
kubectl delete -k overlays/dev

cd /home/ssm-user/k8s-payflow/terraform/environments/dev
cd edge && terraform destroy -var-file=terraform.tfvars && cd ..
cd workloads && terraform destroy -var-file=terraform.tfvars && cd ..
cd platform/addons && terraform destroy -var-file=terraform.tfvars && cd ../..
cd platform/infra && terraform destroy -var-file=terraform.tfvars && cd ../..
cd foundation && terraform destroy -var-file=terraform.tfvars
```

Bootstrap is to be destroyed last:

```bash
cd /home/ssm-user/k8s-payflow/terraform/bootstrap
terraform destroy -var-file=terraform.tfvars
```
