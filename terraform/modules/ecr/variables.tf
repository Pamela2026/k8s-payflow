variable "repositories" {
  description = "ECR repository names to create."
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Whether to allow mutable tags."
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Enable image scanning on push."
  type        = bool
  default     = true
}

variable "lifecycle_policy_json" {
  description = "Lifecycle policy JSON for repositories."
  type        = string
  default     = <<JSON
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire untagged images after 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
JSON
}

variable "tags" {
  description = "Additional tags applied to all repositories."
  type        = map(string)
  default     = {}
}
