module "cdn" {
  source = "../../../modules/cdn"
  providers = {
    aws = aws
    aws.us_east_1 = aws.us_east_1
  }

  enabled        = var.enable_cdn
  app_domain     = var.app_domain
  hosted_zone_id = var.hosted_zone_id
  alb_dns_name   = var.alb_dns_name
  tags           = local.tags
  web_acl_id     = module.waf_cdn.web_acl_id
}

module "waf_cdn" {
  source = "../../../modules/waf"

  enabled                    = var.enable_waf
  name_prefix                = "${local.name_prefix}-cdn"
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
  scope                      = "CLOUDFRONT"
}