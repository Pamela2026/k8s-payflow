variable "enabled" {
  description = "Whether to enable CloudFront + Route53 for the app domain."
  type        = bool
  default     = false
}

variable "app_domain" {
  description = "Root application domain (e.g., computehub.online)."
  type        = string
  default     = null
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the app domain."
  type        = string
  default     = null
}

variable "alb_dns_name" {
  description = "ALB DNS name to use as CloudFront origin."
  type        = string
  default     = null
}

variable "comment" {
  description = "CloudFront distribution comment."
  type        = string
  default     = "Payflow app distribution"
}

variable "origin_protocol_policy" {
  description = "Origin protocol policy."
  type        = string
  default     = "http-only"
}

variable "origin_ssl_protocols" {
  description = "TLS protocols for the origin."
  type        = list(string)
  default     = ["TLSv1.2"]
}

variable "allowed_methods" {
  description = "Allowed HTTP methods."
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
}

variable "cached_methods" {
  description = "Cached HTTP methods."
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]
}

variable "viewer_protocol_policy" {
  description = "Viewer protocol policy."
  type        = string
  default     = "redirect-to-https"
}

variable "cache_policy_id" {
  description = "Managed cache policy ID."
  type        = string
  default     = "658327ea-f89d-4fab-a63d-7e88639e58f6"
}

variable "origin_request_policy_id" {
  description = "Managed origin request policy ID."
  type        = string
  default     = "88a5eaf4-2fd4-4709-b370-b4c650ea3fcf"
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default     = {}
}
