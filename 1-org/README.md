# 1-org

Org-wide guardrails, applied by CI (`lz-apply`, environment approval, `main` only).

- **Folders** Shared / DEV / PROD — adopted with `import` blocks, deletion-protected
- **Tags** `env` (shared/dev/prod, bound to folders), `ingress=public`, `location=eu`, `legacy=true`
- **Org policies**
  - Secure-by-default baseline (imported) + `storage.publicAccessPrevention`, `compute.skipDefaultNetworkCreation`, `compute.requireOsLogin`, `compute.disableSerialPortAccess`, `compute.vmExternalIpAccess` (deny all), `sql.restrictPublicIp`
  - `gcp.resourceLocations`: `europe-west3` only; `location=eu` → any EU location
  - `gcp.restrictNonCmekServices`: CMEK required for Artifact Registry, BigQuery, Cloud Run, Cloud Run functions, Cloud SQL, Cloud Tasks, Compute, Firestore, Pub/Sub, Secret Manager, Storage; `legacy=true` exempt. Tools that create unencrypted side resources (`gcloud run deploy --source`, Firebase console) fail in new projects — provision through modules / CI
  - `gcp.restrictCmekCryptoKeyProjects`: keys only from projects under Shared
  - `run.allowedIngress`: internal / internal+LB; `ingress=public` → any
  - `essentialcontacts.allowedContactDomains`: `@gmail.com`
  - `iam.managed.allowedPolicyMembers` (domain-restricted sharing): **dry run** — org principals, the admin and the budget-alert system account; `legacy=true` exempt
- **Essential contact**: admin, all categories
- **Audit logs**: Data Access for `sts` and `iam` (federation and impersonation) (who federated / impersonated)

Folder IDs and project numbers are looked up with data sources, not committed.

## Legacy projects

`vk-personal-dashboard` and `wedding2026-vk` predate the LZ and are tagged `legacy=true`
(wedding also `ingress=public`). Remove a project from `local.legacy_projects` once it's rebuilt
as a factory project.

## Promoting DRS from dry run

Review the org policy dry-run violation entries in Cloud Audit Logs for a while, add any
legitimate principal to `allowedMemberSubjects`, then rename `dry_run_spec` to `spec`.
