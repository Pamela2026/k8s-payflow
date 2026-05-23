data "aws_route53_zone" "alb_cert" {
  count   = var.enable_alb_cert && var.hosted_zone_id != null ? 1 : 0
  zone_id = var.hosted_zone_id
}

data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  count = var.vpc_id != null ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_acm_certificate" "alb" {
  count = var.enable_alb_cert && var.alb_cert_domain != null ? 1 : 0

  domain_name       = var.alb_cert_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
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

resource "aws_security_group" "alb_origin" {
  count = var.vpc_id != null ? 1 : 0

  name        = "payflow-alb-origin"
  description = "Allow CloudFront origin-facing traffic to the Payflow ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "CloudFront origin-facing HTTP"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront_origin_facing[0].id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
