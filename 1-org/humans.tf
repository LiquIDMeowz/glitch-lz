# Human access (ADR 045). Vlad keeps his existing standing roles (super admin / break-glass, set
# outside Terraform). Kalina: standing read-only here, hands-on work via PAM (pam.tf). Billing
# account IAM is set by hand (lz-apply isn't a billing admin): Kalina has billing viewer.
locals {
  # Can't key a for_each on sensitive values, so operators are fixed keys → sensitive emails
  operators = {
    kalina = var.kalina_email
  }

  standing_read_roles = toset([
    "roles/browser",
    "roles/iam.securityReviewer",
    "roles/logging.viewer",
    "roles/monitoring.viewer",
    "roles/orgpolicy.policyViewer",
    "roles/privilegedaccessmanager.viewer",
    "roles/resourcemanager.tagViewer",
  ])
}

resource "google_organization_iam_member" "operator_read" {
  for_each = {
    for pair in setproduct(keys(local.operators), local.standing_read_roles) :
    "${pair[0]}/${pair[1]}" => { operator = pair[0], role = pair[1] }
  }

  org_id = var.org_id
  role   = each.value.role
  member = "user:${local.operators[each.value.operator]}"
}

# Operators' CLI calls (e.g. `gcloud pam grants create`) need a quota project with the APIs
# enabled; otherwise they hit the shared Cloud SDK project's quota (ERR-004). Set once with
# `gcloud config set billing/quota_project glitch-iac`. Vlad is covered by his standing roles.
resource "google_project_iam_member" "operator_quota" {
  for_each = local.operators

  project = "glitch-iac"
  role    = "roles/serviceusage.serviceUsageConsumer"
  member  = "user:${each.value}"
}
