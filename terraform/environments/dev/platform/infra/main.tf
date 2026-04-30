# ============================================
# PLATFORM (DEV)
# ============================================
# #### Creates private EKS cluster and core add-ons. ####
# #### Depends on dev foundation outputs. ####

resource "local_file" "alb_ingress" {
  filename = "${path.root}/../../../../../overlays/dev/alb-ingress.yaml"
  content = templatefile("${path.root}/templates/alb-ingress.yaml.tpl", {
    waf_web_acl_arn     = module.waf.web_acl_arn
    alb_certificate_arn = var.enable_alb_cert && var.alb_cert_domain != null ? aws_acm_certificate.alb[0].arn : ""
  })
}

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

  name_prefix     = local.name_prefix
  tags            = local.tags
  region          = var.region
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id             = data.terraform_remote_state.foundation.outputs.spoke_vpc_id
  private_subnet_ids = data.terraform_remote_state.foundation.outputs.spoke_private_subnet_ids
  public_subnet_ids  = data.terraform_remote_state.foundation.outputs.spoke_public_subnet_ids
  bastion_role_arn   = data.terraform_remote_state.foundation.outputs.bastion_role_arn
  terraform_user_arn = var.terraform_user_arn
  bastion_vpc_cidr   = var.bastion_vpc_cidr
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

module "waf" {
  source = "../../../../modules/waf"

  enabled                    = var.enable_waf
  name_prefix                = local.name_prefix
  rate_limit                 = var.waf_rate_limit
  enable_common_rule_set     = var.waf_enable_common_rule_set
  enable_bad_inputs_rule_set = var.waf_enable_bad_inputs_rule_set
  enable_sqli_rule_set       = var.waf_enable_sqli_rule_set
  enable_rate_limit          = var.waf_enable_rate_limit
  common_rule_priority       = var.waf_common_rule_priority
  bad_inputs_rule_priority   = var.waf_bad_inputs_rule_priority
  sqli_rule_priority         = var.waf_sqli_rule_priority
  rate_limit_priority        = var.waf_rate_limit_priority
  tags                       = local.tags
}

data "aws_route53_zone" "alb_cert" {
  count   = var.enable_alb_cert && var.hosted_zone_id != null ? 1 : 0
  zone_id = var.hosted_zone_id
}

resource "aws_acm_certificate" "alb" {
  count = var.enable_alb_cert && var.alb_cert_domain != null ? 1 : 0

  domain_name       = var.alb_cert_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

resource "aws_route53_record" "alb_cert_validation" {
  for_each = var.enable_alb_cert && var.alb_cert_domain != null ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  } : {}

  zone_id = data.aws_route53_zone.alb_cert[0].zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "alb" {
  count = var.enable_alb_cert && var.alb_cert_domain != null ? 1 : 0

  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for r in aws_route53_record.alb_cert_validation : r.fqdn]
}
