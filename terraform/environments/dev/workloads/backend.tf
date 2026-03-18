# ============================================
# BACKEND STATE (DEV / WORKLOADS)
# ============================================
# #### State for dev workloads layer. ####
# #### Depends on dev platform state outputs. ####
# #### Run after platform. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "dev/workloads/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
