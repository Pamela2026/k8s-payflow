variable "region" {
  description = "AWS region for the dev edge layer."
  type        = string
}

variable "environment" {
  description = "Environment name used for tagging and naming."
  type        = string
}

variable "project_name" {
  description = "Project name used for naming resources."
  type        = string
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "enable_cdn" {
  description = "Whether to enable CloudFront + Route53 for the app domain."
  type        = bool
  default     = false
}

variable "app_domain" {
  description = "Root application domain (e.g., computehub.online)."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the app domain."
  type        = string
  default     = null
}

variable "alb_dns_name" {
  description = "ALB DNS name to use as CloudFront origin."
  type        = string
  default     = null
}

variable "enable_waf" {
  description = "Whether to create a WAFv2 Web ACL for the ALB."
  type        = bool
  default     = false
}

variable "waf_rate_limit" {
  description = "Rate limit (requests per 5 minutes per IP)."
  type        = number
  default     = 2000
}

variable "waf_enable_common_rule_set" {
  description = "Enable AWSManagedRulesCommonRuleSet."
  type        = bool
  default     = true
}

variable "waf_enable_bad_inputs_rule_set" {
  description = "Enable AWSManagedRulesKnownBadInputsRuleSet."
  type        = bool
  default     = true
}

variable "waf_enable_sqli_rule_set" {
  description = "Enable AWSManagedRulesSQLiRuleSet."
  type        = bool
  default     = true
}

variable "waf_enable_rate_limit" {
  description = "Enable rate-based rule."
  type        = bool
  default     = true
}

variable "waf_common_rule_priority" {
  description = "Priority for CommonRuleSet."
  type        = number
  default     = 1
}

variable "waf_bad_inputs_rule_priority" {
  description = "Priority for KnownBadInputsRuleSet."
  type        = number
  default     = 2
}

variable "waf_sqli_rule_priority" {
  description = "Priority for SQLiRuleSet."
  type        = number
  default     = 3
}

variable "waf_rate_limit_priority" {
  description = "Priority for rate-limit rule."
  type        = number
  default     = 4
}