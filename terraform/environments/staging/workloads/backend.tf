# ============================================
# BACKEND STATE (STAGING / WORKLOADS)
# ============================================
# #### State for staging workloads layer. ####
# #### Depends on staging platform state outputs. ####
# #### Run after platform. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "staging/workloads/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
