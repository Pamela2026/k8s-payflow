# ============================================
# PLATFORM ADDONS (PROD)
# ============================================
# #### Deploys Helm add-ons into EKS. ####
# #### Depends on prod platform-infra outputs. ####

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket         = "payflow-tfstate-003"
    key            = "prod/platform/terraform.tfstate"
    region         = var.region
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}

module "eks_addons" {
  source = "../../../modules/eks_addons"

  cluster_name                 = data.terraform_remote_state.platform.outputs.cluster_name
  region                       = var.region
  vpc_id                       = data.terraform_remote_state.platform.outputs.vpc_id
  alb_controller_role_arn      = data.terraform_remote_state.platform.outputs.alb_controller_role_arn
  external_secrets_role_arn    = data.terraform_remote_state.platform.outputs.external_secrets_role_arn
  cluster_autoscaler_role_arn  = data.terraform_remote_state.platform.outputs.cluster_autoscaler_role_arn
}
