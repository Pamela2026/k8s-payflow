output "bastion_instance_id" {
  description = "Bastion instance ID."
  value       = try(aws_instance.bastion[0].id, null)
}

output "ssm_connect_command" {
  description = "SSM connect command for the bastion."
  value       = try("aws ssm start-session --target ${aws_instance.bastion[0].id} --region ${var.region}", null)
}

output "bastion_role_arn" {
  description = "IAM role ARN attached to the bastion instance."
  value       = try(aws_iam_role.bastion[0].arn, null)
}
