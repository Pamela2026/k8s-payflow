output "alb_certificate_arn" {
  description = "ACM certificate ARN for the ALB."
  value       = var.enable_alb_cert && var.alb_cert_domain != null ? aws_acm_certificate.alb[0].arn : null
}

output "alb_acm_certificate_arn" {
  description = "Alias for alb_certificate_arn (used by overlay render scripts)."
  value       = try(aws_acm_certificate.alb[0].arn, null)
}

output "acm_certificate_arn" {
  description = "Alias for alb_certificate_arn (used by overlay render scripts)."
  value       = try(aws_acm_certificate.alb[0].arn, null)
}

output "app_domain" {
  description = "Primary application domain used in the ALB ingress host rules."
  value       = var.alb_cert_domain
}

output "api_domain" {
  description = "API domain used in the ALB ingress host rules."
  value       = var.alb_cert_domain != null ? "api.${var.alb_cert_domain}" : null
}

output "alb_origin_security_group_id" {
  description = "Security group ID that allows CloudFront origin-facing traffic to the ALB."
  value       = var.vpc_id != null ? aws_security_group.alb_origin[0].id : null
}
