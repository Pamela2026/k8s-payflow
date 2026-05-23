# ============================================
# BOOTSTRAP VARIABLES
# ============================================
# #### Inputs for state bucket, region, and lock table. ####
# #### state_bucket_name must be globally unique. ####

variable "region" {
  description = "AWS region for bootstrap resources."
  type        = string
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state."
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking."
  type        = string
}

variable "force_destroy" {
  description = "Whether to allow destroying the state bucket with objects inside."
  type        = bool
}
