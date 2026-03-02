data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

module "hub_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-hub-vpc"
  cidr = var.hub_vpc_cidr
  azs  = local.azs

  private_subnets = [for idx, _az in local.azs : cidrsubnet(var.hub_vpc_cidr, 4, idx)]
  public_subnets  = [for idx, _az in local.azs : cidrsubnet(var.hub_vpc_cidr, 4, idx + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, { NetworkRole = "hub" })
}

module "spoke_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name_prefix}-spoke-vpc"
  cidr = var.spoke_vpc_cidr
  azs  = local.azs

  private_subnets = [for idx, _az in local.azs : cidrsubnet(var.spoke_vpc_cidr, 4, idx)]
  public_subnets  = [for idx, _az in local.azs : cidrsubnet(var.spoke_vpc_cidr, 4, idx + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }

  tags = merge(local.common_tags, { NetworkRole = "spoke" })
}

resource "aws_ec2_transit_gateway" "this" {
  description = "${local.name_prefix} transit gateway"

  amazon_side_asn                 = var.transit_gateway_asn
  auto_accept_shared_attachments  = "disable"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-tgw" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  subnet_ids         = module.hub_vpc.private_subnets
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = module.hub_vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-hub-attachment" })
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  subnet_ids         = module.spoke_vpc.private_subnets
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = module.spoke_vpc.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-spoke-attachment" })
}

resource "aws_route" "hub_to_spoke" {
  for_each = toset(module.hub_vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = var.spoke_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.hub,
    aws_ec2_transit_gateway_vpc_attachment.spoke
  ]
}

resource "aws_route" "spoke_to_hub" {
  for_each = toset(module.spoke_vpc.private_route_table_ids)

  route_table_id         = each.value
  destination_cidr_block = var.hub_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.this.id

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment.hub,
    aws_ec2_transit_gateway_vpc_attachment.spoke
  ]
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  vpc_id                   = module.spoke_vpc.vpc_id
  subnet_ids               = module.spoke_vpc.private_subnets
  control_plane_subnet_ids = module.spoke_vpc.private_subnets

  cluster_addons = {
    coredns      = {}
    "kube-proxy" = {}
    "vpc-cni"    = {}
  }

  eks_managed_node_groups = {
    default = {
      min_size       = var.node_group_min_size
      max_size       = var.node_group_max_size
      desired_size   = var.node_group_desired_size
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = merge(local.common_tags, { Workload = "payflow-eks" })

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}
