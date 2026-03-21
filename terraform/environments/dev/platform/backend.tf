# ============================================
# BACKEND STATE (DEV / PLATFORM)
# ============================================
# #### State for dev platform layer. ####
# #### Depends on dev foundation state outputs. ####
# #### Run after foundation and before workloads. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "dev/platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
