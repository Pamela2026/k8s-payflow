# ============================================
# VPC MODULE OUTPUTS
# ============================================
# #### IDs and subnet lists used by platform and workloads. ####

output "hub_vpc_id" {
  description = "Hub VPC ID."
  value       = aws_vpc.hub.id
}

output "spoke_vpc_id" {
  description = "Spoke VPC ID."
  value       = aws_vpc.spoke.id
}

output "hub_public_subnet_ids" {
  description = "Hub public subnet IDs."
  value       = [for k in sort(keys(aws_subnet.hub_public)) : aws_subnet.hub_public[k].id]
}

output "hub_private_subnet_ids" {
  description = "Hub private subnet IDs."
  value       = [for k in sort(keys(aws_subnet.hub_private)) : aws_subnet.hub_private[k].id]
}

output "spoke_public_subnet_ids" {
  description = "Spoke public subnet IDs."
  value       = [for k in sort(keys(aws_subnet.spoke_public)) : aws_subnet.spoke_public[k].id]
}

output "spoke_private_subnet_ids" {
  description = "Spoke private subnet IDs."
  value       = [for k in sort(keys(aws_subnet.spoke_private)) : aws_subnet.spoke_private[k].id]
}

output "spoke_data_private_subnet_ids" {
  description = "Spoke data private subnet IDs."
  value       = [for k in sort(keys(aws_subnet.spoke_data_private)) : aws_subnet.spoke_data_private[k].id]
}

output "tgw_id" {
  description = "Transit Gateway ID."
  value       = var.enable_tgw ? aws_ec2_transit_gateway.core[0].id : null
}

output "spoke_private_route_table_id" {
  description = "Spoke private route table ID."
  value       = local.spoke_private_route_table_ids[0]
}

output "spoke_public_route_table_id" {
  description = "Spoke public route table ID."
  value       = aws_route_table.spoke_public.id
}

output "spoke_private_route_table_ids" {
  description = "Spoke private route table IDs (single or per-AZ)."
  value       = local.spoke_private_route_table_ids
}
