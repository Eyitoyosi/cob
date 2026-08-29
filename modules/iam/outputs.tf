output "role_arn" {
  description = "ARN of the created IAM role"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the created IAM role"
  value       = aws_iam_role.this.name
}

output "policy_arn" {
  description = "ARN of the permission policy attached to the role"
  value       = aws_iam_policy.this.arn
}

output "instance_profile_name" {
  description = "Instance profile name, set only when trusted_service is ec2.amazonaws.com; null otherwise"
  value       = try(aws_iam_instance_profile.this[0].name, null)
}