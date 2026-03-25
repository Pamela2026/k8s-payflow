# ============================================
# BACKEND STATE (STAGING / PLATFORM ADDONS)
# ============================================
# #### State for staging platform add-ons (Helm). ####
# #### Depends on staging platform-infra outputs. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "staging/platform-addons/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
