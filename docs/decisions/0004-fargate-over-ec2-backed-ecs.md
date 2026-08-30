# 4. Use Fargate, not EC2-backed ECS, for compute-ecs-*

## Context
ECS supports two launch types. EC2-backed ECS runs tasks on a fleet of
EC2 instances that the account owner manages directly — patching,
capacity planning, AMI updates, and instance-level security groups are
all the consuming team's or Platform Engineering's responsibility.
Fargate runs tasks on AWS-managed infrastructure — the consumer only
specifies CPU/memory for the task itself.

The brief asks COB to make "sensible compute available to workloads
without requiring every team to implement it independently." EC2-backed
ECS reintroduces exactly the kind of undifferentiated infrastructure
work (host patching, capacity sizing, AMI lifecycle) that the platform
exists to remove.

## Decision
`compute-ecs-cluster` and `compute-ecs-service` use Fargate and
Fargate Spot as capacity providers exclusively. No EC2-backed launch
type is exposed.

## Consequences
- Teams never manage container-host capacity, patching, or AMI
  lifecycle for ECS workloads — the module's `cpu`/`memory` inputs are
  the entire capacity conversation.
- Cost is billed per task rather than per always-on host, which is more
  cost-conscious for workloads that don't need to saturate a fixed
  fleet size — but can be more expensive than a well-utilized EC2 fleet
  at very high, steady-state scale. Not a concern for a v1 platform;
  worth revisiting only if a team's workload profile clearly outgrows
  it.
- Fargate Spot (used as a secondary capacity provider) means tasks can
  be interrupted; suitable for the stateless services this module
  targets, not for workloads requiring guaranteed availability of any
  specific task instance.
- If a team genuinely needs EC2-backed ECS (e.g. GPU workloads Fargate
  doesn't support), that is out of scope for `compute-ecs-*` in v1 and
  would need a deliberate new module, not a flag bolted onto this one.