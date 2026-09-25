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
  itself — same-project key storage configured on the **Shared folder** (the provider only supports
  folder-level Autokey config), so all Shared projects keep their own keys; DEV / PROD use the
  dedicated key projects from 2-security | Reason: Autokey keys are in the free tier (100 key versions,
  10k ops/month), manual keys are $0.06/version/month; the LZ state must not depend on key projects
  that a later stage manages | Tradeoffs: rejected Google-managed encryption (breaks the CMEK rule)
  and manual keys in glitch-iac (cost).
- ADR 027: Default branch `main`, commits authored with the GitHub noreply address | Reason: matches
  the design (trunk-based on `main`); keeps personal email out of public history.
- ADR 028: Two LZ identities — `lz-plan` (read-only, env `lz-plan`, PRs) and `lz-apply` (env
  `lz-apply` + `refs/heads/main`, enforced in the WIF binding). Every GCP-authenticating job declares
  a GitHub environment | Reason: least privilege for PR plans on a public repo; main-only apply
  enforced on the GCP side too | Tradeoffs: rejected one SA for plan and apply.
- ADR 029: PR gates `fmt -check`, `validate`, `tflint`, `checkov`, `plan`, summarised by one required
  check `ci-ok`; local hook runs only `gitleaks` + `fmt`; all actions pinned by SHA, kept current by
  Dependabot | Reason: fast commits, full checks before merge, supply-chain safety | Tradeoffs:
  rejected trivy (fewer GCP rules), the checkov GitHub action (ships an outdated image).
- ADR 030: Planner uses curated read-only roles instead of `roles/viewer`; apply SA has no
  `roles/iam.securityAdmin` (3-projects grants SA admin per adopted project); Data Access audit logs
  on glitch-iac replace bucket access logs | Reason: checkov CKV_GCP_115 / 45 / 62 | Tradeoffs:
  planner roles must be extended when a new stage's plan hits a 403.
- ADR 031: Pre-LZ projects (`vk-personal-dashboard`, `wedding2026-vk`) are tagged `legacy=true` and
  exempt from the CMEK and DRS policies; location / ingress / baseline policies still apply | Reason:
  keep live apps deployable without rework; exemption is removed when a project is rebuilt in the
  factory | Tradeoffs: rejected enforcing everything (breaks wedding source deploys) and a separate
  Legacy folder (touches IAM inheritance).
- ADR 032: DRS (`iam.managed.allowedPolicyMembers`) starts in dry run; other new policies are
  enforced immediately | Reason: service-agent exceptions for the managed constraint are poorly
  documented; all other policies only affect resource creation and every non-legacy project already
  complies | Tradeoffs: a window where DRS only logs.
- ADR 033: CMEK required for Storage, BigQuery, Artifact Registry and Compute only (the services
  Autokey keys for free); CMEK keys only from projects under Shared | Reason: cost ceiling | Tradeoffs:
  Secret Manager / Pub/Sub / Cloud SQL / Firestore stay on Google-managed keys until needed.
- ADR 034: IDs are looked up with data sources (folders by display name, projects by ID) instead
  of committed or passed as secrets | Reason: public repo, fewer CI secrets.
