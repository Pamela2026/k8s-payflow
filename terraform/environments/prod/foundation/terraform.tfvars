# Prod foundation environment defaults
region                      = "us-east-1"
environment                 = "prod"
project_name                = "payflow"
eks_cluster_name            = "payflow-eks-cluster"
azs                         = ["us-east-1a", "us-east-1b", "us-east-1c"]

hub_vpc_cidr                = "10.4.0.0/16"
hub_public_subnet_cidrs     = ["10.4.10.0/24", "10.4.20.0/24", "10.4.30.0/24"]
hub_private_subnet_cidrs    = ["10.4.110.0/24", "10.4.120.0/24", "10.4.130.0/24"]

spoke_vpc_cidr              = "10.5.0.0/16"
spoke_public_subnet_cidrs   = ["10.5.10.0/24", "10.5.20.0/24", "10.5.30.0/24"]
spoke_private_subnet_cidrs  = ["10.5.110.0/24", "10.5.120.0/24", "10.5.130.0/24"]
spoke_data_private_subnet_cidrs = ["10.5.210.0/24", "10.5.220.0/24", "10.5.230.0/24"]

enable_tgw                  = true
enable_spoke_nat_gateway    = true
create_vpc_endpoints        = true
create_s3_gateway_endpoint  = true
interface_endpoint_services = ["ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs", "kms"]

enable_bastion             = true
bastion_instance_type       = "t3.micro"
bastion_ssh_cidr_blocks     = []
bastion_key_name            = null
bastion_ami_id              = null

tags = {
  Owner = "payflow-wallet"
}

ecr_repositories = [
  "payflow-wallet-api-gateway",
  "payflow-wallet-auth-service",
  "payflow-wallet-frontend",
  "payflow-wallet-notification-service",
  "payflow-wallet-transaction-service",
  "payflow-wallet-wallet-service"
]
