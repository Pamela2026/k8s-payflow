# ============================================
# FOUNDATION VARIABLES (DEV)
# ============================================
# #### Inputs for hub and spoke VPCs in the dev environment. ####

variable "region" {
  description = "AWS region for the dev foundation layer."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used for tagging and naming."
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name used for naming resources."
  type        = string
  default     = "payflow"
}

variable "azs" {
  description = "Availability zones to use. Set explicitly for stability."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "hub_vpc_cidr" {
  description = "CIDR block for the hub VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "hub_public_subnet_cidrs" {
  description = "Public subnet CIDRs for the hub VPC."
  type        = list(string)
}

variable "hub_private_subnet_cidrs" {
  description = "Private subnet CIDRs for the hub VPC."
  type        = list(string)
}

variable "spoke_vpc_cidr" {
  description = "CIDR block for the spoke VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "spoke_public_subnet_cidrs" {
  description = "Public subnet CIDRs for the spoke VPC."
  type        = list(string)
}

variable "spoke_private_subnet_cidrs" {
  description = "Private subnet CIDRs for the spoke VPC."
  type        = list(string)
}

variable "spoke_data_private_subnet_cidrs" {
  description = "Data-only private subnet CIDRs for the spoke VPC."
  type        = list(string)
}

variable "eks_cluster_name" {
  description = "EKS cluster name used for subnet tagging."
  type        = string
  default     = "payflow-eks-cluster"
}

variable "enable_tgw" {
  description = "Whether to create a Transit Gateway for hub and spoke."
  type        = bool
  default     = true
}

variable "enable_spoke_nat_gateway" {
  description = "Whether to create a NAT Gateway in the spoke VPC."
  type        = bool
  default     = true
}

variable "enable_multi_az_spoke_nat_gateway" {
  description = "Whether to create one NAT Gateway per AZ and route private subnets per AZ."
  type        = bool
  default     = false
}

variable "create_vpc_endpoints" {
  description = "Whether to create interface endpoints in the spoke VPC."
  type        = bool
  default     = true
}

variable "create_s3_gateway_endpoint" {
  description = "Whether to create an S3 gateway endpoint in the spoke VPC."
  type        = bool
  default     = true
}

variable "interface_endpoint_services" {
  description = "Interface endpoint services to create."
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs", "kms"]
}

variable "enable_bastion" {
  description = "Whether to create the bastion instance."
  type        = bool
  default     = true
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion."
  type        = string
  default     = "t3.micro"
}

variable "bastion_ssh_cidr_blocks" {
  description = "Optional CIDR blocks allowed to SSH to the bastion. Empty means SSM-only."
  type        = list(string)
  default     = []
}

variable "bastion_key_name" {
  description = "Optional EC2 key pair name for the bastion."
  type        = string
  default     = null
}

variable "bastion_ami_id" {
  description = "Optional AMI ID for the bastion. If null, Amazon Linux 2023 is used."
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
