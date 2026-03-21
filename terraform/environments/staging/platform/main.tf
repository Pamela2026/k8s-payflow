# ============================================
# PLATFORM (STAGING)
# ============================================
# #### Creates private EKS cluster and core add-ons. ####
# #### Depends on staging foundation outputs. ####

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    # Platform layer depends on foundation layer outputs (networking + bastion).
    bucket         = "payflow-tfstate-003"
    key            = "staging/foundation/terraform.tfstate"
    region         = var.region
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}

module "eks" {
  source = "../../../modules/eks"

  name_prefix    = local.name_prefix
  tags           = local.tags
  region         = var.region
  cluster_name   = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id              = data.terraform_remote_state.foundation.outputs.spoke_vpc_id
  private_subnet_ids  = data.terraform_remote_state.foundation.outputs.spoke_private_subnet_ids
  public_subnet_ids   = data.terraform_remote_state.foundation.outputs.spoke_public_subnet_ids
  bastion_role_arn    = data.terraform_remote_state.foundation.outputs.bastion_role_arn
  terraform_user_arn  = var.terraform_user_arn
  # Dependency mapping:
  # - vpc_id -> foundation.spoke_vpc_id
  # - private_subnet_ids -> foundation.spoke_private_subnet_ids
  # - public_subnet_ids -> foundation.spoke_public_subnet_ids
  # - bastion_role_arn -> foundation.bastion_role_arn
  # - terraform_user_arn -> platform.terraform_user_arn

  endpoint_private_access = var.endpoint_private_access
  endpoint_public_access  = var.endpoint_public_access

  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size
  enable_helm_releases = var.enable_helm_releases
}
