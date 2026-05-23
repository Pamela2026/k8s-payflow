# ============================================
# FOUNDATION LOCALS (PROD)
# ============================================
# #### Standard naming and tags for prod foundation resources. ####

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = merge({
    Project     = var.project_name
    Environment = var.environment
  }, var.tags)
}
