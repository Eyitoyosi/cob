# COB — Architecture

## What COB is

COB is Beejan Technologies' internal Terraform platform for provisioning
AWS infrastructure. Instead of Platform Engineering hand-building
infrastructure per request, or teams writing their own Terraform from
scratch, engineering teams compose a small set of reusable, secure-by-default
modules to get networking, compute, storage, databases, and analytics
infrastructure that already meets company standards.

## The problem it solves

Before COB, every infrastructure request went through Platform Engineering
manually, and different teams' resources drifted apart in configuration —
inconsistent S3 settings, inconsistent IAM, inconsistent naming and tagging,
and infrastructure changes that were hard to track. COB exists to move the
organization from *"Platform Engineering builds this for us"* to
*"we provision this ourselves, on the company's standard platform."*

## Diagram

<!-- PLACEHOLDER: insert the architecture diagram here, e.g.
     ![COB platform architecture](./diagrams/cob-architecture.svg)
     Source diagram (consumers → COB platform → AWS accounts, with
     foundation and capability module layers) was reviewed earlier in
     this project's design discussion. Export it as SVG/PNG into
     docs/diagrams/ and update the path above. -->

The diagram shows three layers:

1. **Consumers** — Application Engineering, Data Engineering, and Analytics
   Engineering, each calling COB modules from their own environment
   directory.
2. **COB platform**, split into:
   - **Foundation layer** — `networking` and `iam`, consumed internally by
     every other module and rarely called directly by application teams.
   - **Capability layer** — `storage-s3`, `compute-ec2`, `compute-ecs-*`,
     `database-rds`, and `data-platform`, called directly by teams and
     internally composing the foundation layer (and, in `data-platform`'s
     case, `storage-s3` itself).
3. **AWS accounts** — a `dev` and a `prod` environment, provisioned from the
   same module source, differing only in `.tfvars` values.

## Platform capabilities

| Module | Capability | Depends on |
|---|---|---|
| `networking` | VPC, three-tier subnets, NAT, S3 gateway endpoint, flow logs, locked default SG | — |
| `iam` | Workload identity (EC2/ECS/Glue trust + least-privilege permissions) | — |
| `iam-team-access` | Human team access: IAM users/group, MFA-enforced | — |
| `storage-s3` | Encrypted, versioned, TLS-only, lifecycle-managed S3 bucket | — |
| `compute-ec2` | ASG-backed EC2 workload, IMDSv2, SSM access, no bastion | `networking`, `iam` |
| `compute-ecs-cluster` | Shared Fargate cluster, one per environment | — |
| `compute-ecs-service` | Fargate service with separate execution/task roles | `networking`, `iam`, `compute-ecs-cluster` |
| `database-rds` | Managed relational database, SG-based access only, Secrets Manager credentials | `networking`, `iam` |
| `data-platform` | Glue Data Catalog + Athena over existing S3 data, no direct S3 grants to analysts | `storage-s3`, `iam` |

Module boundaries were drawn around **use cases a team asks for**, not
individual AWS resource types — see `docs/decisions/` for the reasoning
behind each split (e.g. why workload IAM and human IAM are separate
modules, why ECS cluster and ECS service are separate modules).

## How modules are consumed

Application, Data, and Analytics Engineering never call `modules/*`
directly against production state. Each team has its own root module under
`environments/{dev,prod}/teams/<team-name>/`, with its own Terraform state
key, which:

1. Reads the shared foundation's outputs (`vpc_id`, `private_subnet_ids`,
   `ecs_cluster_arn`, etc.) via `terraform_remote_state` — read-only, no
   write access to foundation's state.
2. Calls whichever capability modules the team's workload needs, passing
   those foundation outputs in as inputs.

See `examples/web-app-with-database/` for a self-contained, runnable
reference that composes five capabilities into one realistic stack.

## Environments

`dev` and `prod` are provisioned from identical module source code. All
differences — CIDR ranges, instance sizing, Multi-AZ, NAT topology, backup
retention, deletion protection — are expressed either as `.tfvars` values
or derived automatically inside a module from the `environment` variable
(e.g. `database-rds` defaults `multi_az` to `true` in prod, `false` in
dev). No infrastructure code is duplicated to express an environment
difference.

## State architecture

State is segregated by blast radius, not just by team:

- One shared S3 bucket + one DynamoDB lock table (created once via
  `bootstrap/`, the one place local state is intentional).
- `environments/<env>/foundation/` — Platform Engineering's own state key;
  owns networking and the shared ECS cluster.
- `environments/<env>/teams/<team>/` — one state key per team per
  environment; can never write to another team's or to foundation's state.

Full reasoning in `docs/decisions/0001-state-segregation-by-blast-radius.md`.

## Security considerations

- **Network isolation**: application and database workloads live in
  private/database subnets; only explicitly declared ingress is opened,
  and databases accept connections from specific security groups only,
  never CIDR ranges.
- **Encryption at rest**: enforced unconditionally in `storage-s3`,
  `compute-ec2` (EBS), and `database-rds` — no module exposes a flag to
  disable it.
- **Least-privilege IAM**: every workload role is scoped to exactly the
  `policy_statements` its consumer declares; ECS execution and task roles
  are always separate so image-pull permissions and application-runtime
  permissions can never be conflated.
- **No long-lived credentials in state**: RDS passwords go to Secrets
  Manager, never a Terraform output; `iam-team-access` never creates
  console passwords or access keys.
- **MFA enforcement**: structurally denied-by-default for human users
  until MFA is active, not merely documented as a policy.

## Important assumptions

- Beejan does not yet use AWS IAM Identity Center (SSO); `iam-team-access`
  is a classic-IAM bridge, expected to be revisited once SSO is available.
- Single AWS region per environment; no cross-region DR in v1.
- Single AWS account per environment (`dev`, `prod`), not one account per
  team.

## Known limitations

- No CI/CD deploy role (OIDC federation) yet — planned once `terraform
  apply` is automated.
- No IAM permissions boundary yet — planned once more teams are calling
  the `iam` module.
- No load balancer / ALB module yet; `compute-ecs-service` and
  `compute-ec2` are reachable within the VPC only.
- No Lake Formation column/row-level access control in `data-platform` —
  current access boundary is table-level via Glue/Athena permissions.

## Major architectural decisions

Recorded individually, with context and consequences, in
`docs/decisions/`:

- `0001-state-segregation-by-blast-radius.md`
- `0002-database-access-via-security-groups.md`
- `0003-separate-workload-and-human-iam-modules.md`
- `0004-fargate-over-ec2-backed-ecs.md`
- `0005-foundation-and-teams-enviromoent-split.md`
- `0006-separate-ecs-execution-and-task-roles.md`

