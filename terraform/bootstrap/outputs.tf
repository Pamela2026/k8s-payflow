# ============================================
# BOOTSTRAP OUTPUTS
# ============================================
# #### Use these values to configure env backend.tf files. ####

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state."
  value       = aws_s3_bucket.tfstate.bucket
}

output "lock_table_name" {
  description = "DynamoDB table name for state locking."
  value       = aws_dynamodb_table.tfstate_lock.name
}

output "kms_key_arn" {
  description = "KMS key ARN used to encrypt the Terraform state bucket."
  value       = aws_kms_key.tfstate.arn
}
