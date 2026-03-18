# ============================================
# BACKEND STATE (PROD / FOUNDATION)
# ============================================
# #### State for prod foundation layer. ####
# #### Depends on terraform/bootstrap (S3 bucket + DynamoDB table). ####
# #### Run before platform and workloads. ####

terraform {
  backend "s3" {
    bucket         = "payflow-tfstate-003"
    key            = "prod/foundation/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "payflow-tfstate-lock"
    encrypt        = true
  }
}
