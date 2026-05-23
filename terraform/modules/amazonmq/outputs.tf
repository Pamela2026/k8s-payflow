output "broker_id" {
  description = "Broker ID."
  value       = aws_mq_broker.this.id
}

output "endpoint" {
  description = "RabbitMQ endpoint."
  value       = aws_mq_broker.this.instances[0].endpoints[0]
}

output "security_group_id" {
  description = "Broker security group ID."
  value       = aws_security_group.this.id
}
