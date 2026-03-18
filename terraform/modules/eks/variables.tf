variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "AWS region for the EKS cluster."
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

variable "vpc_id" {
  description = "VPC ID for the EKS cluster."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS nodes."
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for load balancers."
  type        = list(string)
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

variable "node_instance_types" {
  description = "Instance types for managed node group."
  type        = list(string)
  default     = ["t3.large"]
}

variable "node_min_size" {
  description = "Minimum node count."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum node count."
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Desired node count."
  type        = number
  default     = 2
}
