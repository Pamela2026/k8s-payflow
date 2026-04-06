region               = "us-east-1"
environment          = "dev"
project_name         = "payflow"
cluster_name         = "payflow-eks-dev"
cluster_version      = "1.33"

node_instance_types  = ["m7i-flex.large"]
node_min_size        = 2
node_max_size        = 4
node_desired_size    = 2

endpoint_private_access = true
endpoint_public_access  = false
# admin_role_arn is environment-specific; set via TF_VAR_admin_role_arn or terraform.tfvars.local

ecr_repositories = [
  "payflow-wallet-api-gateway",
  "payflow-wallet-auth-service",
  "payflow-wallet-frontend",
  "payflow-wallet-notification-service",
  "payflow-wallet-transaction-service",
  "payflow-wallet-wallet-service"
]

enable_waf     = true
waf_rate_limit = 2000


tags = {
  Owner = "payflow-wallet"
}
