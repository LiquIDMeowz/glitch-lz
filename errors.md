# Errors

## ERR-001 — 1-org apply: audit config for iamcredentials.googleapis.com rejected
- **Date:** 2026-09-25
- **Tried:** `google_organization_iam_audit_config` with service `iamcredentials.googleapis.com` (CI apply, run 36129103568)
- **Result:** `Error 400: Service iamcredentials.googleapis.com does not exist or does not support service level configuration of Google Cloud audit logging.` Everything else in 1-org applied.

### Resolution
Service account credential calls (generateAccessToken etc.) are audited under `iam.googleapis.com`;
switched the audit config to that service.
