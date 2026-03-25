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
  description = "AWS region for the bastion."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the bastion will be created."
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for the bastion instance."
  type        = string
}

variable "enable_bastion" {
  description = "Whether to create the bastion instance."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type for the bastion."
  type        = string
  default     = "t3.micro"
}

variable "ssh_cidr_blocks" {
  description = "Optional CIDR blocks allowed to SSH to the bastion. Empty means SSM-only."
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH."
  type        = string
  default     = null
}

variable "ami_id" {
  description = "Optional AMI ID. If null, Amazon Linux 2023 is used."
  type        = string
  default     = null
}

variable "eks_cluster_name" {
  description = "Optional EKS cluster name for kubeconfig auto-setup on bastion."
  type        = string
  default     = null
}

variable "tfstate_bucket_name" {
  description = "Optional Terraform state bucket name for bastion policy scoping."
  type        = string
  default     = null
}

variable "tfstate_lock_table_name" {
  description = "Optional Terraform state lock table name for bastion policy scoping."
  type        = string
  default     = null
}
