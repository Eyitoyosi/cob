locals {
  group_name = "cob-${var.environment}-${var.team_name}"

  common_tags = merge(
    {
      Platform    = "COB"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_iam_group" "this" {
  name = local.group_name
}

resource "aws_iam_user" "this" {
  for_each = toset(var.usernames)
  name     = each.value
  tags     = local.common_tags
  # No login profile, no access keys created here — see module README:
  # credentials are issued out-of-band by an account admin.
}

resource "aws_iam_group_membership" "this" {
  name  = "${local.group_name}-membership"
  group = aws_iam_group.this.name
  users = [for u in aws_iam_user.this : u.name]
}

# Team-specific permissions
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

resource "aws_iam_policy" "permissions" {
  name   = "${local.group_name}-permissions"
  policy = data.aws_iam_policy_document.permissions.json
}

resource "aws_iam_group_policy_attachment" "permissions" {
  group      = aws_iam_group.this.name
  policy_arn = aws_iam_policy.permissions.arn
}

# MFA enforcement policy
# This policy allows users to manage their own password and MFA device, but denies all other actions unless MFA is present.'
data "aws_iam_policy_document" "mfa_enforcement" {
  statement {
    sid       = "AllowViewAccountInfo"
    effect    = "Allow"
    actions   = ["iam:GetAccountPasswordPolicy", "iam:ListVirtualMFADevices"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowManageOwnPasswordAndMFA"
    effect = "Allow"
    actions = [
      "iam:ChangePassword",
      "iam:GetUser",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:DeactivateMFADevice",
      "iam:DeleteVirtualMFADevice",
    ]
    resources = [
      "arn:aws:iam::*:user/$${aws:username}",
      "arn:aws:iam::*:mfa/$${aws:username}",
    ]
  }

  statement {
    sid       = "DenyEverythingElseWithoutMFA"
    effect    = "Deny"
    not_actions = [
      "iam:ChangePassword",
      "iam:GetUser",
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
      "iam:ListVirtualMFADevices",
      "iam:GetAccountPasswordPolicy",
    ]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "mfa_enforcement" {
  name   = "${local.group_name}-require-mfa"
  policy = data.aws_iam_policy_document.mfa_enforcement.json
}

resource "aws_iam_group_policy_attachment" "mfa_enforcement" {
  group      = aws_iam_group.this.name
  policy_arn = aws_iam_policy.mfa_enforcement.arn
}