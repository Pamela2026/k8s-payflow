output "db_instance_id" {
  description = "RDS instance ID."
  value       = aws_db_instance.this.id
}

output "endpoint" {
  description = "RDS endpoint."
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS port."
  value       = aws_db_instance.this.port
}

output "security_group_id" {
  description = "RDS security group ID."
  value       = aws_security_group.this.id
}
