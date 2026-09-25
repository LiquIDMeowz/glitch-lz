# glitch-lz

Terraform landing zone for the Glitch GCP organization: org policies, tags, folders, org IAM,
logging, KMS / Autokey, budgets and the project factory. Workloads live in their own repos and
consume hardened modules from [`glitch-modules`](https://github.com/LiquIDMeowz/glitch-modules).

Priorities, in order: **cost > security > availability**. Hard ceiling ≤ $10/month for everything;
a traffic flood must degrade a service, never grow the bill.

## Layout

| Stage | Contents |
|---|---|
| `0-bootstrap` | `glitch-iac` project, state buckets (`-lz`, `-dev`, `-prod`), LZ deployer SA, GitHub WIF pool. Applied once locally, then state migrated into its own bucket |
| `1-org` | Org policies, tag keys / values, folders (imported), org IAM, audit log config, essential contacts |
| `2-security` | KMS projects + Autokey, logging project + org sink, monitoring scope, billing-account budget |
| `3-projects` | Project factory: `glitch-<app>-<env>` projects, APIs, deployer SAs, WIF bindings, budgets, quotas |
| `4-network` | Only when a workload needs a VPC |

Each stage is its own root module and state (prefix = stage name in `glitch-tfstate-lz`).

## Conventions

- Region `europe-west3`; labels `env`, `app`, `owner`, `managed_by=terraform`.
- Trunk-based: `main` only, feature branches → PR. Environment differences only in tfvars.
- Real IDs (org, billing account, admin email) never in Git: local `terraform.tfvars` (ignored) or
  GitHub Actions variables. Commit `*.tfvars.example` instead.
- Pre-commit hook (`.githooks/pre-commit`, enabled via `git config core.hooksPath .githooks`)
  runs `gitleaks` and `terraform fmt`.

## Decisions & Notes

Full design and ADRs 001–024 are in the private design doc (ClickUp, Landing Zone space →
"Landing Zone Design"). Decisions taken in this repo:

- ADR 025: Repos `glitch-lz` / `glitch-modules` are **public** | Reason: portfolio visibility, and on
  free GitHub only public repos get enforced rulesets, environment reviewers, secret scanning and
  push protection | Tradeoffs: rejected private (no enforced guardrails on free plan) and GitHub Pro
  (cost). Consequences: no secrets or real IDs in Git, WIF pinned to repo/owner IDs + ref, no
  `pull_request_target`, no self-hosted runners, plans not posted to PRs.
- ADR 026: State buckets in `0-bootstrap` are encrypted with Autokey keys stored in `glitch-iac`
  itself (same-project key storage) | Reason: Autokey keys are in the free tier (100 key versions,
  10k ops/month), manual keys are $0.06/version/month; the LZ state must not depend on key projects
  that a later stage manages | Tradeoffs: rejected Google-managed encryption (breaks the CMEK rule)
  and manual keys in glitch-iac (cost).
- ADR 027: Default branch `main`, commits authored with the GitHub noreply address | Reason: matches
  the design (trunk-based on `main`); keeps personal email out of public history.
