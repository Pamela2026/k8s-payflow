# ============================================
# BACKEND STATE (PROD / PLATFORM ADDONS)
# ============================================
# #### State for prod platform add-ons (Helm). ####
# #### Depends on prod platform-infra outputs. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "prod/platform-addons/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
