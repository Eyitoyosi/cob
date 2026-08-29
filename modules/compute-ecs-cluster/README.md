# compute-ecs-cluster

Provisions one shared ECS cluster per environment (Fargate + Fargate
Spot capacity providers, Container Insights enabled). Owned by
Platform Engineering and created once in `environments/*/foundation/`
— individual teams never create their own cluster, only services
inside this shared one (see `compute-ecs-service`).

## Usage
    module "ecs_cluster" {
      source      = "../../modules/compute-ecs-cluster"
      environment = "dev"
    }

## Inputs
| Name | Type | Default | Description |
|---|---|---|---|
| name | string | `primary` | Cluster identifier |
| environment | string | — | `dev` or `prod` |
| tags | map(string) | `{}` | |

## Outputs
| Name | Description |
|---|---|
| cluster_arn | Passed into every `compute-ecs-service` call |
| cluster_name | |

## Security notes
- N/A directly — this module has no data plane of its own; security
  posture is enforced per-service in `compute-ecs-service`.

## Known limitations
- One cluster per environment in v1. Splitting clusters per team is a
  possible future change if noisy-neighbor concerns arise, but adds
  operational overhead not currently justified.