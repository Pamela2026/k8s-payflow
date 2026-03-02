# Payflow Hub-and-Spoke EKS (Terraform)

This stack provisions:

- Hub VPC (shared network zone)
- Spoke VPC (EKS workload network)
- Transit Gateway + VPC attachments + routes
- EKS cluster in the spoke private subnets

## Quick Start

```bash
cd terraform/hub-spoke-eks
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

## Topology

- Hub VPC CIDR: `var.hub_vpc_cidr`
- Spoke VPC CIDR: `var.spoke_vpc_cidr`
- TGW routes:
  - Hub private route tables -> Spoke CIDR
  - Spoke private route tables -> Hub CIDR

## Notes

- Subnets in the spoke VPC are tagged for EKS load balancers.
- EKS API endpoint is private by default (`cluster_endpoint_public_access = false`).
- This is a starter baseline. For production, add:
  - Remote state backend + state locking
  - Separate workspaces/environments
  - IRSA roles and least-privilege IAM policies
  - VPC flow logs, CloudTrail, and centralized logging
  - Managed node group hardening and KMS controls
