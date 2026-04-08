# ============================================
# PLATFORM (DEV)
# ============================================
# #### Creates private EKS cluster and core add-ons. ####
# #### Depends on dev foundation outputs. ####

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

module "eks" {
  source = "../../../../modules/eks"

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
  bastion_vpc_cidr    = var.bastion_vpc_cidr
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
}

module "ecr" {
  source = "../../../../modules/ecr"

  repositories = var.ecr_repositories
  tags         = local.tags
}

resource "aws_wafv2_web_acl" "alb" {
  count = var.enable_waf ? 1 : 0

  name  = "${local.name_prefix}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsManagedCommon"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsManagedBadInputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsManagedSQLi"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimit"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rateLimit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "payflowAlbWaf"
    sampled_requests_enabled   = true
  }

  tags = local.tags
}
