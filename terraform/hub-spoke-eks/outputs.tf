output "hub_vpc_id" {
  description = "Hub VPC ID."
  value       = module.hub_vpc.vpc_id
}

output "spoke_vpc_id" {
  description = "Spoke VPC ID where EKS is deployed."
  value       = module.spoke_vpc.vpc_id
}

output "transit_gateway_id" {
  description = "Transit Gateway ID connecting hub and spoke VPCs."
  value       = aws_ec2_transit_gateway.this.id
}

output "eks_cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.eks.cluster_endpoint
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA integrations."
  value       = module.eks.oidc_provider_arn
}
