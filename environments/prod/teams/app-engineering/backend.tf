terraform {
  backend "s3" {
    bucket         = "beejan-cob-terraform-main-state"
    key            = "prod/teams/app-engineering/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cob-terraform-locks"
    encrypt        = true
  }
}
