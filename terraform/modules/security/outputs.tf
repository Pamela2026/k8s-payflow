output "db_secret_arn" {
  description = "DB secret ARN."
  value       = aws_secretsmanager_secret.db.arn
}

output "mq_secret_arn" {
  description = "MQ secret ARN."
  value       = aws_secretsmanager_secret.mq.arn
}

output "redis_secret_arn" {
  description = "Redis secret ARN."
  value       = aws_secretsmanager_secret.redis.arn
}

output "jwt_secret_arn" {
  description = "JWT secret ARN."
  value       = aws_secretsmanager_secret.jwt.arn
}

output "slack_webhook_secret_arn" {
  description = "Alertmanager Slack webhook secret ARN (optional)."
  value       = try(aws_secretsmanager_secret.alertmanager_slack[0].arn, null)
}
