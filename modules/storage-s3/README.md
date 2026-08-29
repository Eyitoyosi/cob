# storage-s3

Provisions a standardized, secure-by-default S3 bucket: encryption at
rest, versioning with automatic old-version cleanup, blocked public
access, and enforced TLS-only access. Not a thin wrapper around
`aws_s3_bucket` — see docs/architecture.md for why that distinction
matters.

## Usage
    module "uploads" {
      source      = "../../modules/storage-s3"
      name        = "checkout-uploads"
      environment = "dev"
    }

## Inputs
| Name | Type | Default | Description |
|---|---|---|---|
| name | string | — | Short bucket purpose identifier |
| environment | string | — | `dev` or `prod` |
| versioning_enabled | bool | true | Protects against accidental delete/overwrite |
| kms_key_arn | string | null | Customer-managed key; falls back to SSE-S3 |
| lifecycle_expiration_days | number | null | Auto-expire current objects |
| noncurrent_version_expiration_days | number | 90 | Cleans up old versions |

## Outputs
| Name | Description |
|---|---|
| bucket_id | Bucket name |
| bucket_arn | For use in IAM policy resources elsewhere |
| bucket_regional_domain_name | Hostname, for services like Glue/CloudFront |

## Security notes
- Public access is always blocked; there is no override.
- Access control (who can read/write) is intentionally **not** handled
  here — grant permissions via the `iam` module's `policy_statements`.

## Known limitations
- Single-region only; no cross-region replication in v1.