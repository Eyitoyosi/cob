# 5. Split each environment into a foundation layer and per-team root modules

## Status
Accepted

## Context
Some infrastructure is shared by construction — a VPC and an ECS
cluster only need to exist once per environment, and every team's
workloads live inside them. Other infrastructure belongs to exactly one
team — a team's S3 buckets, databases, and services. Putting both kinds
in the same root module (or in each team's own root module,
independently creating "their own" VPC) creates two different problems:

- One shared root module for everything means every team's `apply`
  touches shared networking, defeating the state-segregation goal in
  ADR 0001.
- Each team creating its own VPC means N VPCs per environment, extra
  cost, extra peering/routing complexity, and configuration that can
  drift between teams' copies of "the same" network.

## Decision
Each environment (`dev`, `prod`) is split into:

- `environments/<env>/foundation/` — owned and applied only by Platform
  Engineering. Creates the shared VPC (`networking`) and shared ECS
  cluster (`compute-ecs-cluster`) once per environment. Its outputs
  (`vpc_id`, subnet IDs, `ecs_cluster_arn`, etc.) are the only public
  contract other root modules read from.
- `environments/<env>/teams/<team-name>/` — one per team, owned and
  applied only by that team. Reads foundation's outputs via
  `terraform_remote_state` (read-only) and calls whichever capability
  modules the team's workload needs.

## Consequences
- There is exactly one VPC and one ECS cluster per environment, shared
  safely because no team's root module has write access to it.
- A team's `terraform apply` can only ever affect its own resources —
  combined with ADR 0001's state segregation, this is what makes
  "individuality" between teams real rather than aspirational.
- A change to shared networking (e.g. adjusting the VPC CIDR) is a
  Platform Engineering–owned, single-point change; teams automatically
  see updated outputs on their next `terraform plan`, without editing
  anything themselves.
- Onboarding a new team means adding one new directory under
  `teams/`, not touching `foundation/` at all.
- This does mean a hard dependency: a team's root module cannot be
  applied successfully before `foundation/` exists for that
  environment — acceptable, since foundation is meant to be created
  once, early, by Platform Engineering, before teams onboard.