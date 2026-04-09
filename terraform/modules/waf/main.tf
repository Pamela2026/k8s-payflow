resource "aws_wafv2_web_acl" "this" {
  count = var.enabled ? 1 : 0

  name  = "${var.name_prefix}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = var.enable_common_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesCommonRuleSet"
      priority = var.common_rule_priority

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
  }

  dynamic "rule" {
    for_each = var.enable_bad_inputs_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesKnownBadInputsRuleSet"
      priority = var.bad_inputs_rule_priority

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
  }

  dynamic "rule" {
    for_each = var.enable_sqli_rule_set ? [1] : []
    content {
      name     = "AWSManagedRulesSQLiRuleSet"
      priority = var.sqli_rule_priority

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
  }

  dynamic "rule" {
    for_each = var.enable_rate_limit ? [1] : []
    content {
      name     = "RateLimit"
      priority = var.rate_limit_priority

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = var.rate_limit
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "rateLimit"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "payflowAlbWaf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}
