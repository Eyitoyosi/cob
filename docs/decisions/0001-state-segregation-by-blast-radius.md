# 1. Segregate Terraform state by blast radius, not just by team

## Context
A single shared state file means any team's apply can affect another
team's resources, and one held lock blocks everyone. Per-team AWS
accounts would solve this but massively increase IAM/billing overhead
for a first version of the platform.

## Decision
One shared S3 bucket + one DynamoDB lock table, with state segregated
by key: `foundation` (networking + shared cluster, owned by Platform
Engineering) and one key per team per environment. Teams read
foundation's outputs via `terraform_remote_state`, never write to it.

## Consequences
- A team can never accidentally modify another team's or the shared
  foundation's infrastructure.
- Foundation changes (e.g. VPC CIDR) require Platform Engineering to
  apply; teams pick up new outputs automatically.
- Requires a one-time `bootstrap/` module (local state) to create the
  bucket and lock table before any other backend can be configured.