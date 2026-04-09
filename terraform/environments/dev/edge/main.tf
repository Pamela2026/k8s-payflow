data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

data "kubernetes_ingress_v1" "app" {
  count = var.enable_cdn && var.alb_dns_name == null && var.ingress_name != null ? 1 : 0

  metadata {
    name      = var.ingress_name
    namespace = var.ingress_namespace
  }
}

locals {
  ingress_alb_hostname = var.enable_cdn && length(data.kubernetes_ingress_v1.app) > 0 ? try(data.kubernetes_ingress_v1.app[0].status[0].load_balancer[0].ingress[0].hostname, null) : null
  alb_dns_name         = var.alb_dns_name != null ? var.alb_dns_name : local.ingress_alb_hostname
}

module "waf" {
  source = "../../../modules/waf"

  enabled     = var.enable_waf
  name_prefix = local.name_prefix
  rate_limit  = var.waf_rate_limit
  enable_common_rule_set     = var.waf_enable_common_rule_set
  enable_bad_inputs_rule_set = var.waf_enable_bad_inputs_rule_set
  enable_sqli_rule_set       = var.waf_enable_sqli_rule_set
  enable_rate_limit          = var.waf_enable_rate_limit
  common_rule_priority       = var.waf_common_rule_priority
  bad_inputs_rule_priority   = var.waf_bad_inputs_rule_priority
  sqli_rule_priority         = var.waf_sqli_rule_priority
  rate_limit_priority        = var.waf_rate_limit_priority
  tags        = local.tags
}

module "cdn" {
  source = "../../../modules/cdn"
  providers = {
    aws = aws
    aws.us_east_1 = aws.us_east_1
  }

  enabled        = var.enable_cdn
  app_domain     = var.app_domain
  hosted_zone_id = var.hosted_zone_id
  alb_dns_name   = local.alb_dns_name
  tags           = local.tags
}
