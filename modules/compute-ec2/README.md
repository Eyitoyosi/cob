# compute-ec2

Reusable EC2 workload: security group (no open ports by default),
an IAM role + instance profile via the `iam` module (with SSM Session
Manager access baked in — no bastion host, no SSH key required), and
an autoscaling group so a dead instance is replaced automatically
rather than requiring manual intervention.

## Usage
    module "worker" {
      source        = "../../modules/compute-ec2"
      name          = "batch-worker"
      environment   = "dev"
      vpc_id        = module.networking.vpc_id
      subnet_ids    = module.networking.private_subnet_ids

      ingress_rules = [
        {
          description = "Internal health check"
          from_port   = 8080
          to_port     = 8080
          protocol    = "tcp"
          cidr_blocks = ["10.0.0.0/16"]
        }
      ]
    }

## Inputs
| Name | Type | Default | Description |
|---|---|---|---|
| name | string | — | Workload identifier |
| environment | string | — | `dev` or `prod` |
| vpc_id | string | — | From `networking` output |
| subnet_ids | list(string) | — | Private subnet IDs |
| instance_type | string | `t3.micro` | |
| ami_id | string | `null` | Defaults to latest Amazon Linux 2023 |
| min_size / max_size / desired_capacity | number | `1`/`2`/`1` | ASG sizing |
| ingress_rules | list(object) | `[]` | No implicit open ports |
| policy_statements | list(object) | `[]` | Extra IAM permissions beyond SSM |
| user_data | string | `null` | |
| tags | map(string) | `{}` | |

## Outputs
| Name | Description |
|---|---|
| security_group_id | For referencing from `database-rds` etc. |
| autoscaling_group_name | |
| role_arn | |

## Security notes
- IMDSv2 is enforced unconditionally (`http_tokens = "required"`) —
  blocks the SSRF-to-instance-credential-theft pattern.
- EBS volumes are always encrypted; no override.
- SSH access is not provided — use SSM Session Manager via the
  IAM permissions already attached.

## Known limitations
- Single launch template / single AMI per call — no mixed-instance
  ASG policies yet.
- No target-group/load-balancer wiring in this module; pair with an
  ALB module (not yet built) if you need one.