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
- b) Removed the provider-level quota-project override (only needed for user ADC; ADC quota project is glitch-iac anyway).
- c) `roles/monitoring.metricsScopesAdmin` at org for lz-apply (0-bootstrap, human-applied).

