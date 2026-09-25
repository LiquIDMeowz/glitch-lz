# CLAUDE.md — glitch-lz

Terraform landing zone (GlitchLZ) for a two-person GCP organization. Read `CONTRIBUTING.md` first;
decisions are in `project.md` (ADRs), past failures in `errors.md` — check it before debugging and
log any failed attempt there immediately (ERR-NNN, what was tried, the exact error).

## Working rules

- Stages `0-bootstrap` → `1-org` → `2-security` → `3-projects`, each its own state in
  `gs://glitch-tfstate-lz/<stage>`. CI applies 1–3 after approval; 0-bootstrap is applied locally
  by an operator. Never `terraform apply` org-scope stages yourself — prepare the plan, explain it,
  let the operator apply / approve.
- Plan locally as the read-only SA:
  `GOOGLE_IMPERSONATE_SERVICE_ACCOUNT=lz-plan@glitch-iac.iam.gserviceaccount.com terraform plan -lock=false`.
- Every change: branch → PR → CI (`ci-ok`) → squash-merge. Run `terraform fmt`, `tflint --recursive`
  and checkov locally first. Justified checkov skips go inline with a reason (`#checkov:skip=ID:why`).
- Public repo: never commit secrets, org / billing IDs or emails. Real values live in git-ignored
  `terraform.tfvars` and GitHub environment secrets (`ORG_ID`, `BILLING_ACCOUNT`,
  `SHARED_FOLDER_ID`, `ADMIN_EMAIL`, `KALINA_EMAIL`). Look IDs up with data sources where possible.
- New API used by a stage → also add it to glitch-iac's list in 0-bootstrap.
- Pin actions by commit SHA; region `europe-west3`; labels `app`/`env`/`owner`/`managed_by`.
- Priority is cost > security > availability, ≤ $10/month per project. Anything that autoscales
  gets a hard cap; nothing public without auth in front; no load balancers / Cloud Armor.
- Verify version-sensitive GCP / provider facts in current docs (Google Developer Knowledge MCP,
  context7, `terraform providers schema -json`) instead of memory — several resources behave
  differently from their docs (see errors.md).
- Update `task.md` as you work (in-progress → done), add ADRs to `project.md` for non-obvious decisions.
