variable "region" {
  description = "AWS region for the dev platform layer."
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

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
}

variable "node_instance_types" {
  description = "Instance types for managed node group."
  type        = list(string)
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
}

variable "node_desired_size" {
  description = "Desired node count."
  type        = number
}

variable "endpoint_private_access" {
  description = "Whether the EKS endpoint is private."
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the EKS endpoint is public."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "admin_role_arn" {
  description = "Optional role ARN to assume for admin permissions."
  type        = string
  default     = null
}

variable "terraform_user_arn" {
  description = "IAM user ARN for Terraform runner; granted EKS access."
  type        = string
  default     = null
}

variable "bastion_vpc_cidr" {
  description = "CIDR of the bastion VPC allowed to reach EKS API on port 443."
  type        = string
  default     = null
}

variable "ecr_repositories" {
  description = "ECR repositories to create for Payflow services."
  type        = list(string)
  default     = []
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

variable "enable_alb_cert" {
  description = "Whether to request an ACM cert for the ALB."
  type        = bool
  default     = false
}

variable "alb_cert_domain" {
  description = "Domain name for the ALB certificate."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the ALB certificate domain."
  type        = string
  default     = null
}
