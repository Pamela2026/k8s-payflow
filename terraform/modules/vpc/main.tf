# ============================================
# VPC MODULE
# ============================================
# #### Creates hub and spoke VPCs, subnets, IGWs, NAT, TGW, and routes. ####
# #### Used by the foundation layer before platform and workloads. ####

## Derived subnet maps from CIDR lists and AZs. ##
## Used by subnet resources and NAT placement. ##
locals {
  hub_public_subnets = {
    for idx, cidr in var.hub_public_subnet_cidrs : idx => {
      cidr = cidr
      az   = var.azs[idx]
    }
  }

  hub_private_subnets = {
    for idx, cidr in var.hub_private_subnet_cidrs : idx => {
      cidr = cidr
      az   = var.azs[idx]
    }
  }

  spoke_public_subnets = {
    for idx, cidr in var.spoke_public_subnet_cidrs : idx => {
      cidr = cidr
      az   = var.azs[idx]
    }
  }

  spoke_private_subnets = {
    for idx, cidr in var.spoke_private_subnet_cidrs : idx => {
      cidr = cidr
      az   = var.azs[idx]
    }
  }

  spoke_data_private_subnets = {
    for idx, cidr in var.spoke_data_private_subnet_cidrs : idx => {
      cidr = cidr
      az   = var.azs[idx]
    }
  }

  spoke_public_subnet_ids       = [for k in sort(keys(aws_subnet.spoke_public)) : aws_subnet.spoke_public[k].id]
  spoke_private_subnet_ids      = [for k in sort(keys(aws_subnet.spoke_private)) : aws_subnet.spoke_private[k].id]
  spoke_data_private_subnet_ids = [for k in sort(keys(aws_subnet.spoke_data_private)) : aws_subnet.spoke_data_private[k].id]
  hub_private_subnet_ids        = [for k in sort(keys(aws_subnet.hub_private)) : aws_subnet.hub_private[k].id]

  spoke_private_route_table_ids = var.enable_multi_az_spoke_nat_gateway ? [for rt in values(aws_route_table.spoke_private_az) : rt.id] : [aws_route_table.spoke_private.id]
}

## Current AWS region used for VPC endpoint service names. ##
## Depends on: none. ##
data "aws_region" "current" {}

## Hub VPC. ##
## Depends on: none. ##
resource "aws_vpc" "hub" {
  cidr_block           = var.hub_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub"
  })
}

## Spoke VPC. ##
## Depends on: none. ##
resource "aws_vpc" "spoke" {
  cidr_block           = var.spoke_vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke"
  })
}

## Hub Internet Gateway for public egress. ##
## Depends on: aws_vpc.hub. ##
resource "aws_internet_gateway" "hub" {
  vpc_id = aws_vpc.hub.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-igw"
  })
}

## Spoke Internet Gateway for public subnets and NAT. ##
## Depends on: aws_vpc.spoke. ##
resource "aws_internet_gateway" "spoke" {
  vpc_id = aws_vpc.spoke.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-igw"
  })
}

## Hub public subnets. ##
## Depends on: aws_vpc.hub and var.azs. ##
resource "aws_subnet" "hub_public" {
  for_each                = local.hub_public_subnets
  vpc_id                  = aws_vpc.hub.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-public-${each.value.az}"
  })
}

## Hub private subnets. ##
## Depends on: aws_vpc.hub and var.azs. ##
resource "aws_subnet" "hub_private" {
  for_each          = local.hub_private_subnets
  vpc_id            = aws_vpc.hub.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-private-${each.value.az}"
  })
}

## Spoke public subnets used for load balancers and NAT. ##
## Depends on: aws_vpc.spoke, var.azs, and EKS tag inputs. ##
resource "aws_subnet" "spoke_public" {
  for_each                = local.spoke_public_subnets
  vpc_id                  = aws_vpc.spoke.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                            = "${var.name_prefix}-spoke-public-${each.value.az}"
    "kubernetes.io/role/elb"                        = var.eks_cluster_name != "" ? "1" : null
    "kubernetes.io/cluster/${var.eks_cluster_name}" = var.eks_cluster_name != "" ? "shared" : null
  })
}

