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
  description = "VPC ID for the cache security group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the cache subnet group."
  type        = list(string)
}

variable "allowed_sg_ids" {
  description = "Security group IDs allowed to access the cache."
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type."
  type        = string
}

variable "engine_version" {
  description = "Redis engine version."
  type        = string
  default     = "7.1"
}

variable "num_cache_clusters" {
  description = "Number of cache nodes."
  type        = number
  default     = 1
}

variable "port" {
  description = "Redis port."
  type        = number
  default     = 6379
}
