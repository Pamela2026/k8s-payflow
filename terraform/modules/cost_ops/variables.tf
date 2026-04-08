# ============================================
# COST OPS VARIABLES
# ============================================

variable "name_prefix" {
  description = "Prefix for cost ops resources."
  type        = string
}

variable "tags" {
  description = "Tags to apply to supported resources."
  type        = map(string)
  default     = {}
}

variable "enable_cost_ops" {
  description = "Whether to enable AWS cost operations (budgets + anomaly detection)."
  type        = bool
  default     = false
}

variable "budget_amount" {
  description = "Monthly cost budget amount."
  type        = number
  default     = 500
}

variable "budget_unit" {
  description = "Budget currency unit."
  type        = string
  default     = "USD"
}

variable "budget_email_addresses" {
  description = "Email addresses for budget alerts."
  type        = list(string)
  default     = []

}

variable "anomaly_threshold" {
  description = "Anomaly detection threshold in USD."
  type        = number
  default     = 100
}

variable "anomaly_frequency" {
  description = "Anomaly subscription frequency."
  type        = string
  default     = "DAILY"
}

variable "anomaly_email_addresses" {
  description = "Email addresses for anomaly detection alerts."
  type        = list(string)
  default     = []

}
