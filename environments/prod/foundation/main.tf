module "networking" {
  source      = "../../../modules/networking"
  environment = var.environment
  vpc_cidr    = var.vpc_cidr
}

module "ecs_cluster" {
  source      = "../../../modules/compute-ecs-cluster"
  environment = var.environment
}
