variable "project_name" {
  description = "Project identifier used in naming and tagging."
  type        = string
  default     = "payflow"
}

variable "environment" {
  description = "Environment name (for example: dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "az_count" {
  description = "Number of availability zones to use."
  type        = number
  default     = 2
}

variable "hub_vpc_cidr" {
  description = "CIDR block for hub VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_vpc_cidr" {
  description = "CIDR block for spoke VPC where EKS runs."
  type        = string
  default     = "10.10.0.0/16"
}

variable "transit_gateway_asn" {
  description = "Private ASN for AWS Transit Gateway."
  type        = number
  default     = 64512
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "payflow-eks-dev"
}

variable "cluster_version" {
  description = "EKS Kubernetes version."
  type        = string
  default     = "1.30"
}

variable "cluster_endpoint_public_access" {
  description = "Whether EKS API endpoint should be publicly accessible."
  type        = bool
  default     = false
}

variable "node_instance_types" {
  description = "Instance types for EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_group_min_size" {
  description = "Minimum node count for the default node group."
  type        = number
  default     = 1
}

variable "node_group_desired_size" {
  description = "Desired node count for the default node group."
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum node count for the default node group."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
