# iam-team-access

Provisions IAM users and a shared group for a human team, with
group-level permissions and structurally-enforced MFA (every action
except managing your own password/MFA device is denied until MFA is
active — not merely encouraged by policy comment).

Deliberately does **not** create login profiles or access keys —
Terraform state is not an acceptable place for credentials. An account
admin issues the initial password out-of-band after this module runs.

## Usage
    module "data_engineering_access" {
      source      = "../../modules/iam-team-access"
      team_name   = "data-engineering"
      environment = "dev"
      usernames   = ["amara.okoye", "chen.wei"]

      policy_statements = [
        {
          sid       = "ReadDataLakeBucket"
          effect    = "Allow"
          actions   = ["s3:GetObject", "s3:ListBucket"]
          resources = ["arn:aws:s3:::cob-dev-data-lake", "arn:aws:s3:::cob-dev-data-lake/*"]
        }
      ]
    }

## Inputs
| Name | Type | Default | Description |
|---|---|---|---|
| team_name | string | — | Team identifier |
| environment | string | — | `dev` or `prod` |
| usernames | list(string) | `[]` | IAM usernames to create |
| policy_statements | list(object) | — | Team's permissions, beyond MFA self-service |
| tags | map(string) | `{}` | Extra tags |

## Outputs
| Name | Description |
|---|---|
| group_name | IAM group name |
| group_arn | IAM group ARN |
| user_names | Created usernames |
| user_arns | Created user ARNs |

## Security notes
- No console password or access key is ever created by this module.
  After apply, an admin must manually set an initial login profile
  with `password_reset_required = true`.
- MFA enforcement is unconditional — there is no flag to disable it.

## Known limitations
- Assumes AWS Identity Center (SSO) is not yet set up at Beejan; this
  module should be considered a bridge, not the long-term target.
  Revisit once SSO is available — see docs/decisions.
- No password policy resource included yet (account-level, not
  per-group) — should be set once, separately, at the account level.