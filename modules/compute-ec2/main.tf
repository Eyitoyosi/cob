locals {
  resource_name = "cob-${var.environment}-${var.name}"

  common_tags = merge(
    {
      Platform    = "COB"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

data "aws_ami" "amazon_linux" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, try(data.aws_ami.amazon_linux[0].id, null))
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
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

module "role" {
  source          = "../iam"
  name            = var.name
  environment     = var.environment
  trusted_service = "ec2.amazonaws.com"

  policy_statements = concat(
    var.policy_statements,
    [{
      sid    = "AllowSSMSessionManager"
      effect = "Allow"
      actions = [
        "ssmmessages:*",
        "ssm:UpdateInstanceInformation",
        "ec2messages:*",
      ]
      resources = ["*"]
    }]
  )
}

resource "aws_launch_template" "this" {
  name_prefix   = "${local.resource_name}-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  user_data     = var.user_data != null ? base64encode(var.user_data) : null

  iam_instance_profile {
    name = module.role.instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.this.id]

  # Secure by default, non-negotiable: blocks the SSRF-to-credential-theft path
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint                = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted   = true
      volume_size = 20
      volume_type = "gp3"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = local.resource_name })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name_prefix         = "${local.resource_name}-"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = local.resource_name
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}