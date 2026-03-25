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
