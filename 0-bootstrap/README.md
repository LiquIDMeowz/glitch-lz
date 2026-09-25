# 0-bootstrap

Creates what every other stage needs before CI can run Terraform:

- `glitch-iac` project (Shared folder) — quota project for all LZ API calls
- Autokey in same-project mode on the Shared folder + one key per state bucket (ADR 026)
- State buckets `glitch-tfstate-{lz,dev,prod}` — one per trust boundary, CMEK, versioned
- `lz-plan` (read-only, PR plans) and `lz-apply` (stages 1–4) service accounts
- GitHub Actions Workload Identity Federation pool, pinned to the GitHub owner ID

Only a human admin applies this stage; CI never runs it.

## Identity rules

| SA | Federated from | Can |
|---|---|---|
| `lz-plan` | glitch-lz job in environment `lz-plan` (any ref) | Read org, billing, LZ state |
| `lz-apply` | glitch-lz job in environment `lz-apply` **on `refs/heads/main`** | Administer org for stages 1–4 |

Every job that authenticates to GCP must declare a GitHub environment — the provider mapping
reads `assertion.environment`, so jobs without one can't exchange tokens.

## Running

```sh
cp terraform.tfvars.example terraform.tfvars   # real IDs, git-ignored
terraform init -backend-config=backend/lz.hcl
terraform plan
```

The first apply ran with local state and was migrated with
`terraform init -migrate-state -backend-config=backend/lz.hcl`.

## Cost

≈ $0.01/month: Autokey keys are in the KMS free tier, state is kilobytes, WIF / SAs / IAM are free.
