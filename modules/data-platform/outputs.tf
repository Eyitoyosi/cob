output "glue_database_name" {
  value = aws_glue_catalog_database.this.name
}

output "glue_database_arn" {
  value = aws_glue_catalog_database.this.arn
}

output "athena_workgroup_name" {
  value = aws_athena_workgroup.this.name
}

output "results_bucket_arn" {
  value = module.results_bucket.bucket_arn
}