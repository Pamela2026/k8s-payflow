variable "name_prefix" {
  description = "Prefix used for naming resources."
  type        = string
}

variable "tags" {
  description = "Base tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "VPC ID for the broker security group."
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the broker."
  type        = list(string)
}

variable "allowed_sg_ids" {
  description = "Security group IDs allowed to access the broker."
  type        = list(string)
}

variable "username" {
  description = "Broker username."
  type        = string
}

variable "password" {
  description = "Broker password."
  type        = string
  sensitive   = true
}

variable "deployment_mode" {
  description = "RabbitMQ deployment mode."
  type        = string
  default     = "SINGLE_INSTANCE"
}

variable "engine_version" {
  description = "RabbitMQ engine version."
  type        = string
  default     = "3.12.13"
}

variable "host_instance_type" {
  description = "Broker instance type."
  type        = string
}
