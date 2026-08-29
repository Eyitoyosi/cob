data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "beejan-cob-terraform-main-state"
    key    = "dev/foundation/terraform.tfstate"
    region = "us-east-1"
  }
}

locals {
  foundation = data.terraform_remote_state.foundation.outputs
}

module "uploads_bucket" {
  source      = "../../../../modules/storage-s3"
  name        = "checkout-uploads"
  environment = "dev"
}

module "checkout_service" {
  source           = "../../../../modules/compute-ecs-service"
  name             = "checkout-api"
  environment      = "dev"
  cluster_arn      = local.foundation.ecs_cluster_arn
  vpc_id           = local.foundation.vpc_id
  subnet_ids       = local.foundation.private_subnet_ids
  container_image  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/checkout-api:latest" # Chage to dev when ready
  container_port   = 8080

  policy_statements = [
    {
      sid       = "ReadWriteUploads"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = ["${module.uploads_bucket.bucket_arn}/*"]
    }
  ]
}

module "team_access" {
  source      = "../../../../modules/iam-team-access"
  team_name   = "app-engineering"
  environment = "dev"
  usernames   = ["toyosi.alabi"]

  policy_statements = [
    {
      sid       = "ReadUploadsForDebugging"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = [module.uploads_bucket.bucket_arn, "${module.uploads_bucket.bucket_arn}/*"]
    }
  ]
}