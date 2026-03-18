# ============================================
# BACKEND STATE (PROD / WORKLOADS)
# ============================================
# #### State for prod workloads layer. ####
# #### Depends on prod platform state outputs. ####
# #### Run after platform. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "prod/workloads/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
