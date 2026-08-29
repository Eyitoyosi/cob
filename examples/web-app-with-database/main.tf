
module "networking" {
  source      = "../../modules/networking"
  environment = "dev"
  vpc_cidr    = "10.99.0.0/16"
}

module "ecs_cluster" {
  source      = "../../modules/compute-ecs-cluster"
  environment = "dev"
  name        = "example"
}

module "uploads_bucket" {
  source      = "../../modules/storage-s3"
  name        = "example-uploads"
  environment = "dev"
}

module "orders_db" {
  source                      = "../../modules/database-rds"
  name                         = "example-orders"
  environment                  = "dev"
  vpc_id                       = module.networking.vpc_id
  database_subnet_group_name   = module.networking.database_subnet_group_name
  allowed_security_group_ids   = [module.api_service.security_group_id]
}

module "api_service" {
  source           = "../../modules/compute-ecs-service"
  name             = "example-api"
  environment      = "dev"
  cluster_arn      = module.ecs_cluster.cluster_arn
  vpc_id           = module.networking.vpc_id
  subnet_ids       = module.networking.private_subnet_ids
  container_image  = "public.ecr.aws/nginx/nginx:latest"
  container_port   = 80

  policy_statements = [
    {
      sid       = "ReadWriteUploads"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:PutObject"]
      resources = ["${module.uploads_bucket.bucket_arn}/*"]
    }
  ]
}