# ============================================
# WORKLOADS (DEV)
# ============================================
# #### Managed services in data private subnets. ####
# #### Depends on foundation and platform outputs. ####

data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket         = "payflow-tfstate-003"
    key            = "dev/foundation/terraform.tfstate"
    region         = var.region
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}

# data "terraform_remote_state" "platform" {
#   backend = "local"
#   config = {
#     # Workloads layer depends on platform outputs (EKS node SG).
#     path = "../platform/terraform.tfstate"
#   }
# }

data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket         = "payflow-tfstate-003"
    key            = "dev/platform/terraform.tfstate"
    region         = var.region
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}

module "rds" {
  source = "../../../modules/rds"

  name_prefix = local.name_prefix
  tags        = local.tags

  vpc_id       = data.terraform_remote_state.foundation.outputs.spoke_vpc_id
  subnet_ids   = data.terraform_remote_state.foundation.outputs.spoke_data_private_subnet_ids
  allowed_sg_ids = [data.terraform_remote_state.platform.outputs.node_security_group_id]

  db_name        = var.rds_db_name
  username       = var.rds_username
  password       = var.rds_password
  instance_class = var.rds_instance_class
  backup_retention_period = var.rds_backup_retention_period
}

module "redis" {
  source = "../../../modules/elasticache"

  name_prefix = local.name_prefix
  tags        = local.tags

  vpc_id       = data.terraform_remote_state.foundation.outputs.spoke_vpc_id
  subnet_ids   = data.terraform_remote_state.foundation.outputs.spoke_data_private_subnet_ids
  allowed_sg_ids = [data.terraform_remote_state.platform.outputs.node_security_group_id]

  node_type = var.redis_node_type
}

module "rabbitmq" {
  source = "../../../modules/amazonmq"

  name_prefix = local.name_prefix
  tags        = local.tags

  vpc_id       = data.terraform_remote_state.foundation.outputs.spoke_vpc_id
  subnet_ids   = data.terraform_remote_state.foundation.outputs.spoke_data_private_subnet_ids
  allowed_sg_ids = [data.terraform_remote_state.platform.outputs.node_security_group_id]

  username           = var.mq_username
  password           = var.mq_password
  host_instance_type = var.mq_host_instance_type
  engine_version     = var.mq_engine_version
  auto_minor_version_upgrade = true
}

module "secrets" {
  source = "../../../modules/security"

  name_prefix = local.name_prefix
  tags        = local.tags

  db_secret = {
    host     = module.rds.endpoint
    port     = module.rds.port
    name     = var.rds_db_name
    username = var.rds_username
    password = var.rds_password
  }

  mq_secret = {
    endpoint = module.rabbitmq.endpoint
    username = var.mq_username
    password = var.mq_password
  }

  jwt_secret = var.jwt_secret
  slack_webhook_url = var.slack_webhook_url
}
