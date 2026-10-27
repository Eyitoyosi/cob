locals {
  bucket_name   = "cob-${var.environment}-${var.name}"
  sse_algorithm = var.kms_key_arn != null ? "aws:kms" : "AES256"

  common_tags = merge(
    {
      Platform    = "COB"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

resource "aws_s3_bucket" "this" {
  bucket = local.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = local.sse_algorithm
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Created whenever there's something to clean up: an explicit expiration,
# or old versions piling up from versioning being on.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.lifecycle_expiration_days != null || var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "cob-lifecycle"
    status = "Enabled"

    filter {}

    dynamic "expiration" {
      for_each = var.lifecycle_expiration_days != null ? [1] : []
      content {
        days = var.lifecycle_expiration_days
      }
    }

    dynamic "noncurrent_version_expiration" {
      for_each = var.versioning_enabled ? [1] : []
      content {
        noncurrent_days = var.noncurrent_version_expiration_days
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# TLS enforcement is unconditional — every bucket gets this, no opt-out.
data "aws_iam_policy_document" "enforce_tls" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.enforce_tls.json

  # S3 can reject a policy and a public-access block applied at the same
  # moment, so apply them one after the other.
  depends_on = [aws_s3_bucket_public_access_block.this]
}