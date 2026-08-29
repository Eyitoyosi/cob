variable "environment" {
  type        = string
  description = "The deployment environment name (e.g., dev, prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "The primary CIDR block for the VPC"
}

variable "aws_region"  { type = string, default = "us-east-1" }