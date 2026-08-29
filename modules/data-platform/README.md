# data-platform

Makes data already sitting in an S3 bucket (from `storage-s3`)
queryable by analytics users via AWS Glue Data Catalog and Amazon
Athena — without ever granting those users direct S3 permissions.
Glue/Athena become the access boundary, so "who queried what" is
answerable from Athena's query history rather than reconstructed from
S3 access logs.

Provisions its own query-results bucket by calling `storage-s3`
internally, rather than duplicating its security defaults.

## Usage
    module "orders_catalog" {
      source          = "../../modules/data-platform"
      name            = "orders"
      environment     = "dev"
      data_bucket_id  = module.orders_bucket.bucket_id
      data_bucket_arn = module.orders_bucket.bucket_arn
      data_s3_prefix  = "orders/"
    }

## Inputs
| Name | Type | Default | Description |
|---|---|---|---|
| name | string | — | Catalog identifier |
| environment | string | — | `dev` or `prod` |
| data_bucket_id / data_bucket_arn | string | — | The existing source bucket, from `storage-s3` |
| data_s3_prefix | string | `""` | Prefix the crawler scans |
| create_crawler | bool | `true` | |
| crawler_schedule | string | `null` | Cron expression; on-demand only if unset |
| tags | map(string) | `{}` | |

## Outputs
| Name | Description |
|---|---|
| glue_database_name | |
| glue_database_arn | |
| athena_workgroup_name | |
| results_bucket_arn | |

## Security notes
- Analysts are granted Athena/Glue query permissions, never `s3:Get*`
  on the source bucket directly — access is mediated entirely through
  the catalog and workgroup.
- Query results land in a dedicated bucket with a 30-day lifecycle —
  results are treated as transient, not a data store of record.

## Known limitations
- One crawler per module call, S3-target only — no JDBC or DynamoDB
  crawler targets in v1.
- No column-level or row-level access control (AWS Lake Formation)
  yet — out of scope for v1; current access boundary is table-level.