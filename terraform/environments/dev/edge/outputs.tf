output "waf_web_acl_arn" {
  description = "WAFv2 Web ACL ARN for the ALB (regional)."
  value       = module.waf.web_acl_arn
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = module.cdn.cloudfront_domain_name
}
