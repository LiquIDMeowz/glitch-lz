# GitHub Actions federation. The repos are public (ADR 025), so trust is pinned to numeric
# GitHub IDs and enforced here, not only in GitHub settings.
resource "google_iam_workload_identity_pool" "github" {
  project                   = google_project.iac.project_id
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  description               = "Keyless CI for Glitch repos"

  depends_on = [google_project_service.iac]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  #checkov:skip=CKV_GCP_118:attribute_condition is set; checkov can't resolve the variable inside it
  #checkov:skip=CKV_GCP_125:Trust is pinned to numeric owner/repo IDs (immune to repo rename or re-creation), not the name-based sub claim this check parses
  project                            = google_project.iac.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions OIDC"

  # Every job that authenticates to GCP must declare a GitHub environment: the mapping reads
  # assertion.environment, so jobs without one fail the token exchange.
  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository_id"    = "assertion.repository_id"
    "attribute.repo_env"         = "assertion.repository_id + '/' + assertion.environment"
    "attribute.repo_env_ref"     = "assertion.repository_id + '/' + assertion.environment + '/' + assertion.ref"
    "attribute.repository_owner" = "assertion.repository_owner_id"
  }

  attribute_condition = "assertion.repository_owner_id == '${var.github_owner_id}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

locals {
  wif_principal_set = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}"
}

# PR plans: environment lz-plan (no reviewers), any branch of glitch-lz
resource "google_service_account_iam_member" "lz_plan_wif" {
  service_account_id = google_service_account.lz_plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.wif_principal_set}/attribute.repo_env/${var.lz_repo_id}/lz-plan"
}

# Apply: environment lz-apply (required reviewer) AND ref main, checked on the GCP side too
resource "google_service_account_iam_member" "lz_apply_wif" {
  service_account_id = google_service_account.lz_apply.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "${local.wif_principal_set}/attribute.repo_env_ref/${var.lz_repo_id}/lz-apply/refs/heads/main"
}
