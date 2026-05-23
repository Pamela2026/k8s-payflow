variable "enabled" {
  description = "Whether to create a WAFv2 Web ACL for the ALB."
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "rate_limit" {
  description = "Rate limit (requests per 5 minutes per IP)."
  type        = number
  default     = 2000
}

variable "enable_common_rule_set" {
  description = "Enable AWSManagedRulesCommonRuleSet."
  type        = bool
  default     = true
}

variable "enable_bad_inputs_rule_set" {
  description = "Enable AWSManagedRulesKnownBadInputsRuleSet."
  type        = bool
  default     = true
}

variable "enable_sqli_rule_set" {
  description = "Enable AWSManagedRulesSQLiRuleSet."
  type        = bool
  default     = true
}

variable "enable_rate_limit" {
  description = "Enable rate-based rule."
  type        = bool
  default     = true
}

variable "common_rule_priority" {
  description = "Priority for CommonRuleSet."
  type        = number
  default     = 1
}

variable "bad_inputs_rule_priority" {
  description = "Priority for KnownBadInputsRuleSet."
  type        = number
  default     = 2
}

variable "sqli_rule_priority" {
  description = "Priority for SQLiRuleSet."
  type        = number
  default     = 3
}

variable "rate_limit_priority" {
  description = "Priority for rate-limit rule."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}

variable "scope" {
  description = "Scope of the WAF (REGIONAL or CLOUDFRONT)."
  type        = string
  default     = "CLOUDFRONT"
}
