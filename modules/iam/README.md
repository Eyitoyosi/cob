# iam

Reusable "role factory" for **workload identity** — service-to-service
permissions (EC2 instances, ECS tasks), not human access. Handles the
trust policy correctly for the given service so consumers never write
one by hand, and attaches whatever least-privilege permission
statements the workload actually needs.

For human/team access, see `iam-team-access` instead — deliberately a
separate module; see docs/decisions for why.

## Usage
    module "role" {
      source          = "../../modules/iam"
      name            = "checkout-service"
      environment     = "dev"
      trusted_service = "ecs-tasks.amazonaws.com"

      policy_statements = [
        {
          sid       = "ReadCheckoutBucket"
          effect    = "Allow"
          actions   = ["s3:GetObject"]
          resources = ["arn:aws:s3:::cob-dev-checkout-data/*"]
        }
      ]
    }

## Inputs
| Name | Type | Default | Description |
|---|---|---|---|
| name | string | — | Short role identifier |
| environment | string | — | `dev` or `prod` |
| trusted_service | string | — | `ec2.amazonaws.com`, `ecs-tasks.amazonaws.com`, or `glue.amazonaws.com` |
| policy_statements | list(object) | — | Permission statements (sid, effect, actions, resources) |
| tags | map(string) | `{}` | Extra tags |

## Outputs
| Name | Description |
|---|---|
| role_arn | ARN of the created role |
| role_name | Name of the created role |
| policy_arn | ARN of the attached permission policy |
| instance_profile_name | Set only when `trusted_service = "ec2.amazonaws.com"`; `null` otherwise |

## Security notes
- The trust policy is derived entirely from `trusted_service` — a
  consumer cannot accidentally create an overly-broad trust
  relationship, because there's no field for one.
- `policy_statements` currently supports only `actions`/`resources`/
  `effect` — no `condition` blocks yet, to keep the interface simple
  for v1. Anything needing conditional access needs a direct
  `aws_iam_role_policy` for now (a known limitation, not a workaround
  to hide).

## Known limitations
- No permissions boundary applied yet — see docs/decisions for the
  planned follow-up once more teams are calling this module.
- No support for cross-account trust or OIDC federation (e.g.
  GitHub Actions) — a distinct trust pattern, deliberately out of
  scope for this module.