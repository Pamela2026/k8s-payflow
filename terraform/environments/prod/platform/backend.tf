# ============================================
# BACKEND STATE (PROD / PLATFORM)
# ============================================
# #### State for prod platform layer. ####
# #### Depends on prod foundation state outputs. ####
# #### Run after foundation and before workloads. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "prod/platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
