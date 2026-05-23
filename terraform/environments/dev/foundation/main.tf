# ============================================
# FOUNDATION (DEV)
# ============================================
# #### Wires the VPC module for hub and spoke networking. ####
# #### Depends on terraform/bootstrap backend being created. ####
# #### Run before platform and workloads in dev. ####

## Available AZs used when var.azs is empty. ##
## Depends on: none. ##
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source = "../../../modules/vpc"

  name_prefix = local.name_prefix
  tags        = local.tags
  azs         = local.azs

  hub_vpc_cidr             = var.hub_vpc_cidr
  hub_public_subnet_cidrs  = var.hub_public_subnet_cidrs
  hub_private_subnet_cidrs = var.hub_private_subnet_cidrs

  spoke_vpc_cidr                  = var.spoke_vpc_cidr
  spoke_public_subnet_cidrs       = var.spoke_public_subnet_cidrs
  spoke_private_subnet_cidrs      = var.spoke_private_subnet_cidrs
  spoke_data_private_subnet_cidrs = var.spoke_data_private_subnet_cidrs


  eks_cluster_name                  = var.eks_cluster_name
  enable_tgw                        = var.enable_tgw
  enable_spoke_nat_gateway          = var.enable_spoke_nat_gateway
  enable_multi_az_spoke_nat_gateway = var.enable_multi_az_spoke_nat_gateway
  create_vpc_endpoints              = var.create_vpc_endpoints
  create_s3_gateway_endpoint        = var.create_s3_gateway_endpoint
  interface_endpoint_services       = var.interface_endpoint_services
}

module "bastion" {
  source = "../../../modules/bastion"

  name_prefix      = local.name_prefix
  tags             = local.tags
  region           = var.region
  eks_cluster_name = var.eks_cluster_name

  vpc_id    = module.vpc.hub_vpc_id
  subnet_id = module.vpc.hub_public_subnet_ids[0]

  enable_bastion          = var.enable_bastion
  instance_type           = var.bastion_instance_type
  ssh_cidr_blocks         = var.bastion_ssh_cidr_blocks
  key_name                = var.bastion_key_name
  ami_id                  = var.bastion_ami_id
  tfstate_bucket_name     = var.tfstate_bucket_name
  tfstate_lock_table_name = var.tfstate_lock_table_name
}

moved {
  from = module.cost_ops
  to   = module.fin_ops
}

module "ecr" {
  source = "../../../modules/ecr"

  repositories = var.ecr_repositories
  tags         = local.tags
}

module "fin_ops" {
  source = "../../../modules/fin_ops"

  name_prefix = local.name_prefix
  tags        = local.tags

  enable_fin_ops          = var.enable_fin_ops
  budget_amount           = var.fin_ops_budget_amount
  budget_unit             = var.fin_ops_budget_unit
  budget_email_addresses  = var.fin_ops_email_addresses
  anomaly_threshold       = var.fin_ops_anomaly_threshold
  anomaly_frequency       = var.fin_ops_anomaly_frequency
  anomaly_email_addresses = var.fin_ops_email_addresses
}
