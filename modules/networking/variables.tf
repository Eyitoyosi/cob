variable "environment" {
  type        = string
  description = "The deployment environment"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "The primary CIDR block for the VPC"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid CIDR block, e.g. 10.0.0.0/16."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags merged onto every networking resource"
  default     = {}
}