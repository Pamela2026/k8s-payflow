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

output "vpc_id" {
  description = "VPC ID for the EKS cluster."
  value       = data.terraform_remote_state.foundation.outputs.spoke_vpc_id
}

output "node_security_group_id" {
  description = "EKS worker nodes security group ID."
  value       = module.eks.node_security_group_id
}

# Edge / Route 53 outputs are intentionally disabled in the current setup.
# Re-enable if you own a domain.
#
# output "alb_certificate_arn" {
#   description = "ACM certificate ARN for the ALB."
#   value       = module.route53.alb_certificate_arn
# }
#
# output "alb_acm_certificate_arn" {
#   description = "Alias for alb_certificate_arn (used by overlay render scripts)."
#   value       = module.route53.alb_acm_certificate_arn
# }
#
# output "acm_certificate_arn" {
#   description = "Alias for alb_certificate_arn (used by overlay render scripts)."
#   value       = module.route53.acm_certificate_arn
# }
#
# output "alb_origin_security_group_id" {
#   description = "Security group ID that allows CloudFront origin-facing traffic to the ALB."
#   value       = module.route53.alb_origin_security_group_id
# }

output "app_domain" {
  description = "Primary application domain used in the ALB ingress host rules."
  value       = var.alb_cert_domain
}

output "api_domain" {
  description = "API domain used in the ALB ingress host rules."
  value       = var.alb_cert_domain != null ? "api.${var.alb_cert_domain}" : null
}

output "rds_endpoint" {
  description = "RDS endpoint."
  value       = module.rds.endpoint
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint."
  value       = module.redis.primary_endpoint
}

output "rabbitmq_endpoint" {
  description = "RabbitMQ endpoint."
  value       = module.rabbitmq.endpoint
}

# output "rabbitmq_hostname" {
#   value = replace(
#     replace(aws_mq_broker.main.instances[0].endpoints[0], "amqps://", ""),
#     ":5671",
#     ""
#   )
# }
output "db_secret_arn" {
  description = "DB Secrets Manager ARN."
  value       = module.secrets.db_secret_arn
}

output "mq_secret_arn" {
  description = "MQ Secrets Manager ARN."
  value       = module.secrets.mq_secret_arn
}

output "jwt_secret_arn" {
  description = "JWT Secrets Manager ARN."
  value       = module.secrets.jwt_secret_arn
}

output "slack_webhook_secret_arn" {
  description = "Alertmanager Slack webhook secret ARN (optional)."
  value       = module.secrets.slack_webhook_secret_arn
}
