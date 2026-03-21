provider "aws" {
  region = var.region

  dynamic "assume_role" {
    for_each = var.admin_role_arn == null ? [] : [var.admin_role_arn]
    content {
      role_arn     = assume_role.value
      session_name = "terraform-platform"
    }
  }
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}
