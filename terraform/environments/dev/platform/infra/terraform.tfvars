region          = "us-east-1"
environment     = "dev"
project_name    = "payflow"
cluster_name    = "payflow-eks-dev"
cluster_version = "1.33"

node_instance_types = ["m7i-flex.large"]
node_min_size       = 2
node_max_size       = 4
node_desired_size   = 2

endpoint_private_access = true
endpoint_public_access  = false
# admin_role_arn is environment-specific; set via TF_VAR_admin_role_arn or terraform.tfvars.local
terraform_user_arn = "arn:aws:iam::725094769583:role/for-payflow-terraform"
bastion_vpc_cidr   = "10.0.0.0/16"

# Edge / Route 53 are disabled for now.
# Activate these if you own a domain.
# enable_alb_cert = true
# alb_cert_domain = "computehub.online"
# hosted_zone_id  = "Z02373822JO7MP3G5ZLH"

# RDS
rds_db_name  = "payflow"
rds_username = "payflow_admin"
# rds_password must be provided via TF_VAR_rds_password or terraform.tfvars.local
rds_instance_class          = "db.t3.micro"
rds_backup_retention_period = 0

# Redis
redis_node_type = "cache.r7g.xlarge"

# RabbitMQ
mq_username = "payflow_mq"
# mq_password must be provided via TF_VAR_mq_password or terraform.tfvars.local
mq_host_instance_type = "mq.m7g.large"
mq_engine_version     = "3.13"

# JWT
# jwt_secret must be provided via TF_VAR_jwt_secret or terraform.tfvars.local
# slack_webhook_url must be provided via TF_VAR_slack_webhook_url or terraform.tfvars.local


tags = {
  Owner = "payflow-wallet"
}
