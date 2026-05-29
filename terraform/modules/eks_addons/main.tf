## EKS cluster data (for kubeconfig). ##
data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
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

## Default gp2 StorageClass for EBS CSI driver. ##
resource "kubernetes_manifest" "gp2" {
  manifest = {
    apiVersion = "storage.k8s.io/v1"
    kind       = "StorageClass"
    metadata = {
      name = "gp2"
      annotations = {
        "storageclass.kubernetes.io/is-default-class" = "true"
      }
    }
    provisioner          = "ebs.csi.aws.com"
    volumeBindingMode    = "WaitForFirstConsumer"
    allowVolumeExpansion = true
    parameters = {
      type      = "gp2"
      encrypted = "true"
    }
  }

  # Force Terraform to overwrite the fields managed by the EKS default installer
  field_manager {
    force_conflicts = true
  }
}

## AWS Load Balancer Controller (Helm). ##
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.alb_controller_role_arn
  }
}

## External Secrets (Helm). ##
resource "helm_release" "external_secrets" {
  depends_on = [helm_release.alb_controller]
  name       = "external-secrets"
  namespace  = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"

  create_namespace = true

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "external-secrets"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.external_secrets_role_arn
  }
}

## Metrics Server (Helm). ##
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
}

## Cluster Autoscaler (Helm). ##
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  namespace  = "kube-system"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = "true"
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.cluster_autoscaler_role_arn
  }
}

## Prometheus (Helm). ##
resource "helm_release" "prometheus" {
  count            = var.enable_prometheus ? 1 : 0
  depends_on       = [helm_release.alb_controller, kubernetes_manifest.gp2, kubernetes_manifest.alertmanager_slack_secret]
  name             = "payflow-prometheus"
  namespace        = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  create_namespace = true
  values           = var.prometheus_values_path != "" ? [file(var.prometheus_values_path)] : []
}

## Grafana (Helm). ##
resource "helm_release" "grafana" {
  count            = var.enable_grafana ? 1 : 0
  depends_on       = [helm_release.alb_controller]
  name             = "payflow-grafana"
  namespace        = "monitoring"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  create_namespace = true
  values           = var.grafana_values_path != "" ? [file(var.grafana_values_path)] : []
}

## Loki (Helm). ##
resource "helm_release" "loki" {
  count            = var.enable_loki ? 1 : 0
  depends_on       = [helm_release.alb_controller, kubernetes_manifest.gp2]
  name             = "payflow-loki"
  namespace        = "monitoring"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  create_namespace = true
  values           = var.loki_values_path != "" ? [file(var.loki_values_path)] : []
}

## Promtail (Helm). ##
resource "helm_release" "promtail" {
  count            = var.enable_promtail ? 1 : 0
  depends_on       = [helm_release.alb_controller]
  name             = "payflow-promtail"
  namespace        = "monitoring"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  create_namespace = true
  values           = var.promtail_values_path != "" ? [file(var.promtail_values_path)] : []
}

## Postgres Exporter (Helm). ##
resource "helm_release" "postgres_exporter" {
  count            = var.enable_postgres_exporter ? 1 : 0
  depends_on       = [helm_release.alb_controller]
  name             = "payflow-postgres-exporter"
  namespace        = "monitoring"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-postgres-exporter"
  create_namespace = true
  values           = var.postgres_exporter_values_path != "" ? [file(var.postgres_exporter_values_path)] : []
}

## Kubecost (Helm). ##
resource "helm_release" "kubecost" {
  count            = var.enable_kubecost ? 1 : 0
  depends_on       = [helm_release.alb_controller, kubernetes_manifest.gp2]
  name             = "kubecost"
  namespace        = "kubecost"
  repository       = "https://kubecost.github.io/cost-analyzer/"
  chart            = "cost-analyzer"
  version          = "2.8.3"
  create_namespace = true
  values           = var.kubecost_values_path != "" ? [file(var.kubecost_values_path)] : []

  set {
    name  = "kubecostProductConfigs.clusterName"
    value = var.cluster_name
  }
}

## AWS SecretStore for External Secrets ##
resource "kubernetes_manifest" "aws_secretstore" {
  depends_on = [helm_release.external_secrets]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = "aws-secretsmanager"
      namespace = "monitoring"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = "us-east-1"
        }
      }
    }
  }
}

## Sync definition for Alertmanager Slack secret ##
resource "kubernetes_manifest" "alertmanager_slack_secret" {
  depends_on = [kubernetes_manifest.aws_secretstore]
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = "alertmanager-slack-sync"
      namespace = "monitoring"
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = "aws-secretsmanager"
        kind = "SecretStore"
      }
      target = {
        name = "alertmanager-slack" 
        creationPolicy = "Owner"
      }
      data = [
        {
          secretKey = "api-url"
          remoteRef = {
            key      = "dev/monitoring/alertmanager-slack" # Matches AWS Secrets Manager Name
            property = "api-url"
          }
        }
      ]
    }
  }
}
