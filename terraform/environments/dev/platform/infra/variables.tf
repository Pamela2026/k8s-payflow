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

variable "slack_webhook_url" {
  description = "Slack webhook URL stored in Secrets Manager for Alertmanager."
  type        = string
  sensitive   = true
  default     = null
}
