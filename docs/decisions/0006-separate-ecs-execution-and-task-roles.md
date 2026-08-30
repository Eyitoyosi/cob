# 6. Create separate execution and task IAM roles per ECS service

## Context
ECS Fargate tasks can technically run with a single IAM role serving
both purposes AWS distinguishes: the **execution role** (used by the
ECS agent, before the container starts, to pull the image from ECR and
set up log streaming) and the **task role** (used by the application
code itself, at runtime, to call other AWS services). Using one shared
role for both is a common shortcut, since AWS does not force the split
technically.

Doing so means the application's runtime code ends up with
`ecr:GetAuthorizationToken` and log-write permissions it will never
use, and — more importantly — any future change to what the agent
needs (e.g. a new logging destination) silently changes what the
*application* is allowed to do, and vice versa. This directly
contradicts the platform's least-privilege standard: a role should
only ever contain the permissions its actual holder needs.

## Decision
`compute-ecs-service` always creates two roles via the `iam` module:
an execution role with a fixed, non-configurable set of permissions
(ECR pull, CloudWatch Logs write) and a task role whose permissions
come entirely from the consumer's `policy_statements` input. There is
no option to collapse them into one.

## Consequences
- A team's `policy_statements` can never accidentally grant image-pull
  or logging permissions, and can never be under-scoped by inheriting
  agent-level permissions it didn't ask for.
- Two roles (and two trust relationships, two policies) exist per ECS
  service instead of one — a small increase in the number of IAM
  resources per workload, accepted as the cost of a correct
  least-privilege boundary.
- Consumers only ever configure the task role; the execution role is
  entirely the module's concern and requires no input, keeping the
  module's interface simple despite the extra resource underneath.
- If a future service genuinely needs the application to also manage
  its own image-pull behavior (unusual), that would be a deliberate
  module change, not a workaround via shared roles.