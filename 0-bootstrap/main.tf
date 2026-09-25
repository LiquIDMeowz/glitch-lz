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

resource "google_project_service" "iac" {
  for_each = toset(local.services)

  project            = google_project.iac.project_id
  service            = each.value
  disable_on_destroy = false
}
