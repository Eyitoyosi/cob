data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  common_tags = merge(
    {
      Platform    = "COB"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "cob-vpc-${var.environment}"
  cidr = var.vpc_cidr

  azs = data.aws_availability_zones.available.names

  public_subnets   = [cidrsubnet(var.vpc_cidr, 8, 1), cidrsubnet(var.vpc_cidr, 8, 2), cidrsubnet(var.vpc_cidr, 8, 3)]
  private_subnets  = [cidrsubnet(var.vpc_cidr, 8, 11), cidrsubnet(var.vpc_cidr, 8, 12), cidrsubnet(var.vpc_cidr, 8, 13)]
  database_subnets = [cidrsubnet(var.vpc_cidr, 8, 21), cidrsubnet(var.vpc_cidr, 8, 22), cidrsubnet(var.vpc_cidr, 8, 23)]

  create_database_subnet_group = true

  # Cost-conscious: 1 NAT for dev, 1 per AZ for prod 
  enable_nat_gateway     = true
  single_nat_gateway     = var.environment != "prod"
  one_nat_gateway_per_az = var.environment == "prod"


  # Observability: required to actually debug "why can't X reach Y"
  enable_flow_log                      = true
  flow_log_destination_type            = "cloud-watch-logs"
  flow_log_max_aggregation_interval    = 60
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true

  # Secure by default: close the implicit "everything can talk to everything" hole
  manage_default_security_group  = true
  default_security_group_ingress = []
  default_security_group_egress  = []

  tags = local.common_tags
}

 # Free, keeps S3 traffic off the NAT gateway entirely
 # this was initially set enable_s3_endpoint = true. this is just for us to 
 # explicitly declare exactly which route tables get access.
data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.database_route_table_ids
  )

  tags = local.common_tags
}