# Dev foundation environment defaults
region           = "us-east-1"
environment      = "dev"
project_name     = "payflow"
eks_cluster_name = "payflow-eks-dev"
azs              = ["us-east-1a", "us-east-1b", "us-east-1c"]

hub_vpc_cidr             = "10.0.0.0/16"
hub_public_subnet_cidrs  = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
hub_private_subnet_cidrs = ["10.0.110.0/24", "10.0.120.0/24", "10.0.130.0/24"]

spoke_vpc_cidr                  = "10.1.0.0/16"
spoke_public_subnet_cidrs       = ["10.1.10.0/24", "10.1.20.0/24", "10.1.30.0/24"]
spoke_private_subnet_cidrs      = ["10.1.110.0/24", "10.1.120.0/24", "10.1.130.0/24"]
spoke_data_private_subnet_cidrs = ["10.1.210.0/24", "10.1.220.0/24", "10.1.230.0/24"]

enable_tgw                  = true
enable_spoke_nat_gateway    = true
create_vpc_endpoints        = true
create_s3_gateway_endpoint  = true
interface_endpoint_services = ["ecr.api", "ecr.dkr", "sts", "secretsmanager", "logs", "kms"]

enable_bastion             = true
bastion_instance_type       = "t3.micro"
bastion_ssh_cidr_blocks     = ["102.91.93.17/32"]
bastion_key_name            = "payflow-bastion-key"
bastion_ami_id              = null


tags = {
  Owner = "payflow-wallet"
}

#---- Cost Ops (AWS Budgets + Anomaly Detection) ----
enable_cost_ops = true
cost_ops_budget_amount = 500
cost_ops_budget_unit = "USD"
cost_ops_anomaly_threshold = 100
cost_ops_anomaly_frequency = "DAILY"
cost_ops_email_addresses = ["pamelapateick464@gmail.com"]
