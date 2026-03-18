variable "region" {
  description = "AWS region for the staging platform layer."
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
