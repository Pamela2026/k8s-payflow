# ============================================
# COST OPS (AWS)
# ============================================

resource "aws_budgets_budget" "monthly_cost" {
  count = var.enable_cost_ops ? 1 : 0

  name         = "${var.name_prefix}-monthly-cost-budget"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_amount)
  limit_unit   = var.budget_unit
  time_unit    = "MONTHLY"

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 80
    threshold_type      = "PERCENTAGE"
    notification_type   = "FORECASTED"

    dynamic "subscriber" {
      for_each = var.budget_email_addresses
      content {
        address          = subscriber.value
        subscription_type = "EMAIL"
      }
    }
  }

  notification {
    comparison_operator = "GREATER_THAN"
    threshold           = 100
    threshold_type      = "PERCENTAGE"
    notification_type   = "ACTUAL"

    dynamic "subscriber" {
      for_each = var.budget_email_addresses
      content {
        address          = subscriber.value
        subscription_type = "EMAIL"
      }
    }
  }

  tags = var.tags
}

resource "aws_ce_anomaly_monitor" "service" {
  count = var.enable_cost_ops ? 1 : 0

  name              = "${var.name_prefix}-service-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "service" {
  count = var.enable_cost_ops ? 1 : 0

  name             = "${var.name_prefix}-service-anomaly-subscription"
  frequency        = var.anomaly_frequency
  monitor_arn_list = [aws_ce_anomaly_monitor.service[0].arn]
  threshold        = var.anomaly_threshold

  dynamic "subscriber" {
    for_each = var.anomaly_email_addresses
    content {
      address = subscriber.value
      type    = "EMAIL"
    }
  }

  depends_on = [aws_ce_anomaly_monitor.service]
}
