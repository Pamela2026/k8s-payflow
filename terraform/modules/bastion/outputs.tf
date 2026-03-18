output "bastion_instance_id" {
  description = "Bastion instance ID."
  value       = try(aws_instance.bastion[0].id, null)
}

output "ssm_connect_command" {
  description = "SSM connect command for the bastion."
  value       = try("aws ssm start-session --target ${aws_instance.bastion[0].id} --region ${var.region}", null)
}
