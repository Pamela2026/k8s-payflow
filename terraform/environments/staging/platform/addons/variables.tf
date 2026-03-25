variable "region" {
  description = "AWS region for the staging platform add-ons layer."
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

variable "admin_role_arn" {
  description = "Optional role ARN to assume for admin permissions."
  type        = string
  default     = null
}
