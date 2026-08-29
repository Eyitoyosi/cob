variable "name" {
  type        = string
  description = "Short identifier for the bucket's purpose, e.g. 'checkout-data'"
}

variable "environment" {
  type        = string
  description = "Deployment environment"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "versioning_enabled" {
  type        = bool
  default     = true
  description = "Protects against accidental overwrite/delete. Disable only for genuinely disposable data."
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "Optional customer-managed KMS key ARN. Falls back to SSE-S3 (AES256) when unset."
}

variable "lifecycle_expiration_days" {
  type        = number
  default     = null
  description = "If set, current objects expire after this many days. Leave null to retain indefinitely."
}

variable "noncurrent_version_expiration_days" {
  type        = number
  default     = 90
  description = "Days to retain old versions of overwritten/deleted objects before permanent removal"
}

variable "tags" {
  type    = map(string)
  default = {}
}