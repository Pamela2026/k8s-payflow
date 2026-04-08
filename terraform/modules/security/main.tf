## Secrets Manager: database credentials. ##
resource "aws_secretsmanager_secret" "db" {
  name = "${var.name_prefix}-db"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = var.db_secret.host
    port     = var.db_secret.port
    name     = var.db_secret.name
    username = var.db_secret.username
    password = var.db_secret.password
  })
}

## Secrets Manager: RabbitMQ credentials. ##
resource "aws_secretsmanager_secret" "mq" {
  name = "${var.name_prefix}-mq"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "mq" {
  secret_id     = aws_secretsmanager_secret.mq.id
  secret_string = jsonencode({
    endpoint = var.mq_secret.endpoint
    username = var.mq_secret.username
    password = var.mq_secret.password
  })
}

## Secrets Manager: JWT secret. ##
resource "aws_secretsmanager_secret" "jwt" {
  name = "${var.name_prefix}-jwt"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id     = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    jwt_secret = var.jwt_secret
  })
}

## Secrets Manager: Alertmanager Slack webhook (optional). ##
resource "aws_secretsmanager_secret" "alertmanager_slack" {
  count = var.slack_webhook_url != null && var.slack_webhook_url != "" ? 1 : 0

  name = "${var.name_prefix}-slack-webhook"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "alertmanager_slack" {
  count = var.slack_webhook_url != null && var.slack_webhook_url != "" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.alertmanager_slack[0].id
  secret_string = jsonencode({
    webhook-url = var.slack_webhook_url
  })
}