## Spoke private subnets for EKS nodes and data services. ##
## Depends on: aws_vpc.spoke, var.azs, and EKS tag inputs. ##
resource "aws_subnet" "spoke_private" {
  for_each          = local.spoke_private_subnets
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name                                            = "${var.name_prefix}-spoke-private-${each.value.az}"
    "kubernetes.io/role/internal-elb"               = var.eks_cluster_name != "" ? "1" : null
    "kubernetes.io/cluster/${var.eks_cluster_name}" = var.eks_cluster_name != "" ? "shared" : null
  })
}

## Spoke data-only private subnets for managed services. ##
## Depends on: aws_vpc.spoke and var.azs. ##
resource "aws_subnet" "spoke_data_private" {
  for_each          = local.spoke_data_private_subnets
  vpc_id            = aws_vpc.spoke.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-data-private-${each.value.az}"
  })
}

## Hub public route table. ##
## Depends on: aws_vpc.hub. ##
resource "aws_route_table" "hub_public" {
  vpc_id = aws_vpc.hub.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-public-rt"
  })
}

## Hub private route table. ##
## Depends on: aws_vpc.hub. ##
resource "aws_route_table" "hub_private" {
  vpc_id = aws_vpc.hub.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-private-rt"
  })
}

## Spoke public route table. ##
## Depends on: aws_vpc.spoke. ##
resource "aws_route_table" "spoke_public" {
  vpc_id = aws_vpc.spoke.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-public-rt"
  })
}

## Spoke private route table. ##
## Depends on: aws_vpc.spoke. ##
resource "aws_route_table" "spoke_private" {
  vpc_id = aws_vpc.spoke.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-private-rt"
  })
}

## Spoke private route tables per AZ (multi-AZ NAT). ##
## Depends on: aws_vpc.spoke. ##
resource "aws_route_table" "spoke_private_az" {
  for_each = var.enable_multi_az_spoke_nat_gateway ? local.spoke_private_subnets : {}

  vpc_id = aws_vpc.spoke.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-private-rt-${each.value.az}"
  })
}

## Hub public default route to Internet Gateway. ##
## Depends on: aws_route_table.hub_public and aws_internet_gateway.hub. ##
resource "aws_route" "hub_public_igw" {
  route_table_id         = aws_route_table.hub_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.hub.id
}

## Spoke public default route to Internet Gateway. ##
## Depends on: aws_route_table.spoke_public and aws_internet_gateway.spoke. ##
resource "aws_route" "spoke_public_igw" {
  route_table_id         = aws_route_table.spoke_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.spoke.id
}

## Elastic IP for the spoke NAT Gateway. ##
## Depends on: none. ##
resource "aws_eip" "spoke_nat" {
  count  = var.enable_spoke_nat_gateway ? (var.enable_multi_az_spoke_nat_gateway ? length(local.spoke_public_subnet_ids) : 1) : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-nat-eip"
  })
}

## NAT Gateway for spoke private subnets. ##
## Depends on: aws_eip.spoke_nat and aws_subnet.spoke_public. ##
resource "aws_nat_gateway" "spoke" {
  count         = var.enable_spoke_nat_gateway ? (var.enable_multi_az_spoke_nat_gateway ? length(local.spoke_public_subnet_ids) : 1) : 0
  allocation_id = aws_eip.spoke_nat[count.index].id
  subnet_id     = var.enable_multi_az_spoke_nat_gateway ? local.spoke_public_subnet_ids[count.index] : local.spoke_public_subnet_ids[0]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-nat"
  })
}

## Spoke private default route to NAT Gateway. ##
## Depends on: aws_route_table.spoke_private and aws_nat_gateway.spoke. ##
resource "aws_route" "spoke_private_nat" {
  count                  = var.enable_spoke_nat_gateway && !var.enable_multi_az_spoke_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.spoke_private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.spoke[0].id
}

