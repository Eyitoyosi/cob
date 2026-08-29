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

module "orders_bucket" {
  source      = "../../../../modules/storage-s3"
  name        = "orders-raw"
  environment = "dev"
}

module "orders_db" {
  source                     = "../../../../modules/database-rds"
  name                       = "orders"
  environment                = "dev"
  vpc_id                     = local.foundation.vpc_id
  database_subnet_group_name = local.foundation.database_subnet_group_name
  allowed_security_group_ids = [module.ingestion_service.security_group_id]
}

module "ingestion_service" {
  source          = "../../../../modules/compute-ecs-service"
  name            = "ingestion"
  environment     = "dev"
  cluster_arn     = local.foundation.ecs_cluster_arn
  vpc_id          = local.foundation.vpc_id
  subnet_ids      = local.foundation.private_subnet_ids
  container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/ingestion:latest"
  container_port  = 8080
}


output "orders_bucket_id" {
  value = module.orders_bucket.bucket_id
}

output "orders_bucket_arn" {
  value = module.orders_bucket.bucket_arn
}
