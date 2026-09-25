# Tasks

Mirrors the ClickUp "GlitchLZ — implementation" task (Vladimir space).

| Task | Status | Notes |
|---|---|---|
| Repo guardrails (.gitignore, gitleaks hook, rulesets, security settings) | done | |
| Stage 0-bootstrap | done | Applied 2026-09-25 (56 resources); state in `glitch-tfstate-lz/0-bootstrap` |
| Stage 1-org | done | Applied 2026-09-25; CMEK list 11 services; DRS in dry run |
| Stage 2-security | done | KMS projects + Autokey + manual keys, security log sink, monitoring, $10 budgets. Also fix Cost page budget section in the ClickUp design doc (ADR 035) |
| Stage 3-projects | done | Factory + first app `ops` (GlitchOps); legacy projects budget + metrics scope only |
| Stage 4-network | pending | Optional |
| CI: GitHub Actions + WIF for glitch-lz | done | PR gates: fmt, validate, tflint, checkov, plan (lz-plan SA); apply via env `lz-apply`. Plans not posted to PRs (public logs) |
| Promote DRS from dry run to enforced | pending | After reviewing dry-run violations |
| Remove legacy tags | pending | wedding: when retired/rebuilt; GlitchHub dev: after prod promotion + dev teardown |
| Dev kill switch (budget-alerts → detach billing) | in-progress | Log-only test passed; enforcing; real tests: prod → 403, dev → detach + re-link |
| VPC-SC dry-run perimeter | pending | Once internal workload projects exist |
| Delete old GlitchHub $5 budget | pending | After 3-projects creates `project:vk-personal-dashboard` |
