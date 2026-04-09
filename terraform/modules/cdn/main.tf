locals {
  alb_origin_dns = var.alb_dns_name != null ? replace(replace(var.alb_dns_name, "https://", ""), "http://", "") : null
}

data "aws_route53_zone" "app" {
  count   = var.enabled && var.hosted_zone_id != null ? 1 : 0
  zone_id = var.hosted_zone_id
}

resource "aws_acm_certificate" "app" {
  count    = var.enabled && var.app_domain != null ? 1 : 0
  provider = aws.us_east_1

  domain_name       = var.app_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

resource "aws_route53_record" "app_cert_validation" {
  count = var.enabled && var.app_domain != null ? 1 : 0

  zone_id = data.aws_route53_zone.app[0].zone_id
  name    = aws_acm_certificate.app[0].domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.app[0].domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.app[0].domain_validation_options[0].resource_record_value]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "app" {
  count    = var.enabled && var.app_domain != null ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.app[0].arn
  validation_record_fqdns = [aws_route53_record.app_cert_validation[0].fqdn]
}

resource "aws_cloudfront_distribution" "app" {
  count = var.enabled && var.app_domain != null && local.alb_origin_dns != null ? 1 : 0

  enabled             = true
  is_ipv6_enabled     = true
  comment             = var.comment
  default_root_object = ""

  aliases = [var.app_domain]

  origin {
    domain_name = local.alb_origin_dns
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = var.origin_protocol_policy
      origin_ssl_protocols   = var.origin_ssl_protocols
    }
  }

  default_cache_behavior {
    allowed_methods        = var.allowed_methods
    cached_methods         = var.cached_methods
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = var.viewer_protocol_policy

    cache_policy_id          = var.cache_policy_id
    origin_request_policy_id = var.origin_request_policy_id
  }

  price_class = var.price_class

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.app[0].certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = var.tags
}

resource "aws_route53_record" "app_alias" {
  count = var.enabled && var.app_domain != null ? 1 : 0

  zone_id = data.aws_route53_zone.app[0].zone_id
  name    = var.app_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app[0].domain_name
    zone_id                = aws_cloudfront_distribution.app[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "app_alias_ipv6" {
  count = var.enabled && var.app_domain != null ? 1 : 0

  zone_id = data.aws_route53_zone.app[0].zone_id
  name    = var.app_domain
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.app[0].domain_name
    zone_id                = aws_cloudfront_distribution.app[0].hosted_zone_id
    evaluate_target_health = false
  }
}
