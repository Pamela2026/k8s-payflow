# ============================================
# FOUNDATION (PROD)
# ============================================
# #### Wires the VPC module for hub and spoke networking. ####
# #### Depends on terraform/bootstrap backend being created. ####
# #### Run before platform and workloads in prod. ####

module "vpc" {
  source = "../../../modules/vpc"

  name_prefix = local.name_prefix
  tags        = local.tags
  azs         = var.azs

  hub_vpc_cidr             = var.hub_vpc_cidr
  hub_public_subnet_cidrs  = var.hub_public_subnet_cidrs
  hub_private_subnet_cidrs = var.hub_private_subnet_cidrs

  spoke_vpc_cidr                  = var.spoke_vpc_cidr
  spoke_public_subnet_cidrs       = var.spoke_public_subnet_cidrs
  spoke_private_subnet_cidrs      = var.spoke_private_subnet_cidrs
  spoke_data_private_subnet_cidrs = var.spoke_data_private_subnet_cidrs

  eks_cluster_name            = var.eks_cluster_name
  enable_tgw                  = var.enable_tgw
  enable_spoke_nat_gateway    = var.enable_spoke_nat_gateway
  create_vpc_endpoints        = var.create_vpc_endpoints
  create_s3_gateway_endpoint  = var.create_s3_gateway_endpoint
  interface_endpoint_services = var.interface_endpoint_services
}

module "bastion" {
  source = "../../../modules/bastion"

  name_prefix      = local.name_prefix
  tags             = local.tags
  region           = var.region
  eks_cluster_name = var.eks_cluster_name

  vpc_id    = module.vpc.hub_vpc_id
  subnet_id = module.vpc.hub_public_subnet_ids[0]

  enable_bastion  = var.enable_bastion
  instance_type   = var.bastion_instance_type
  ssh_cidr_blocks = var.bastion_ssh_cidr_blocks
  key_name        = var.bastion_key_name
  ami_id          = var.bastion_ami_id
}

module "ecr" {
  source = "../../../modules/ecr"

  repositories = var.ecr_repositories
  tags         = local.tags
}
