locals {
  identifier = "cob-${var.environment}-${var.name}"

  common_tags = merge(
    { Platform = "COB", Environment = var.environment, ManagedBy = "Terraform" },
    var.tags
  )
}

resource "aws_glue_catalog_database" "this" {
  name = replace(local.identifier, "-", "_") # Glue database names disallow hyphens
}

module "crawler_role" {
  count           = var.create_crawler ? 1 : 0
  source          = "../iam"
  name            = "${var.name}-crawler"
  environment     = var.environment
  trusted_service = "glue.amazonaws.com"

  policy_statements = [
    {
      sid       = "ReadSourceData"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = [var.data_bucket_arn, "${var.data_bucket_arn}/*"]
    },
    {
      sid    = "ManageCatalogEntries"
      effect = "Allow"
      actions = [
        "glue:GetDatabase", "glue:GetTable", "glue:GetTables",
        "glue:CreateTable", "glue:UpdateTable",
        "glue:BatchCreatePartition", "glue:GetPartitions",
      ]
      resources = ["*"]
    },
    {
      sid       = "WriteCrawlerLogs"
      effect    = "Allow"
      actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      resources = ["arn:aws:logs:*:*:log-group:/aws-glue/*"]
    },
  ]
}

resource "aws_glue_crawler" "this" {
  count         = var.create_crawler ? 1 : 0
  name          = "${local.identifier}-crawler"
  database_name = aws_glue_catalog_database.this.name
  role          = module.crawler_role[0].role_arn
  schedule      = var.crawler_schedule

  s3_target {
    path = "s3://${var.data_bucket_id}/${var.data_s3_prefix}"
  }

  tags = local.common_tags
}

# Query results need somewhere to land — reuse storage-s3 rather than
# hand-rolling a bucket here. Short retention: results are transient.
module "results_bucket" {
  source                    = "../storage-s3"
  name                       = "${var.name}-athena-results"
  environment                = var.environment
  versioning_enabled         = false
  lifecycle_expiration_days  = 30
  tags                       = var.tags
}

resource "aws_athena_workgroup" "this" {
  name = local.identifier

  configuration {
    enforce_workgroup_configuration = true

    result_configuration {
      output_location = "s3://${module.results_bucket.bucket_id}/"

      encryption_configuration {
        encryption_option = "SSE_S3"
      }
    }
  }

  tags = local.common_tags
}