# ============================================
# FOUNDATION VERSIONS (STAGING)
# ============================================
# #### Terraform and provider constraints for the staging foundation layer. ####

terraform {
  required_version = ">= 1.5.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

provider "aws" {
  region = var.region
}
