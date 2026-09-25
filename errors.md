# Errors

## ERR-001 — 1-org apply: audit config for iamcredentials.googleapis.com rejected
- **Date:** 2026-09-25
- **Tried:** `google_organization_iam_audit_config` with service `iamcredentials.googleapis.com` (CI apply, run 36129103568)
- **Result:** `Error 400: Service iamcredentials.googleapis.com does not exist or does not support service level configuration of Google Cloud audit logging.` Everything else in 1-org applied.

### Resolution
Service account credential calls (generateAccessToken etc.) are audited under `iam.googleapis.com`;
switched the audit config to that service.

## ERR-002 — PR blocked by code-scanning threads for skipped checkov findings
- **Date:** 2026-09-25 (PR #5)
- **Tried:** upload checkov SARIF as produced
- **Result:** checkov writes `#checkov:skip` findings with SARIF `suppressions`; GitHub code scanning ignores them, opens review threads, and the ruleset (thread resolution required) blocks the merge.

### Resolution
CI strips results that carry `suppressions` before upload (`jq`); threads auto-resolved on the next run.

## ERR-003 — 2-security first apply (run 36131940863): three failures
- **Date:** 2026-09-25
- **a)** `google_project_service_identity` (cloudkms) returns the **EKM** agent `service-N@gcp-sa-ekms`; binding it failed "does not exist". Autokey needs `service-N@gcp-sa-cloudkms`.
- **b)** Pub/Sub topic creation: "Cloud Pub/Sub API has not been used in project glitch-iac" — provider-level `billing_project = glitch-iac` + `user_project_override` sent every call with glitch-iac as quota project.
- **c)** `google_monitoring_monitored_project` 403: `monitoring.metricsScopes.link` is required on the scoping **and** the monitored project; lz-apply only had monitoring.admin on glitch-monitoring.

### Resolution
- a) Bind `service-${project_number}@gcp-sa-cloudkms.iam.gserviceaccount.com` (as in Google's Autokey Terraform example).
- b) ~~Removed the provider-level quota-project override~~ — **did not work** (run 36140137823, same error for consumer project 364574903782 = glitch-iac): calls made as lz-apply in CI are attributed to the SA's own project regardless. Real fix: enable `pubsub.googleapis.com` in glitch-iac (0-bootstrap `local.services`), consistent with glitch-iac being the quota project for every LZ API. Rule: when a stage starts using a new API, add it to 0-bootstrap's list.
- c) `roles/monitoring.metricsScopesAdmin` at org for lz-apply (0-bootstrap, human-applied).

## ERR-004 — 0-bootstrap local plan hangs (cloudbilling 429)
- **Date:** 2026-09-25
- **Tried:** local `terraform plan` (admin ADC) on the kill-switch branch; first attempt hung >5 min and left a stale lock after SIGINT/TERM; retry with `timeout 200` hung the same way.
- **Result:** TF_LOG showed `google_billing_account_iam_member` reads retrying on `429 RATE_LIMIT_EXCEEDED` for consumer `projects/764086051850` — the shared Google Cloud SDK project, not ours (user credentials sent no quota project to this API). Stale locks removed with `terraform force-unlock <generation>` (GCS lock ID = object generation, not the UUID in the lock file).

### Resolution
0-bootstrap provider sets `billing_project = glitch-iac` + `user_project_override = true` (only this stage runs with user credentials; CI SAs bill to glitch-iac anyway).