## Spoke private default routes per AZ (multi-AZ NAT). ##
## Depends on: aws_route_table.spoke_private_az and aws_nat_gateway.spoke. ##
resource "aws_route" "spoke_private_nat_az" {
  for_each               = var.enable_spoke_nat_gateway && var.enable_multi_az_spoke_nat_gateway ? local.spoke_private_subnets : {}
  route_table_id         = aws_route_table.spoke_private_az[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.spoke[each.key].id
}

## Associate hub public subnets to hub public route table. ##
## Depends on: aws_subnet.hub_public and aws_route_table.hub_public. ##
resource "aws_route_table_association" "hub_public" {
  for_each       = aws_subnet.hub_public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.hub_public.id
}

## Associate hub private subnets to hub private route table. ##
## Depends on: aws_subnet.hub_private and aws_route_table.hub_private. ##
resource "aws_route_table_association" "hub_private" {
  for_each       = aws_subnet.hub_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.hub_private.id
}

## Associate spoke public subnets to spoke public route table. ##
## Depends on: aws_subnet.spoke_public and aws_route_table.spoke_public. ##
resource "aws_route_table_association" "spoke_public" {
  for_each       = aws_subnet.spoke_public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.spoke_public.id
}

## Associate spoke private subnets to spoke private route table. ##
## Depends on: aws_subnet.spoke_private and aws_route_table.spoke_private. ##
resource "aws_route_table_association" "spoke_private" {
  for_each       = var.enable_multi_az_spoke_nat_gateway ? {} : aws_subnet.spoke_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.spoke_private.id
}

## Associate spoke data private subnets to spoke private route table. ##
## Depends on: aws_subnet.spoke_data_private and aws_route_table.spoke_private. ##
resource "aws_route_table_association" "spoke_data_private" {
  for_each       = var.enable_multi_az_spoke_nat_gateway ? {} : aws_subnet.spoke_data_private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.spoke_private.id
}

## Associate spoke private subnets to AZ-specific route tables (multi-AZ NAT). ##
## Depends on: aws_subnet.spoke_private and aws_route_table.spoke_private_az. ##
resource "aws_route_table_association" "spoke_private_az" {
  for_each       = var.enable_multi_az_spoke_nat_gateway ? aws_subnet.spoke_private : {}
  subnet_id      = each.value.id
  route_table_id = aws_route_table.spoke_private_az[each.key].id
}

## Associate spoke data private subnets to AZ-specific route tables (multi-AZ NAT). ##
## Depends on: aws_subnet.spoke_data_private and aws_route_table.spoke_private_az. ##
resource "aws_route_table_association" "spoke_data_private_az" {
  for_each       = var.enable_multi_az_spoke_nat_gateway ? aws_subnet.spoke_data_private : {}
  subnet_id      = each.value.id
  route_table_id = aws_route_table.spoke_private_az[each.key].id
}

## Transit Gateway for hub and spoke routing. ##
## Depends on: none. ##
resource "aws_ec2_transit_gateway" "core" {
  count       = var.enable_tgw ? 1 : 0
  description = "${var.name_prefix} transit gateway"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw"
  })
}

## Transit Gateway route table. ##
## Depends on: aws_ec2_transit_gateway.core. ##
resource "aws_ec2_transit_gateway_route_table" "core" {
  count              = var.enable_tgw ? 1 : 0
  transit_gateway_id = aws_ec2_transit_gateway.core[0].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw-rt"
  })
}

## Hub attachment to the Transit Gateway. ##
## Depends on: aws_vpc.hub, aws_subnet.hub_private, and aws_ec2_transit_gateway.core. ##
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  count                                           = var.enable_tgw ? 1 : 0
  transit_gateway_id                              = aws_ec2_transit_gateway.core[0].id
  vpc_id                                          = aws_vpc.hub.id
  subnet_ids                                      = local.hub_private_subnet_ids
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-tgw-attach"
  })
}

## Spoke attachment to the Transit Gateway. ##
## Depends on: aws_vpc.spoke, aws_subnet.spoke_private, and aws_ec2_transit_gateway.core. ##
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  count                                           = var.enable_tgw ? 1 : 0
  transit_gateway_id                              = aws_ec2_transit_gateway.core[0].id
  vpc_id                                          = aws_vpc.spoke.id
  subnet_ids                                      = local.spoke_private_subnet_ids
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-spoke-tgw-attach"
  })
}

## Associate hub attachment with the TGW route table. ##
## Depends on: aws_ec2_transit_gateway_vpc_attachment.hub and aws_ec2_transit_gateway_route_table.core. ##
resource "aws_ec2_transit_gateway_route_table_association" "hub" {
  count                          = var.enable_tgw ? 1 : 0
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.core[0].id
}

## Associate spoke attachment with the TGW route table. ##
## Depends on: aws_ec2_transit_gateway_vpc_attachment.spoke and aws_ec2_transit_gateway_route_table.core. ##
resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  count                          = var.enable_tgw ? 1 : 0
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.core[0].id
}

## Propagate hub attachment routes into the TGW route table. ##
## Depends on: aws_ec2_transit_gateway_vpc_attachment.hub and aws_ec2_transit_gateway_route_table.core. ##
resource "aws_ec2_transit_gateway_route_table_propagation" "hub" {
  count                          = var.enable_tgw ? 1 : 0
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.core[0].id
}

