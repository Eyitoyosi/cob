output "bucket_id" {
  description = "Bucket name/ID"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Bucket ARN, for use in IAM policy resources elsewhere"
  value       = aws_s3_bucket.this.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name, for services (e.g. CloudFront, Glue) that need a hostname"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
