# ============================================
# BACKEND STATE (DEV / EDGE)
# ============================================
# #### State for dev edge layer (WAF/CDN). ####
# #### Run after workloads and ingress ALB exists. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "dev/edge/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
