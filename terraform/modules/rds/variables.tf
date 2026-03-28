variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID for the database security group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group."
  type        = list(string)
}

variable "allowed_sg_ids" {
  description = "Security group IDs allowed to access the DB."
  type        = list(string)
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "username" {
  description = "Master username."
  type        = string
}

variable "password" {
  description = "Master password."
  type        = string
  sensitive   = true
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
}

variable "allocated_storage" {
  description = "Allocated storage (GB)."
  type        = number
  default     = 50
}

variable "engine_version" {
  description = "PostgreSQL engine version."
  type        = string
  default     = "15.7"
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ."
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Whether the instance is publicly accessible."
  type        = bool
  default     = false
}

variable "storage_encrypted" {
  description = "Whether to enable storage encryption."
  type        = bool
  default     = true
}

variable "backup_retention_period" {
  description = "Backup retention (days)."
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Whether to skip final snapshot on destroy."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection."
  type        = bool
  default     = false
}
