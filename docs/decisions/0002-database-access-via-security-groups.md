# 2. Database ingress is security-group-based, never CIDR-based

## Context
CIDR-based ingress rules only restrict *where* traffic originates
network-wise; anything in that range can connect. For a database,
we know exactly which application should have access.

## Decision
`database-rds` only accepts `allowed_security_group_ids` as input —
no CIDR-based ingress option exists in the module at all.

## Consequences
- Even an unrelated resource in the same VPC/subnet cannot reach the
  database unless its security group is explicitly listed.
- Slightly less flexible for exotic cases (e.g. an on-prem VPN client
  needing direct access) — not supported in v1; would need a
  deliberate follow-up module change, not a workaround.