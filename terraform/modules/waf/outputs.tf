output "web_acl_arn" {
  description = "WAFv2 Web ACL ARN."
  value       = var.enabled ? aws_wafv2_web_acl.this[0].arn : null
}
