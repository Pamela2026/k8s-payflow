variable "enable_alb_cert" {
  description = "Whether to request an ACM cert for the ALB."
  type        = bool
  default     = false
}

variable "alb_cert_domain" {
  description = "Domain name for the ALB certificate."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the ALB certificate domain."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID used for the ALB origin security group."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to supported resources."
  type        = map(string)
  default     = {}
}
