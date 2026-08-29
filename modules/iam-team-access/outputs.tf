output "group_name" {
  value = aws_iam_group.this.name
}

output "group_arn" {
  value = aws_iam_group.this.arn
}

output "user_names" {
  value = [for u in aws_iam_user.this : u.name]
}

output "user_arns" {
  value = [for u in aws_iam_user.this : u.arn]
}