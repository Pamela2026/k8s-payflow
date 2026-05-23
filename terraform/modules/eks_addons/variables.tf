variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
}

variable "region" {
  description = "AWS region for the EKS cluster."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EKS cluster."
  type        = string
}

variable "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller."
  type        = string
}

variable "external_secrets_role_arn" {
  description = "IAM role ARN for External Secrets."
  type        = string
}

variable "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler."
  type        = string
}

variable "enable_prometheus" {
  description = "Whether to install Prometheus via Helm."
  type        = bool
  default     = true
}

variable "enable_grafana" {
  description = "Whether to install Grafana via Helm."
  type        = bool
  default     = true
}

variable "enable_loki" {
  description = "Whether to install Loki via Helm."
  type        = bool
  default     = true
}

variable "enable_promtail" {
  description = "Whether to install Promtail via Helm."
  type        = bool
  default     = true
}

variable "enable_postgres_exporter" {
  description = "Whether to install Prometheus Postgres exporter via Helm."
  type        = bool
  default     = false
}

variable "enable_kubecost" {
  description = "Whether to install Kubecost for cost visibility."
  type        = bool
  default     = true
}

variable "prometheus_values_path" {
  description = "Path to Prometheus Helm values file."
  type        = string
  default     = ""
}

variable "grafana_values_path" {
  description = "Path to Grafana Helm values file."
  type        = string
  default     = ""
}

variable "loki_values_path" {
  description = "Path to Loki Helm values file."
  type        = string
  default     = ""
}

variable "promtail_values_path" {
  description = "Path to Promtail Helm values file."
  type        = string
  default     = ""
}

variable "postgres_exporter_values_path" {
  description = "Path to Postgres exporter Helm values file."
  type        = string
  default     = ""
}

variable "kubecost_values_path" {
  description = "Path to Kubecost Helm values file."
  type        = string
  default     = ""
}
