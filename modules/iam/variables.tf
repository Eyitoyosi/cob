variable "name" {
  type        = string
  description = "Short identifier for this role, e.g. 'checkout-service'"
}

variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "trusted_service" {
  type        = string
  description = "AWS service principal allowed to assume this role"

  validation {
    condition     = contains(["ec2.amazonaws.com", "ecs-tasks.amazonaws.com"], var.trusted_service)
    error_message = "trusted_service must be one of the supported principals: ec2.amazonaws.com, ecs-tasks.amazonaws.com."
  }
}

variable "policy_statements" {
  description = "Permission statements this role needs. Kept intentionally simple: no conditions or NotAction."
  type = list(object({
    sid       = string
    effect    = string # "Allow" or "Deny"
    actions   = list(string)
    resources = list(string)
  }))
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags merged onto every IAM resource"
}