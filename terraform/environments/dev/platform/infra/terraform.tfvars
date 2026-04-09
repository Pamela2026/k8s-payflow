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
terraform_user_arn = "arn:aws:iam::725094769583:role/for-payflow-terraform"
bastion_vpc_cidr   = "10.0.0.0/16"

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
waf_enable_common_rule_set     = true
waf_enable_bad_inputs_rule_set = true
waf_enable_sqli_rule_set       = true
waf_enable_rate_limit          = true

enable_alb_cert = true
alb_cert_domain = "computehub.online"
hosted_zone_id  = "Z02373822JO7MP3G5ZLH"

tags = {
  Owner = "payflow-wallet"
}
