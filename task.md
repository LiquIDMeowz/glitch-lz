# Tasks

Mirrors the ClickUp "GlitchLZ — implementation" task (Vladimir space).

| Task | Status | Notes |
|---|---|---|
| Repo guardrails (.gitignore, gitleaks hook, rulesets, security settings) | done | |
| Stage 0-bootstrap | done | Applied 2026-09-25 (56 resources); state in `glitch-tfstate-lz/0-bootstrap` |
| Stage 1-org | in-progress | Folders imported, tags, org policies (DRS dry run), contacts, identity audit logs |
| Stage 2-security | pending | Also fix Cost page budget section (ADR 017 → 022) |
| Stage 3-projects | pending | Adopt `vk-personal-dashboard`, `wedding2026-vk` via import |
| Stage 4-network | pending | Optional |
| CI: GitHub Actions + WIF for glitch-lz | done | PR gates: fmt, validate, tflint, checkov, plan (lz-plan SA); apply via env `lz-apply`. Plans not posted to PRs (public logs) |
| Promote DRS from dry run to enforced | pending | After reviewing dry-run violations |
| Remove legacy tags | pending | wedding: when retired/rebuilt; GlitchHub dev: after prod promotion + dev teardown |
