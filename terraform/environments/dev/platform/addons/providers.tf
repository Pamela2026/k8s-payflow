provider "aws" {
  region = var.region

  dynamic "assume_role" {
    for_each = var.admin_role_arn == null ? [] : [var.admin_role_arn]
    content {
      role_arn     = assume_role.value
      session_name = "terraform-platform-addons"
    }
  }
}

data "aws_eks_cluster" "this" {
  name = data.terraform_remote_state.platform.outputs.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.platform.outputs.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
