# ============================================
# VPC MODULE VARIABLES
# ============================================
# #### Inputs for hub and spoke networking, TGW, NAT, and endpoints. ####
# #### Keep CIDR and subnet lists aligned with azs. ####

variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "azs" {
  description = "Availability zones for subnets."
  type        = list(string)
}

variable "hub_vpc_cidr" {
  description = "CIDR block for the hub VPC."
  type        = string
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
  default     = []
}

variable "eks_cluster_name" {
  description = "EKS cluster name used for subnet tagging. Leave empty to skip EKS tags."
  type        = string
  default     = ""
}

variable "enable_tgw" {
  description = "Whether to create a Transit Gateway and attachments."
  type        = bool
  default     = true
}

variable "enable_spoke_nat_gateway" {
  description = "Whether to create a single NAT Gateway in the spoke VPC."
  type        = bool
  default     = true
}

variable "enable_multi_az_spoke_nat_gateway" {
  description = "Whether to create one NAT Gateway per AZ and route private subnets per AZ."
  type        = bool
  default     = false
}

variable "create_vpc_endpoints" {
  description = "Whether to create interface VPC endpoints in the spoke VPC."
  type        = bool
  default     = true
}

variable "create_s3_gateway_endpoint" {
  description = "Whether to create an S3 gateway endpoint in the spoke VPC."
  type        = bool
  default     = true
}

variable "interface_endpoint_services" {
  description = "Interface endpoint services to create in the spoke VPC."
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs", "kms"]
}
