variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "db_secret" {
  description = "DB secret payload."
  type = object({
    host     = string
    port     = number
    name     = string
    username = string
    password = string
  })
}

variable "mq_secret" {
  description = "MQ secret payload."
  type = object({
    endpoint = string
    username = string
    password = string
  })
}

variable "jwt_secret" {
  description = "JWT secret value."
  type        = string
  sensitive   = true
}
