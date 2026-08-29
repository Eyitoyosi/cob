# compute-ecs-service

Reusable Fargate service: security group, CloudWatch log group, and
**two separate IAM roles** — an execution role (used by the ECS agent
to pull the image and ship logs; application code never touches this)
and a task role (used by the running application at runtime, scoped to
exactly what `policy_statements` grants). Registers into the shared
cluster from `compute-ecs-cluster`.

## Usage
    module "checkout_service" {
      source           = "../../modules/compute-ecs-service"
      name             = "checkout-api"
      environment      = "dev"
      cluster_arn      = module.ecs_cluster.cluster_arn
      vpc_id           = module.networking.vpc_id
      subnet_ids       = module.networking.private_subnet_ids
      container_image  = "123456789012.dkr.ecr.us-east-1.amazonaws.com/checkout-api:latest"
      container_port   = 8080

      policy_statements = [
        {
          sid       = "ReadWriteUploads"
          effect    = "Allow"
          actions   = ["s3:GetObject", "s3:PutObject"]
          resources = ["arn:aws:s3:::cob-dev-checkout-uploads/*"]
        }
      ]
    }

## Inputs
| Name | Type | Default | Description |
|---|---|---|---|
| name | string | — | Service identifier |
| environment | string | — | `dev` or `prod` |
| cluster_arn | string | — | From `compute-ecs-cluster` output |
| vpc_id / subnet_ids | string / list(string) | — | From `networking` output |
| container_image | string | — | Full image URI |
| container_port | number | — | |
| cpu / memory | number | `256`/`512` | Fargate task sizing |
| desired_count | number | `1` | |
| ingress_rules | list(object) | `[]` | |
| policy_statements | list(object) | `[]` | Task role only — never affects the execution role |
| log_retention_days | number | `30` | |
| tags | map(string) | `{}` | |

## Outputs
| Name | Description |
|---|---|
| service_name | |
| security_group_id | For referencing from `database-rds` etc. |
| task_role_arn | |
| log_group_name | |

## Security notes
- Execution-role and task-role permissions can never be conflated —
  `policy_statements` only ever reaches the task role.
- No public IP is assigned; tasks run in private subnets behind
  whatever ingress the team explicitly opens.

## Known limitations
- No ALB/target-group integration in v1 — a service is reachable
  within the VPC only. Add an ALB module as a follow-up if
  internet-facing services are needed.
- Single container per task definition; no sidecar pattern yet.