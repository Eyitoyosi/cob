# COB — Internal Infrastructure Provisioning Platform

COB is Beejan Technologies' internal Terraform platform for provisioning
standardized, secure-by-default AWS infrastructure. Engineering teams
compose a small set of reusable modules instead of writing Terraform from
scratch or waiting on Platform Engineering for every request.

Full design detail, module list, and diagram: [`docs/architecture.md`](docs/architecture.md)
Major decisions and the reasoning behind them: [`docs/decisions/`](docs/decisions/)

<!-- PLACEHOLDER: architecture diagram screenshot -->
<!-- ![COB architecture](docs/diagrams/cob-architecture.png) -->

## Repository structure

```
cob/
├── bootstrap/         # One-time setup: creates the Terraform state S3 bucket
│                       # and DynamoDB lock table. Local state, run once, by an admin.
├── modules/            # The platform itself — reusable capability modules
│   ├── networking/
│   ├── iam/
│   ├── iam-team-access/
│   ├── storage-s3/
│   ├── compute-ec2/
│   ├── compute-ecs-cluster/
│   ├── compute-ecs-service/
│   ├── database-rds/
│   └── data-platform/
├── environments/
│   ├── dev/
│   │   ├── foundation/          # Shared VPC + ECS cluster, owned by Platform Eng
│   │   └── teams/
│   │       ├── app-engineering/
│   │       ├── data-engineering/
│   │       └── analytics-engineering/
│   └── prod/
│       └── (same shape as dev/)
├── examples/
│   └── web-app-with-database/   # Self-contained reference consumer, runnable standalone
└── docs/
    ├── architecture.md
    └── decisions/                # ADRs — one file per major decision
```

## Quick start

**Prerequisites:** Terraform >= 1.5.0, AWS CLI configured with credentials
(`aws sts get-caller-identity` should succeed).

1. **Bootstrap the state backend** (once, ever):
   ```bash
   cd bootstrap
   terraform init
   terraform apply
   ```

2. **Provision the shared foundation for an environment:**
   ```bash
   cd environments/dev/foundation
   terraform init
   terraform apply -var-file=dev.tfvars
   ```

3. **Provision a team's workload** (after foundation exists):
   ```bash
   cd environments/dev/teams/app-engineering
   terraform init
   terraform apply
   ```

Repeat steps 2–3 under `environments/prod/` when ready for production,
using `prod.tfvars`.

## Consuming COB as a team

You do not write raw `aws_*` resources. You call capability modules from
your team's directory under `environments/<env>/teams/<your-team>/`,
reading shared network/cluster info from foundation's outputs:

```hcl
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = "beejan-cob-terraform-main-state"
    key    = "dev/foundation/terraform.tfstate"
    region = "us-east-1"
  }
}

module "my_bucket" {
  source      = "../../../../modules/storage-s3"
  name        = "my-team-data"
  environment = "dev"
}
```

See [`examples/web-app-with-database/`](examples/web-app-with-database/)
for a full runnable example composing networking, compute, storage, and a
database, and [`docs/architecture.md`](docs/architecture.md) for how
modules are consumed and what each one guarantees.

## Available capabilities

| Need | Module |
|---|---|
| Network foundation | `networking` |
| Service-to-service permissions (EC2/ECS/Glue) | `iam` |
| Human team access to AWS | `iam-team-access` |
| Secure object storage | `storage-s3` |
| Long-running EC2 workload | `compute-ec2` |
| Shared Fargate cluster (Platform Eng only) | `compute-ecs-cluster` |
| Fargate service | `compute-ecs-service` |
| Managed relational database | `database-rds` |
| Query S3 data via Glue/Athena | `data-platform` |

Each module has its own `README.md` with inputs, outputs, security notes,
and known limitations.

## Environments

`dev` and `prod` use identical module source; differences are expressed
through `.tfvars` values or derived automatically from the `environment`
variable inside a module (e.g. Multi-AZ defaults on in prod). See
[`docs/decisions/0005-foundation-and-teams-environment-split.md`](docs/decisions/0005-foundation-and-teams-environment-split.md).

## Security & standards

Encryption at rest, least-privilege IAM, network isolation, MFA
enforcement, and credential handling via Secrets Manager are enforced
inside the modules — see [`docs/architecture.md`](docs/architecture.md#security-considerations)
for the full list and each module's README for module-specific notes.

## Status

v1 — core capabilities are provisionable and one example consumer is
built. Known limitations (no CI/CD role yet, no ALB module yet, etc.) are
listed in `docs/architecture.md`.