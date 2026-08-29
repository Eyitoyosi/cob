variable "name" {
  type        = string
  description = "Short identifier for this database, e.g. 'orders-db'"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "database_subnet_group_name" {
  type        = string
  description = "From the networking module's output"
}

variable "vpc_id" {
  type = string
}

variable "allowed_security_group_ids" {
  type        = list(string)
  description = "Security groups (e.g. from compute-ecs-service) permitted to connect. Never opened by CIDR."
}

variable "engine" {
  type    = string
  default = "postgres"
}

variable "engine_version" {
  type    = string
  default = "16.3"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  type        = bool
  default     = null
  description = "Defaults to true in prod, false in dev, when left unset"
}

variable "kms_key_arn" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}