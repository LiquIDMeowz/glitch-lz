# Working on GlitchLZ

For the two operators (Vlad, Kalina) and the Claude sessions they work with. The design and all
decisions live in this repo: stage READMEs, [`project.md`](project.md) (ADRs 025+),
[`errors.md`](errors.md) (every failure and its fix), [`task.md`](task.md).

## Which repo does what

| I want to… | Repo | Flow |
|---|---|---|
| a new project, or new APIs / roles / budget for one | `glitch-lz` → `3-projects/projects.tf` | PR → CI plans → merge → approve `lz-apply` |
| org guardrails: policies, tags, keys, logging, budgets | `glitch-lz` → `1-org`, `2-security` | same |
| infra + app inside a project | the app's own repo (`infra/` uses `glitch-modules`) | PR → CI plans dev → merge → deploys dev → approve `prod` → same commit / image to prod |
| a new or better building block | `glitch-modules` | PR → merge → **tag `vX.Y.Z`**; apps upgrade when they choose (dev first) |

`glitch-modules` is a library: nothing deploys from it.

## Change flow

1. Branch from `main` (`feature/…`, `fix/…`, `chore/…`), conventional commits.
2. The pre-commit hook (`git config core.hooksPath .githooks`) runs gitleaks + `terraform fmt`.
3. Open a PR. CI runs fmt / validate / tflint / checkov and plans every changed stage as the
   read-only `lz-plan`. `ci-ok` must pass; review threads must be resolved. Plans are in the job
   logs (public repo: secrets are masked, nothing sensitive is committed).
4. Squash-merge. CI plans again and waits on environment **`lz-apply`** — either operator approves.
5. **0-bootstrap is never applied by CI.** An operator applies it locally
   (`terraform plan -out=tfplan`, review, `terraform apply tfplan`).

Run a plan locally without write access: `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=lz-plan@glitch-iac.iam.gserviceaccount.com terraform plan -lock=false`
(both operators may impersonate `lz-plan`; nobody impersonates `lz-apply`).

## Access (ADR 045)

- Kalina: standing read-only; elevate with PAM (see [1-org README](1-org/README.md#operators--pam-adr-045)):
  `dev-writer` self-service, `prod-writer` / `org-admin` approved by Vlad.
- Vlad: standing admin (break-glass), approves Kalina's PAM requests.
- CLI quota project, once: `gcloud config set billing/quota_project glitch-iac`.
- Budget CLI: add `--billing-project=glitch-iac`.

## A new app, end to end

1. Create the public repo `glitch-<app>`; note its ID: `gh api repos/<owner>/glitch-<app> --jq .id`.
2. `glitch-lz`: add `<app>` to `local.apps` in `3-projects/projects.tf` (repo ID, APIs, deployer
   roles, `public_ingress` only if it must be reachable from the internet) → PR → approve.
   → `glitch-<app>-dev` / `-prod`, deployer SA, WIF bound to that repo, state `<app>/<env>`, $10 budgets.
3. App repo, one-time: guardrails (hook, ruleset, secret scanning), GitHub environments `dev` and
   `prod` (reviewers, `main` only), variables `WIF_PROVIDER`, `REGION` and per environment
   `GCP_PROJECT`, `DEPLOYER_SA`, `STATE_BUCKET`, `STATE_PREFIX` (values: `terraform output projects`
   in 3-projects). *Planned: `glitch-app-template` + `setup-app-repo.sh` to do this in one step.*
4. App repo CI: authenticate with `google-github-actions/auth` (WIF → deployer), build the image,
   push to the app's CMEK Artifact Registry repo, `terraform apply` `infra/` (modules pinned by tag),
   deploy the image digest; promote the same digest to prod after approval.

### What `repo_id` means

`repo_id` in a factory entry is the **numeric ID of the app's GitHub repo** — the one repo GCP will
trust to deploy into that app's two projects. The factory writes it into the WIF bindings:

- a CI job in environment `dev` of that repo → may act as `deployer@glitch-<app>-dev`
- a CI job in environment `prod` of that repo, **on `main` only** → `deployer@glitch-<app>-prod`

No keys anywhere: GitHub signs "this is repo X, environment dev", GCP exchanges it for a
short-lived deployer token. The deployer builds and deploys; the app itself runs as a separate
runtime SA created by the module, with only the data roles it needs. The ID (not the name) is used,
so a rename keeps working and a deleted-and-recreated repo with the same name is *not* trusted.

### Template vs. setup script (planned, built with the GlitchOps wiki)

A GitHub template copies **files**, not **settings**, so a new app repo takes two pieces:

| Piece | Gives you |
|---|---|
| `glitch-app-template` ("Use this template") | CI workflow (build → dev → promote to prod), `infra/` skeleton using `glitch-modules`, pre-commit hook, `.gitignore`, `project.md` / `task.md`, repo `CLAUDE.md` |
| `setup-app-repo.sh <app>` | GitHub environments `dev` / `prod` (reviewers, `main` only), variables from the 3-projects outputs, ruleset, secret scanning |

Target flow: template → note repo ID → factory PR → approve → `setup-app-repo.sh <app>` → push code.

## Rules that bite (read before changing things)

- **Never create projects by hand** — only the factory. Never click-ops org settings.
- **Any API the LZ service accounts call must be enabled in `glitch-iac`** (0-bootstrap
  `local.services`) — their calls are billed there (ERR-003b). App deployers bill their own project.
- **CMEK is required** for AR, BigQuery, Cloud Run, functions, Cloud SQL, Tasks, Compute,
  Firestore, Pub/Sub, Secret Manager, Storage. Use Autokey key handles; Firestore / Tasks /
  direct Cloud Functions need the manual keys in `glitch-kms-<env>` (factory grant not built yet).
  `gcloud run deploy --source` and Firebase-console resource creation fail in new projects.
- **europe-west3 only** (tag `location=eu` for other EU regions). Cloud Run ingress is internal
  unless the project has `public_ingress = true`.
- **Cost > security > availability.** Every Cloud Run service has a hard `max_instances`, auth in
  front (IAP), and request-log exclusions. Budgets alert at $10 per project; **dev projects lose
  billing at 100 %** (kill switch). Re-link: `gcloud billing projects link <id> --billing-account=<BA>`.
- Google service agents are often created lazily — a "service account does not exist" error on a
  `service-…@gcp-sa-…` address usually means the agent must be provisioned first (ERR-003a, ERR-005).
- Public repos: no secrets, real org / billing IDs or personal emails in Git — use local
  `terraform.tfvars` (git-ignored) and GitHub environment secrets.
