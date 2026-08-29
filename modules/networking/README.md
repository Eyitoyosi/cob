# networking

Provisions the standard AWS network foundation: a VPC with public,
private, and database subnet tiers across all available AZs, NAT
gateways (cost-optimized per environment), an S3 gateway endpoint,
VPC flow logs, and a locked-down default security group.

Built on `terraform-aws-modules/vpc/aws` rather than hand-rolled
subnet/route-table resources — reinventing that module would be pure
maintenance burden with no abstraction benefit.

## Usage
    module "networking" {
      source      = "../../modules/networking"
      environment = "dev"
      vpc_cidr    = "10.0.0.0/16"
    }

## Inputs
| Name | Type | Default | Description |
|---|---|---|---|
| environment | string | — | `dev` or `prod` |
| vpc_cidr | string | — | Primary CIDR block, e.g. `10.0.0.0/16` |
| tags | map(string) | `{}` | Extra tags merged onto every resource |

## Outputs
| Name | Description |
|---|---|
| vpc_id | VPC ID |
| vpc_cidr_block | VPC CIDR, for security group rules elsewhere |
| public_subnet_ids | For internet-facing resources (ALBs) |
| private_subnet_ids | For application workloads (EC2, ECS) |
| database_subnet_ids | For RDS |
| database_subnet_group_name | For the `database-rds` module |

## Security notes
- The default VPC security group is explicitly locked to deny all
  ingress/egress — nothing relies on its default (and historically
  inconsistent) behavior.
- Flow logs are always enabled to CloudWatch Logs; there is no opt-out.
- Private subnets route to S3 via a gateway endpoint, not the NAT
  gateway — cheaper and keeps that traffic off the public internet path.

## Known limitations
- Single-region only. No Transit Gateway or VPC peering in v1.
- NAT topology (`single_nat_gateway` vs one-per-AZ) is derived
  automatically from `environment` and isn't independently overridable
  yet — a deliberate v1 simplification, not an oversight.