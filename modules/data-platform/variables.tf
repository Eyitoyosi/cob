variable "name" {
  type        = string
  description = "Short identifier, e.g. 'sales-analytics'"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "data_bucket_id" {
  type        = string
  description = "Name of the existing S3 bucket (from storage-s3) holding the source data"
}

variable "data_bucket_arn" {
  type = string
}

variable "data_s3_prefix" {
  type        = string
  default     = ""
  description = "Prefix within the data bucket the crawler should scan, e.g. 'orders/'"
}

variable "create_crawler" {
  type    = bool
  default = true
}

variable "crawler_schedule" {
  type        = string
  default     = null
  description = "Optional cron expression, e.g. 'cron(0 6 * * ? *)'. Runs on-demand only if unset."
}

variable "tags" {
  type    = map(string)
  default = {}
}