locals {
  labels = {
    app        = "iac"
    env        = "shared"
    owner      = "glitch"
    managed_by = "terraform"
  }

  # glitch-iac is the quota project for every LZ stage, so it needs the APIs they call
  services = [
    "accesscontextmanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudbilling.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "essentialcontacts.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "orgpolicy.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
    "sts.googleapis.com",
  ]
}

resource "google_project" "iac" {
  project_id      = var.project_id
  name            = var.project_id
  folder_id       = var.shared_folder_id
  billing_account = var.billing_account
  labels          = local.labels

  auto_create_network = false
  deletion_policy     = "PREVENT"
}

# Data Access audit logs on glitch-iac record who read or wrote state and keys. Replaces bucket
# access logs (CKV_GCP_62). Volume is a handful of entries per CI run, well within the free tier.
resource "google_project_iam_audit_config" "iac" {
  project = google_project.iac.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_project_service" "iac" {
  for_each = toset(local.services)

  project            = google_project.iac.project_id
  service            = each.value
  disable_on_destroy = false
}
