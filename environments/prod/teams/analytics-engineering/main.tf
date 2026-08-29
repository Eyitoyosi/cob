data "terraform_remote_state" "data_engineering" {
  backend = "s3"
  config = {
    bucket = "beejan-cob-terraform-main-state"
    key    = "prod/teams/data-engineering/terraform.tfstate" 
    region = "us-east-1"
  }
}

module "orders_catalog" {
  source          = "../../../../modules/data-platform"
  name            = "orders"
  environment     = "prod"
  data_bucket_id  = data.terraform_remote_state.data_engineering.outputs.orders_bucket_id
  data_bucket_arn = data.terraform_remote_state.data_engineering.outputs.orders_bucket_arn
}

module "team_access" {
  source      = "../../../../modules/iam-team-access"
  team_name   = "analytics-engineering"
  environment = "prod"
  usernames   = ["kate.doe"]

  policy_statements = [
    {
      sid       = "QueryOrdersData"
      effect    = "Allow"
      actions   = ["athena:StartQueryExecution", "athena:GetQueryResults", "glue:GetTable", "glue:GetDatabase"]
      resources = ["*"]
    }
  ]
}
