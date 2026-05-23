# ============================================
# FOUNDATION LOCALS (DEV)
# ============================================
# #### Standard naming and tags for dev foundation resources. ####

locals {
  name_prefix = "${var.project_name}-${var.environment}"

  azs = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, 3)

  tags = merge({
    Project     = var.project_name
    Environment = var.environment
  }, var.tags)
}
