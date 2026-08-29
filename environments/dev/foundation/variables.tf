variable "environment" {
  type        = string
  description = "The name of the environment (e.g., dev, prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC network"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "The AWS region to deploy into"
}