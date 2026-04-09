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
