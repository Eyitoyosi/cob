locals {
  resource_name = "cob-${var.environment}-${var.name}"

  common_tags = merge(
    { Platform = "COB", Environment = var.environment, ManagedBy = "Terraform" },
    var.tags
  )
}

resource "aws_security_group" "this" {
  name_prefix = "${local.resource_name}-"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/cob/${var.environment}/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

# Execution role: pulls the image, ships logs. App code never uses this.
module "execution_role" {
  source          = "../iam"
  name            = "${var.name}-exec"
  environment     = var.environment
  trusted_service = "ecs-tasks.amazonaws.com"

  policy_statements = [{
    sid    = "AllowImagePullAndLogging"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }]
}

# Task role: what the application code itself is allowed to do at runtime.
module "task_role" {
  source            = "../iam"
  name              = var.name
  environment       = var.environment
  trusted_service   = "ecs-tasks.amazonaws.com"
  policy_statements = var.policy_statements
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.resource_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = module.execution_role.role_arn
  task_role_arn             = module.task_role.role_arn

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.container_image
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.name
        }
      }
    }
  ])

  tags = local.common_tags
}

data "aws_region" "current" {}

resource "aws_ecs_service" "this" {
  name            = local.resource_name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.this.id]
  }

  tags = local.common_tags
}