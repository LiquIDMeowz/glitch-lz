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

Shared projects are never killed. The dev kill switch (detach billing at 100 %) subscribes to
`budget-alerts` and maps `project:<id>` display names to projects — added with 3-projects.

## Cost

≈ $0.40/month: 6 manual keys × $0.06, Autokey keys free, audit-log volume in cents.

## Not here (yet)

- Kill switch function — with 3-projects, once dev projects exist
- VPC-SC dry-run perimeter (ADR 016) — once internal workload projects exist
