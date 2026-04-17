region       = "us-east-1"
environment  = "dev"
project_name = "payflow"

# admin_role_arn is environment-specific; set via TF_VAR_admin_role_arn or terraform.tfvars.local

tags = {
  Owner = "payflow-wallet"
}

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
