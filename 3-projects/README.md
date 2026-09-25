# 3-projects

The project factory, applied by CI (`lz-apply`). Input: `local.apps` in `projects.tf` — one entry
per app, each producing `glitch-<app>-dev` (DEV folder) and `glitch-<app>-prod` (PROD folder).

Per project:

| Resource | Details |
|---|---|
| Project | labels `app` / `env` / `owner` / `managed_by`; `env` tag inherited from the folder; `ingress=public` tag if the app sets `public_ingress` |
| APIs | base (KMS, IAM, IAM credentials, Logging, Monitoring, Service Usage) + the app's list |
| Deployer SA `deployer@<project>` | base roles (Autokey user, SA admin/user, logging config, service usage consumer) + the app's list; project-scoped only, no `projectIamAdmin` |
| WIF | dev: repo ID + environment `dev` (any ref, so PRs can plan dev); prod: repo ID + environment `prod` + `refs/heads/main` (ADR 038) |
| State | `glitch-tfstate-<env>`: list names (custom `tfStateLister`) + read/write only `<app>/<env>/` (ADR 039) |
| Budget | `project:<id>`, $10, → `budget-alerts` (dev projects are killed at 100 % by the kill switch) |
| Metrics scope | added to `glitch-monitoring` |

Legacy projects (`legacy_projects`) get only the budget and the metrics scope (ADR 040).

## Adding an app

1. Create the public repo, note its numeric ID (`gh api repos/<owner>/<repo> --jq .id`).
2. Add an entry to `local.apps`; if the app uses a new API, also add it to glitch-iac's list in 0-bootstrap (ERR-003b).
3. PR → CI plans → merge → approve `lz-apply`.
4. In the app repo: GitHub environments `dev` and `prod` (prod: required reviewer, `main` only),
   variables from `terraform output projects` / `wif_provider`.
