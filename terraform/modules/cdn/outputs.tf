output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = var.enabled && var.app_domain != null ? aws_cloudfront_distribution.app[0].domain_name : null
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID."
  value       = var.enabled && var.app_domain != null ? aws_cloudfront_distribution.app[0].hosted_zone_id : null
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN used for the distribution."
  value       = var.enabled && var.app_domain != null ? aws_acm_certificate.app[0].arn : null
}
