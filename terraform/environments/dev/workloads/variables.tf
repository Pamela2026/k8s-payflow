variable "region" {
  description = "AWS region for the dev workloads layer."
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

variable "admin_role_arn" {
  description = "Optional role ARN to assume for admin permissions."
  type        = string
  default     = null
}

## RDS ##
variable "rds_db_name" {
  description = "RDS database name."
  type        = string
}

variable "rds_username" {
  description = "RDS master username."
  type        = string
}

variable "rds_password" {
  description = "RDS master password."
  type        = string
  sensitive   = true
}

variable "rds_instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "rds_backup_retention_period" {
  description = "RDS backup retention period (days)."
  type        = number
  default     = 7
}

## Redis ##
variable "redis_node_type" {
  description = "ElastiCache node type."
  type        = string
}

## RabbitMQ ##
variable "mq_username" {
  description = "RabbitMQ username."
  type        = string
}

variable "mq_password" {
  description = "RabbitMQ password."
  type        = string
  sensitive   = true
}

variable "mq_host_instance_type" {
  description = "RabbitMQ broker instance type."
  type        = string
}

variable "mq_engine_version" {
  description = "RabbitMQ engine version."
  type        = string
  default     = "3.13"
}

## Secrets ##
variable "jwt_secret" {
  description = "JWT signing secret."
  type        = string
  sensitive   = true
}
