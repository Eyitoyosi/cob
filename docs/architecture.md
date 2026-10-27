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

## Diagrams

Two diagrams are included, at different zoom levels, because one diagram
trying to do both jobs ends up too abstract to verify against the code or
too cluttered to explain to someone new. Read them in this order.

### 1. Platform overview

![COB platform architecture](./diagrams/cob_simple_high_level_diagram.png)

This is the "what is COB, at a glance" view: engineering teams call the
COB platform, which provisions infrastructure into an AWS account. It
shows the platform's two internal layers —
**foundation modules** (`networking`, `iam`), consumed internally by
every other module and rarely called directly by a team, and
**capability modules** (`storage-s3`, `compute-ec2`, `compute-ecs-*`,
`database-rds`, `data-platform`), called directly by teams and composed
on top of the foundation layer. Use this diagram when explaining COB to
someone who has never seen it before, or when deciding which layer a new
module belongs in.

### 2. Example stack, detailed

![COB example stack architecture](./diagrams/cob_example_stack_white_bg_styled.png)

This is the "what actually gets built" view — the real resource
topology produced by `examples/web-app-with-database/`, one instance of
a team composing COB's capabilities. It shows:

- Traffic path: `INTERNET` → `INTERNET_GATEWAY` → `VPC`.
- Three subnet tiers inside the VPC: `PUBLIC_SUBNET` (NAT egress only —
  there is no internet-facing compute yet, see Known Limitations),
  `PRIVATE_SUBNET` (the `ECS_SERVICE` and its security group), and
  `DATABASE_SUBNET` (`RDS_POSTGRESQL` and its security group).
- The horizontal arrow between `ECS_SECURITY_GROUP` and
  `DB_SECURITY_GROUP` represents a security-group *reference*, not a
  network path — this is the mechanism from
  `0002-database-access-via-security-groups.md`: the database only
  trusts traffic from that specific security group, never a CIDR range.
- `S3_BUCKET`, `SECRETS_MANAGER`, and `IAM_TASK_ROLE` sit outside the
  VPC boundary because they're account-level services the ECS task
  reaches via AWS APIs, not network routing.

Use this diagram when reviewing or defending a specific security
decision, or when onboarding someone who needs to actually trace how a
request reaches the database.

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

## Repositories and versioning

COB is split across two repositories:

| Repository | Contains | Role |
|---|---|---|
| `cob` | `modules/`, `docs/`, `examples/` | The platform. Released by Git tag. |
| `cob-live` | `bootstrap/`, `environments/` | The consumers. Each module call pins a released version. |

Every module call in `cob-live` references a tagged release:

```hcl
source = "git::https://github.com/<org>/cob.git//modules/networking?ref=v0.1.0"
```

This makes a module change a deliberate, reviewable release rather than an
edit that silently affects every environment. A new version is adopted in
dev first, and prod moves only when its `ref` is changed. Rollback is
changing the `ref` back. `terraform init` is still required; it downloads
the pinned snapshot into `.terraform/modules/`.

Reasoning and trade-offs in
`docs/decisions/0007-consume-modules-via-versioned-git-tags.md`.

## How modules are consumed

Each team has its own root module under
`environments/{dev,prod}/teams/<team-name>/` in `cob-live`, with its own
Terraform state key, which:

1. Reads the shared foundation's outputs (`vpc_id`, `private_subnet_ids`,
   `ecs_cluster_arn`, etc.) via `terraform_remote_state` — read-only, no
   write access to foundation's state.
2. Calls whichever capability modules the team's workload needs, passing
   those foundation outputs in as inputs.

See `examples/web-app-with-database/` in `cob` for a self-contained,
runnable reference that composes five capabilities into one realistic stack
— the same stack shown in the detailed diagram above. Unlike `cob-live`,
examples use relative module paths on purpose, so an example always
exercises the code in the same commit.

## Environments

`dev` and `prod` are provisioned from identical module source code. All
differences — CIDR ranges, instance sizing, Multi-AZ, NAT topology, backup
retention, deletion protection — are expressed either as `.tfvars` values
or derived automatically inside a module from the `environment` variable
(e.g. `database-rds` defaults `multi_az` to `true` in prod, `false` in
dev). No infrastructure code is duplicated to express an environment
difference.

## State architecture

State is segregated by blast radius, not just by team. The code that owns
state (`bootstrap/` and `environments/`) lives in the `cob-live` repository:

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
  `compute-ec2` are reachable within the VPC only. This is why the
  detailed diagram's public subnet has no internet-facing compute — NAT
  egress only, for now.
- No Lake Formation column/row-level access control in `data-platform` —
  current access boundary is table-level via Glue/Athena permissions.

## Major architectural decisions

Recorded individually, with context and consequences, in
`docs/decisions/`:

- `0001-state-segregation-by-blast-radius.md`
- `0002-database-access-via-security-groups.md`
- `0003-separate-workload-and-human-iam-modules.md`
- `0004-fargate-over-ec2-backed-ecs.md`
- `0005-foundation-and-teams-environment-split.md`
- `0006-separate-ecs-execution-and-task-roles.md`
- `0007-consume-modules-via-versioned-git-tags.md`