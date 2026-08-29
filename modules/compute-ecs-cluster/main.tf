variable "name" {
  type    = string
  default = "primary"
}

variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  common_tags = merge(
    { Platform = "COB", Environment = var.environment, ManagedBy = "Terraform" },
    var.tags
  )
}

resource "aws_ecs_cluster" "this" {
  name = "cob-${var.environment}-${var.name}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.common_tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  value = aws_ecs_cluster.this.name
}