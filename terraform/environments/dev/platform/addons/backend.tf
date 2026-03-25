# ============================================
# BACKEND STATE (DEV / PLATFORM ADDONS)
# ============================================
# #### State for dev platform add-ons (Helm). ####
# #### Depends on dev platform-infra state outputs. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "dev/platform-addons/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
