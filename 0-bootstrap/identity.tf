# Two LZ identities: a read-only planner for PRs and an apply SA that only a reviewed run on
# main can reach. Workload deployer SAs are created per project by 3-projects.
resource "google_service_account" "lz_plan" {
  project      = google_project.iac.project_id
  account_id   = "lz-plan"
  display_name = "GlitchLZ plan (read-only, PRs)"
}

resource "google_service_account" "lz_apply" {
  project      = google_project.iac.project_id
  account_id   = "lz-apply"
  display_name = "GlitchLZ apply (main + approval)"
}

resource "google_organization_iam_member" "lz_apply" {
  for_each = var.lz_apply_org_roles

  org_id = var.org_id
  role   = each.value
  member = google_service_account.lz_apply.member
}

resource "google_organization_iam_member" "lz_plan" {
  for_each = var.lz_plan_org_roles

  org_id = var.org_id
  role   = each.value
  member = google_service_account.lz_plan.member
}

resource "google_billing_account_iam_member" "lz_apply" {
  for_each = toset(["roles/billing.user", "roles/billing.costsManager"])

  billing_account_id = var.billing_account
  role               = each.value
  member             = google_service_account.lz_apply.member
}

resource "google_billing_account_iam_member" "lz_plan" {
  billing_account_id = var.billing_account
  role               = "roles/billing.viewer"
  member             = google_service_account.lz_plan.member
}

# glitch-iac is the quota project for every LZ API call
resource "google_project_iam_member" "quota" {
  for_each = {
    plan  = google_service_account.lz_plan.member
    apply = google_service_account.lz_apply.member
  }

  project = google_project.iac.project_id
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = each.value
}

# State access. The apply SA administers the dev/prod buckets because 3-projects grants each
# workload deployer access to its own prefix there. The planner runs with -lock=false.
resource "google_storage_bucket_iam_member" "lz_apply_state" {
  bucket = google_storage_bucket.state["lz"].name
  role   = "roles/storage.objectUser"
  member = google_service_account.lz_apply.member
}

resource "google_storage_bucket_iam_member" "lz_apply_workload_buckets" {
  for_each = toset(["dev", "prod"])

  bucket = google_storage_bucket.state[each.key].name
  role   = "roles/storage.admin"
  member = google_service_account.lz_apply.member
}

resource "google_storage_bucket_iam_member" "lz_plan_state" {
  bucket = google_storage_bucket.state["lz"].name
  role   = "roles/storage.objectViewer"
  member = google_service_account.lz_plan.member
}

# Operators may impersonate lz-plan for local read-only plans. Nobody impersonates lz-apply:
# that would be a standing org-admin path around PAM (ADR 045).
resource "google_service_account_iam_member" "plan_impersonation" {
  for_each = {
    vlad   = var.admin_email
    kalina = var.kalina_email
  }

  service_account_id = google_service_account.lz_plan.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "user:${each.value}"
}

moved {
  from = google_service_account_iam_member.admin_impersonation["plan"]
  to   = google_service_account_iam_member.plan_impersonation["vlad"]
}
