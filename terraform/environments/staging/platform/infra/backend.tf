# ============================================
# BACKEND STATE (STAGING / PLATFORM)
# ============================================
# #### State for staging platform layer. ####
# #### Depends on staging foundation state outputs. ####
# #### Run after foundation and before workloads. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "staging/platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
