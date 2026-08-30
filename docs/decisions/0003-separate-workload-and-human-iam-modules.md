# 3. Separate workload identity from human access into two IAM modules

## Context
"IAM" covers two problems that look similar on the surface — both end in
a role or user with a policy attached — but differ in almost every
dimension that matters for module design:

| | Workload identity | Human access |
|---|---|---|
| Who assumes it | An AWS service (EC2, ECS, Glue) | A person |
| Trust principal | A service principal, e.g. `ec2.amazonaws.com` | An IAM user (or eventually a federated identity) |
| Session concept | Long-running, no MFA | Should be short-lived, MFA-enforced |
| Lifecycle driver | Deployments | Team roster / headcount changes |
| Typical requester | The team owning the workload | Whoever manages team membership |

A single `iam` module trying to serve both would need a trust-principal
input that sometimes means "a service" and sometimes means "a person,"
plus conditional logic for MFA, console access, and group membership that
only applies to one branch. That is the same "thin wrapper hiding two
unrelated concerns" problem the platform is designed to avoid elsewhere.

## Decision
Two separate modules:

- `iam` — workload identity only. Trust principal is always an AWS
  service (`ec2.amazonaws.com`, `ecs-tasks.amazonaws.com`,
  `glue.amazonaws.com`). Used internally by `compute-ec2`,
  `compute-ecs-service`, and `data-platform`.
- `iam-team-access` — human access only. Creates an IAM group and IAM
  users, with MFA enforced structurally (every action except managing
  one's own password/MFA device is denied until MFA is active) and no
  login credentials created by Terraform at all.

Neither module has a code path that resembles the other's use case.

## Consequences
- Each module's interface stays small and its `variables.tf` only
  contains inputs that make sense for its one job — there is no
  `trusted_service` value that would silently do the wrong thing.
- A future change to how humans authenticate (e.g. moving to AWS IAM
  Identity Center / SSO) only touches `iam-team-access`; workload roles
  are unaffected.
- Two modules to maintain instead of one, and two READMEs instead of
  one — accepted, since the alternative (one module encoding two
  unrelated trust models) is more confusing to consume, not less.
- `iam-team-access` is explicitly documented as a bridge for pre-SSO
  Beejan, not the long-term target — see its README's "Known
  limitations."