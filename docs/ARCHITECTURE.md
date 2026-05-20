# PayFlow Architecture Overview

> Environment: `payflow-dev`
> Region: `us-east-1`
> Source of truth: Terraform under `terraform/environments/dev`

## Topology

PayFlow is deployed as a hub-and-spoke AWS layout:

- Hub VPC: `10.0.0.0/16`
- Spoke VPC: `10.1.0.0/16`
- Connectivity: AWS Transit Gateway
- Active user path: public ALB -> EKS workloads
- Edge path (commented config): Route 53 -> CloudFront -> ALB -> EKS workloads
- Control path: engineer -> SSM -> bastion -> private EKS API / Terraform assume-role

For comparison, see `diagrams/Payflow-architecture.pdf`

## Network Layout

### Hub VPC

- Purpose: access and control plane entry point
- CIDR: `10.0.0.0/16`
- Public subnets: `10.0.10.0/24`, `10.0.20.0/24`, `10.0.30.0/24`
- Private subnets: `10.0.110.0/24`, `10.0.120.0/24`, `10.0.130.0/24`
- Bastion: `t3.micro`, SSM-enabled, deployed in the hub VPC public subnet tier

### Spoke VPC

- Purpose: application runtime and managed services
- CIDR: `10.1.0.0/16`
- Public subnets: `10.1.10.0/24`, `10.1.20.0/24`, `10.1.30.0/24`
- Private subnets: `10.1.110.0/24`, `10.1.120.0/24`, `10.1.130.0/24`
- Data private subnets: `10.1.210.0/24`, `10.1.220.0/24`, `10.1.230.0/24`
- NAT: one NAT gateway per AZ for private-subnet egress and improved AZ fault tolerance
- VPC endpoints: `ecr.api`, `ecr.dkr`, `sts`, `secretsmanager`, `logs`, `kms`, plus an S3 gateway endpoint

### Transit

- Hub and spoke VPCs are attached to a single Transit Gateway
- Terraform adds routes in both directions so the hub bastion can reach the private EKS API and spoke resources

## Platform Layer

### EKS

- Cluster name: `payflow-eks-dev`
- Kubernetes version: `1.33`
- Endpoint access: private only
- Public endpoint: disabled
- Nodes run in spoke private subnets
- Public spoke subnets are tagged for internet-facing load balancers

### Access Model

- Bastion uses SSM rather than SSH as the intended operator access path
- Bastion role is granted EKS access
- Terraform also uses `arn:aws:iam::725094769583:role/for-payflow-terraform` for EKS access and AWS changes

### Edge and Ingress

- The current setup does not deploy the public edge layer.
- The app is reached directly through the public ALB DNS name.
- Route 53 / CloudFront / edge ACM wiring is kept in the repo as commented configuration, re-enable if you have a domain.
- The ALB is internet-facing and spans the spoke public subnets.
- Ingress is managed by Helm/GitOps, not by Terraform-rendered manifest generation.

## Kubernetes Workloads Layer

Managed services are deployed into the spoke data private subnets and allow inbound traffic only from the EKS node security group.

In `dev`, application workloads consume managed-service endpoints from AWS Secrets Manager via External Secrets and overlay patches. This avoids TLS hostname issues that can occur when certificate-bound services such as Amazon MQ are accessed through Kubernetes `ExternalName` aliases.

### Current service shape

- RDS PostgreSQL: single instance, not Multi-AZ
- ElastiCache Redis: replication group with `num_cache_clusters = 1`
- Amazon MQ RabbitMQ: `SINGLE_INSTANCE`
- Secrets Manager: stores DB, MQ, JWT, and optional Slack secrets

This means the current `dev` Terraform implementation is not yet a highly available data plane (it prioritizes simplicity and cost).

## Add-ons

The platform add-ons layer deploys:

- AWS Load Balancer Controller
- External Secrets
- Cluster Autoscaler
- Metrics Server
- Prometheus
- Grafana
- Loki
- Promtail
- Postgres exporter
- Kubecost

## Traffic Flows

### User traffic

1. User resolves the public ALB DNS name directly.
2. The ALB applies ingress rules and routes `/` to `frontend` and `/api` to `api-gateway`.
3. The ALB targets workload IPs in EKS.
4. Workloads in EKS access RDS, Redis, RabbitMQ, and Secrets Manager inside the spoke VPC.

### Operator and deploy traffic

1. Engineer authenticates into AWS and reaches the bastion with SSM.
2. Bastion reaches the private EKS API over Transit Gateway.
3. Terraform assumes the environment-specific GitHub OIDC role for infrastructure changes.
4. Foundation and platform/infra are applied through GitHub Actions with environment-gated AWS roles.
5. Platform add-ons are verified through the bastion/SSM path when needed for private EKS access.
6. Kubernetes workloads are reconciled from Git using GitOps rather than pushed imperatively from a local deploy script.

## Security Notes

- EKS API is private-only
- Bastion is SSM-based
- Managed services are not publicly accessible
- ALB is internet-facing
- The public ALB is the entry point
- Secrets are injected from AWS Secrets Manager rather than committed in manifests
- Local deployment helpers are intentionally limited to bootstrap and teardown; the archived imperative scripts are no longer the active path.

## Canonical Files

- Network foundation: `terraform/environments/dev/foundation/terraform.tfvars`
- Platform infra: `terraform/environments/dev/platform/infra/main.tf`
- Platform vars: `terraform/environments/dev/platform/infra/terraform.tfvars`
- Managed services (RDS/Redis/MQ/Secrets): `terraform/environments/dev/platform/infra/aws-managed-databases.tf`
- Edge: `terraform/environments/dev/edge/main.tf` (commented future config)
- Diagram source: `diagrams/Payflow-architecture.pdf`
