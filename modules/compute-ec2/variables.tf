variable "name" {
  type        = string
  description = "Short identifier for this workload, e.g. 'checkout-api'"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "vpc_id" {
  type        = string
  description = "VPC ID, from the networking module's output"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs, from the networking module's output"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "ami_id" {
  type        = string
  default     = null
  description = "Override AMI. Defaults to latest Amazon Linux 2023 when unset."
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "ingress_rules" {
  description = "Inbound rules this workload needs. No implicit open ports."
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = []
}

variable "policy_statements" {
  description = "Extra IAM permissions this workload's instances need, beyond SSM access"
  type = list(object({
    sid       = string
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "user_data" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}