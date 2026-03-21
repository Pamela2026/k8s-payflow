output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN."
  value       = module.eks.oidc_provider_arn
}

output "alb_controller_role_arn" {
  description = "ALB controller IAM role ARN."
  value       = module.eks.alb_controller_role_arn
}

output "external_secrets_role_arn" {
  description = "External Secrets IAM role ARN."
  value       = module.eks.external_secrets_role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IAM role ARN."
  value       = module.eks.cluster_autoscaler_role_arn
}

output "node_security_group_id" {
  description = "EKS worker nodes security group ID."
  value       = module.eks.node_security_group_id
}
