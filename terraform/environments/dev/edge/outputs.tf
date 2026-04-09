output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.cdn.cloudfront_domain_name
}

output "acm_certificate_arn" {
  description = "ACM certificate ARN used for CloudFront (us-east-1)."
  value       = module.cdn.acm_certificate_arn
}
