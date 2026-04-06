provider "aws" {
  region = var.region

  # NOTE: Assume role disabled for local runs. Re-enable if local creds can assume.
  # dynamic "assume_role" {
  #   for_each = var.admin_role_arn == null ? [] : [var.admin_role_arn]
  #   content {
  #     role_arn     = assume_role.value
  #     session_name = "terraform-platform"
  #   }
  # }
}
