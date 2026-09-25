# 2-security

Shared security and cost services, applied by CI (`lz-apply`).

| Project | Contents |
|---|---|
| `glitch-kms-dev` / `glitch-kms-prod` | Autokey key projects for the DEV / PROD folders (dedicated-project mode); keyring `cmek-manual` with keys `firestore`, `cloudtasks`, `cloudfunctions` (services Autokey can't key, yearly rotation) |
| `glitch-logging` | Bucket `security` (90 days) fed by an org sink with all Cloud Audit Logs |
| `glitch-monitoring` | Metrics scope for the Shared projects, admin email channel, CMEK topic `budget-alerts` |

## Budgets (ADR 035)

Budgets alert, they never cap spend. Every budget emails the admin and publishes to `budget-alerts`.

| Budget | Amount | Thresholds |
|---|---|---|
| `billing-account-total` | $10 | 50 / 100 / 150 / 200 %, forecast 100 % |
| `project:<id>` (Shared projects here; workload projects in 3-projects) | $10 | 50 / 90 / 100 %, forecast 100 % |

Shared projects are never killed.

## Dev kill switch

`budget-alerts` → push subscription (OIDC as `budget-push`) → Cloud Run `kill-switch` in
glitch-monitoring (internal ingress, max 1 instance, CMEK, stdlib-only Python pulled through the
CMEK Docker Hub proxy `dockerhub`). For a `project:<id>` budget with cost ≥ amount it detaches
billing. Its SA holds `billing.projectManager` + `browser` **only on the DEV folder**, so prod and
Shared projects are refused by IAM whatever the code does.

`kill_switch_enforce = false` (default) only logs "would detach". Test end to end, then set it to
`true`:

```sh
gcloud pubsub topics publish budget-alerts --project glitch-monitoring \
  --message '{"budgetDisplayName":"project:glitch-ops-dev","costAmount":11,"budgetAmount":10}'
gcloud logging read 'resource.labels.service_name="kill-switch"' --project glitch-monitoring --freshness 10m
```

Re-enable billing on a killed project manually after fixing the cause (Billing → My projects).

## Cost

≈ $0.40/month: 6 manual keys × $0.06, Autokey keys free, audit-log volume in cents.

## Not here (yet)

- VPC-SC dry-run perimeter (ADR 016) — once internal workload projects exist
