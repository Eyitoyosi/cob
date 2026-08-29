locals {
  role_name = "cob-${var.environment}-${var.name}"

  common_tags = merge(
    {
      Platform    = "COB"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# 1. Trust policy — who can assume this role
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [var.trusted_service]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = local.common_tags
}

# 2. Permission policy — what the role can actually do
data "aws_iam_policy_document" "permissions" {
  dynamic "statement" {
    for_each = var.policy_statements
    content {
      sid       = statement.value.sid
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_policy" "this" {
  name   = "${local.role_name}-permissions"
  policy = data.aws_iam_policy_document.permissions.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.this.arn
}

resource "aws_iam_instance_profile" "this" {
  count = var.trusted_service == "ec2.amazonaws.com" ? 1 : 0

  name = local.role_name
  role = aws_iam_role.this.name
  tags = local.common_tags
}