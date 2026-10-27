# 7. Consume COB modules as versioned Git sources, from a separate live repository

## Context
COB's environments originally called modules by relative path
(`source = "../../../modules/networking"`). That worked for building the
platform, but it has structural problems once COB is a real internal product:

- **No version boundary.** Environments read whatever is on disk, so editing
  a module changes what the next `plan` shows in *every* environment at once.
  There is no way to roll a change through dev before prod.
- **No record of what ran.** Nothing says which version of a module a given
  deployment used, which makes rollback and incident review guesswork.
- **Product and consumers are mixed.** Platform code and the live
  configuration that uses it sit in one repository, so "teams consume COB"
  really means "teams work inside Platform Engineering's repo."
- **CI/CD (the next phase) needs a clean consumer.** An automated pipeline
  should run against a consumer repo that depends on a *released* version of
  the platform, not on whatever commit happens to be checked out beside it.

## Options considered
| Option | Why not (or why) |
|---|---|
| Keep relative paths | Simplest, but none of the problems above go away |
| One repo, remote source pointing at a tag of the same repo | Gives versions, but still mixes product and consumers; one tag would cover both |
| Private Terraform registry (HCP Terraform or self-hosted) | Best versioning and discovery, but adds a service, cost and setup that a v0.x platform with a handful of consumers does not justify |
| **Separate repos, modules pinned by Git tag** | Versioning and promotion with no new infrastructure |

## Decision
Two repositories:

- `cob` — the platform: `modules/`, `docs/`, `examples/`. Released by Git tag.
- `cob-live` — consumers: `bootstrap/` and `environments/`. Every module call
  pins a released version:

```hcl
module "networking" {
  source = "git::https://github.com/<org>/cob.git//modules/networking?ref=v0.1.0"
}
```

Release rules:
- Versions follow semantic versioning. A breaking change to a module's inputs
  or outputs is a major bump.
- Versions stay `0.x` until modules have been exercised against real
  environments.
- A tag is never moved or reused. A fix gets a new tag.
- `ref` is always a tag, never a branch. A branch ref makes Terraform's cached
  download go stale and defeats the point of pinning.
- `examples/` keeps relative paths so an example always tests the code in the
  same commit.

## Consequences
- **Controlled promotion.** A new release is adopted in dev first, and prod
  moves only when someone changes its `ref`. Rollback is changing the `ref`
  back.
- **Reproducibility.** A deployment can be tied to an exact module version.
  Nested module calls (for example `compute-ec2` calling `../iam`) resolve
  inside the downloaded snapshot, so they are pinned to the same tag
  automatically.
- **`terraform init` is still required.** Remote modules are downloaded into
  `.terraform/modules/` by `init`, and it must be re-run when a `ref`
  changes. What changes is *what* is downloaded, not whether init runs.
- **The version is a literal in every module call.** Terraform does not allow
  variables in `source`, so a version bump means editing each call site.
  `grep -rn "ref=" environments/` finds them all.
- **Releasing is an extra step.** A module change reaches consumers only after
  it is merged and tagged. This is intended.
- **Authentication.** If `cob` is private, every machine and CI runner that
  runs `terraform init` needs Git credentials for it.
- ADRs 0001 and 0005 still hold. The `bootstrap/` and `environments/`
  directories they describe now live in `cob-live`.

## Revisit when
The number of modules or consuming teams makes tag-based discovery painful
(for example, teams cannot easily find which versions exist or what changed).
At that point a private registry becomes worth its overhead.