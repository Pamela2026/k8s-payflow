provider "aws" {
  region = var.region

  dynamic "assume_role" {
    for_each = var.admin_role_arn == null ? [] : [var.admin_role_arn]
    content {
      role_arn     = assume_role.value
      session_name = "terraform-workloads"
    }
  }
}

