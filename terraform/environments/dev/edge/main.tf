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
}
