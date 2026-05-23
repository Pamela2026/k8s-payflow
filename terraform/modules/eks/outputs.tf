output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_ca" {
  description = "EKS cluster CA data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA."
  value       = aws_iam_openid_connect_provider.oidc.arn
}

output "alb_controller_role_arn" {
  description = "ALB controller IAM role ARN."
  value       = aws_iam_role.alb_controller.arn
}

output "external_secrets_role_arn" {
  description = "External Secrets IAM role ARN."
  value       = aws_iam_role.external_secrets.arn
}

output "cluster_autoscaler_role_arn" {
  description = "Cluster Autoscaler IAM role ARN."
  value       = aws_iam_role.cluster_autoscaler.arn
}

output "node_security_group_id" {
  description = "Security group ID for EKS worker nodes."
  value       = aws_security_group.nodes.id
}
