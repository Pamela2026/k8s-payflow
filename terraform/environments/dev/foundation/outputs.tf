# ============================================
# FOUNDATION OUTPUTS (DEV)
# ============================================
# #### Networking outputs consumed by platform and workloads. ####

output "hub_vpc_id" {
  description = "Hub VPC ID."
  value       = module.vpc.hub_vpc_id
}

output "spoke_vpc_id" {
  description = "Spoke VPC ID."
  value       = module.vpc.spoke_vpc_id
}

output "hub_public_subnet_ids" {
  description = "Hub public subnet IDs."
  value       = module.vpc.hub_public_subnet_ids
}

output "hub_private_subnet_ids" {
  description = "Hub private subnet IDs."
  value       = module.vpc.hub_private_subnet_ids
}

output "spoke_public_subnet_ids" {
  description = "Spoke public subnet IDs."
  value       = module.vpc.spoke_public_subnet_ids
}

output "spoke_private_subnet_ids" {
  description = "Spoke private subnet IDs."
  value       = module.vpc.spoke_private_subnet_ids
}

output "spoke_data_private_subnet_ids" {
  description = "Spoke data private subnet IDs."
  value       = module.vpc.spoke_data_private_subnet_ids
}

output "bastion_instance_id" {
  description = "Bastion instance ID."
  value       = module.bastion.bastion_instance_id
}

output "bastion_role_arn" {
  description = "IAM role ARN for the bastion instance."
  value       = module.bastion.bastion_role_arn
}

output "bastion_ssm_connect_command" {
  description = "SSM connect command for the bastion."
  value       = module.bastion.ssm_connect_command
}

output "tgw_id" {
  description = "Transit Gateway ID."
  value       = module.vpc.tgw_id
}

output "spoke_private_route_table_id" {
  description = "Spoke private route table ID."
  value       = module.vpc.spoke_private_route_table_id
}

output "ecr_repository_urls" {
  description = "Map of ECR repository name to URL."
  value       = module.ecr.repository_urls
}
