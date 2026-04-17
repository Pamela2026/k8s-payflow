# PayFlow Architecture Overview

> Environment: `payflow-dev`
> Region: `us-east-1`
> Source of truth: Terraform under `terraform/environments/dev`

## Topology

PayFlow is deployed as a hub-and-spoke AWS layout:

- Hub VPC: `10.0.0.0/16`
- Spoke VPC: `10.1.0.0/16`
- Connectivity: AWS Transit Gateway
- Edge path: Route 53 -> CloudFront -> ALB -> EKS workloads
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

- Route 53 hosts `computehub.online`
- CloudFront is enabled and fronts the public ALB DNS name
- CloudFront has its own ACM certificate in `us-east-1`
- The ALB certificate is provisioned separately in the platform layer
- CloudFront forwards the viewer `Host` header to the ALB origin
- CloudFront is configured to talk to the ALB origin over HTTPS
- WAF is created in Terraform and attached to the ALB ingress via the `alb.ingress.kubernetes.io/wafv2-acl-arn` annotation
- The ALB is internet-facing and spans the spoke public subnets

## Workloads Layer

Managed services are deployed into the spoke data private subnets and allow inbound traffic only from the EKS node security group.

In `dev`, application workloads consume managed-service endpoints from AWS Secrets Manager via External Secrets and overlay patches. This avoids TLS hostname issues that can occur when certificate-bound services such as Amazon MQ are accessed through Kubernetes `ExternalName` aliases.

### Current service shape

- RDS PostgreSQL: single instance, not Multi-AZ
- ElastiCache Redis: replication group with `num_cache_clusters = 1`
- Amazon MQ RabbitMQ: `SINGLE_INSTANCE`
- Secrets Manager: stores DB, MQ, JWT, and optional Slack secrets

This means the Terraform implementation is not yet a highly available data plane. The AWS Account being used does not allow Multi-AZ failovers, but since it Dev Environment it's not a cause for alarm.

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

1. User resolves `computehub.online` in Route 53.
2. Route 53 aliases the domain to CloudFront.
3. CloudFront forwards requests to the ALB origin over HTTPS.
4. The ALB applies WAF and ingress rules and routes `/` to `frontend` and `/api` to `api-gateway`.
5. The ALB targets workload IPs in EKS.
6. Workloads in EKS access RDS, Redis, RabbitMQ, and Secrets Manager inside the spoke VPC.

### Operator and deploy traffic

1. Engineer authenticates into AWS and reaches the bastion with SSM.
2. Bastion reaches the private EKS API over Transit Gateway.
3. Terraform assumes `for-payflow-terraform` for infrastructure changes.
4. Platform add-ons and workloads are applied after foundation and platform infrastructure are ready.

## Security Notes

- EKS API is private-only
- Bastion is SSM-based
- Managed services are not publicly accessible
- ALB is internet-facing
- CloudFront is public edge entry
- WAF is regional on the ALB path
- CloudFront to ALB origin traffic is HTTPS
- Secrets are injected from AWS Secrets Manager rather than committed in manifests

## Canonical Files

- Network foundation: `terraform/environments/dev/foundation/terraform.tfvars`
- Platform infra: `terraform/environments/dev/platform/infra/main.tf`
- Platform vars: `terraform/environments/dev/platform/infra/terraform.tfvars`
- Workloads: `terraform/environments/dev/workloads/main.tf`
- Edge: `terraform/environments/dev/edge/main.tf`
- Diagram source: `diagrams/Payflow-architecture.pdf`
