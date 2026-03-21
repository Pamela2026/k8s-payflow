output "rds_endpoint" {
  description = "RDS endpoint."
  value       = module.rds.endpoint
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint."
  value       = module.redis.primary_endpoint
}

output "rabbitmq_endpoint" {
  description = "RabbitMQ endpoint."
  value       = module.rabbitmq.endpoint
}

output "db_secret_arn" {
  description = "DB Secrets Manager ARN."
  value       = module.secrets.db_secret_arn
}

output "mq_secret_arn" {
  description = "MQ Secrets Manager ARN."
  value       = module.secrets.mq_secret_arn
}

output "jwt_secret_arn" {
  description = "JWT Secrets Manager ARN."
  value       = module.secrets.jwt_secret_arn
}
