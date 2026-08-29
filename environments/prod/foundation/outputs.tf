output "vpc_id" {
  value = module.networking.vpc_id
}

output "vpc_cidr_block" {
  value = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "database_subnet_ids" {
  value = module.networking.database_subnet_ids
}

output "database_subnet_group_name" {
  value = module.networking.database_subnet_group_name
}

output "ecs_cluster_arn" {
  value = module.ecs_cluster.cluster_arn
}

output "ecs_cluster_name" {
  value = module.ecs_cluster.cluster_name
}
