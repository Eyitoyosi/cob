# Example: web app with database

Demonstrates composing five COB capabilities into one working workload:
networking, an ECS cluster, object storage, a container service, and a
relational database — the kind of stack Application Engineering or Data
Engineering would actually deploy.

## What this proves
- A team never touches a raw `aws_vpc`, `aws_security_group`, or
  `aws_iam_role` resource directly.
- The database only accepts traffic from the API service's security
  group — nothing else in the VPC can reach it.
- Credentials for the database are in Secrets Manager, never in state
  output or a `.tfvars` file.

## Running this example
This example is self-contained (its own VPC, its own local state) and
safe to run in an isolated/sandbox AWS account:

    cd examples/web-app-with-database
    terraform init
    terraform apply

Real teams don't copy this pattern verbatim — see
`environments/dev/teams/app-engineering/` for how a team consumes COB
against the shared foundation and remote state.