## Propagate spoke attachment routes into the TGW route table. ##
## Depends on: aws_ec2_transit_gateway_vpc_attachment.spoke and aws_ec2_transit_gateway_route_table.core. ##
resource "aws_ec2_transit_gateway_route_table_propagation" "spoke" {
  count                          = var.enable_tgw ? 1 : 0
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[0].id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.core[0].id
}

## TGW route from hub to spoke CIDR. ##
## Depends on: aws_ec2_transit_gateway_route_table.core and aws_ec2_transit_gateway_vpc_attachment.spoke. ##
resource "aws_ec2_transit_gateway_route" "hub_to_spoke" {
  count                          = var.enable_tgw ? 1 : 0
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.core[0].id
  destination_cidr_block         = var.spoke_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke[0].id
}

## TGW route from spoke to hub CIDR. ##
## Depends on: aws_ec2_transit_gateway_route_table.core and aws_ec2_transit_gateway_vpc_attachment.hub. ##
resource "aws_ec2_transit_gateway_route" "spoke_to_hub" {
  count                          = var.enable_tgw ? 1 : 0
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.core[0].id
  destination_cidr_block         = var.hub_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.hub[0].id
}

## Hub private route to spoke via TGW. ##
## Depends on: aws_route_table.hub_private and aws_ec2_transit_gateway.core. ##
resource "aws_route" "hub_to_spoke" {
  count                  = var.enable_tgw ? 1 : 0
  route_table_id         = aws_route_table.hub_private.id
  destination_cidr_block = var.spoke_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.core[0].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.hub,
    aws_ec2_transit_gateway_vpc_attachment.spoke
  ]
}

## Hub public route to spoke via TGW. ##
## Depends on: aws_route_table.hub_public and aws_ec2_transit_gateway.core. ##
resource "aws_route" "hub_public_to_spoke" {
  count                  = var.enable_tgw ? 1 : 0
  route_table_id         = aws_route_table.hub_public.id
  destination_cidr_block = var.spoke_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.core[0].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.hub,
    aws_ec2_transit_gateway_vpc_attachment.spoke
  ]
}

## Spoke private route to hub via TGW. ##
## Depends on: aws_route_table.spoke_private and aws_ec2_transit_gateway.core. ##
resource "aws_route" "spoke_to_hub" {
  count                  = var.enable_tgw ? 1 : 0
  route_table_id         = aws_route_table.spoke_private.id
  destination_cidr_block = var.hub_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.core[0].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.hub,
    aws_ec2_transit_gateway_vpc_attachment.spoke
  ]
}

## Spoke public route to hub via TGW. ##
## Depends on: aws_route_table.spoke_public and aws_ec2_transit_gateway.core. ##
resource "aws_route" "spoke_public_to_hub" {
  count                  = var.enable_tgw ? 1 : 0
  route_table_id         = aws_route_table.spoke_public.id
  destination_cidr_block = var.hub_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.core[0].id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.hub,
    aws_ec2_transit_gateway_vpc_attachment.spoke
  ]
}

## Security group for interface VPC endpoints. ##
## Depends on: aws_vpc.spoke. ##
resource "aws_security_group" "endpoints" {
  count       = var.create_vpc_endpoints ? 1 : 0
  name        = "${var.name_prefix}-vpce-sg"
  description = "Allow VPC endpoint access within spoke VPC"
  vpc_id      = aws_vpc.spoke.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.spoke_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-sg"
  })
}

## S3 gateway endpoint for private subnets. ##
## Depends on: aws_vpc.spoke and aws_route_table.spoke_private. ##
resource "aws_vpc_endpoint" "s3" {
  count             = var.create_s3_gateway_endpoint ? 1 : 0
  vpc_id            = aws_vpc.spoke.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.spoke_private_route_table_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-s3"
  })
}

## Interface VPC endpoints for AWS APIs (ECR, STS, Secrets Manager, Logs, KMS). ##
## Depends on: aws_vpc.spoke, aws_subnet.spoke_private, and aws_security_group.endpoints. ##
resource "aws_vpc_endpoint" "interface" {
  for_each = var.create_vpc_endpoints ? toset(var.interface_endpoint_services) : []

  vpc_id              = aws_vpc.spoke.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.spoke_private_subnet_ids
  security_group_ids  = [aws_security_group.endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-${each.value}"
  })
}
