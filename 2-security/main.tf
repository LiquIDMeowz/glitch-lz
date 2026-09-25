locals {
  iac_project  = "glitch-iac"
  lz_apply     = "serviceAccount:lz-apply@${local.iac_project}.iam.gserviceaccount.com"
  folders      = data.terraform_remote_state.org.outputs.folders
  folder_id    = { for k, v in local.folders : k => trimprefix(v, "folders/") }
  labels       = { env = "shared", owner = "glitch", managed_by = "terraform" }
  project_apis = ["cloudkms.googleapis.com", "logging.googleapis.com", "monitoring.googleapis.com"]

  # Shared projects owned by this stage and the roles lz-apply needs inside them. Granted
  # explicitly (organizationAdmin can set project IAM) instead of relying on creator-owner.
  shared_projects = {
    kms-dev  = { apis = [], roles = ["roles/cloudkms.admin"] }
    kms-prod = { apis = [], roles = ["roles/cloudkms.admin"] }
    logging  = { apis = [], roles = ["roles/logging.admin"] }
    monitoring = {
      apis = ["artifactregistry.googleapis.com", "cloudbilling.googleapis.com", "pubsub.googleapis.com", "run.googleapis.com"]
      roles = [
        "roles/artifactregistry.admin",
        "roles/cloudkms.autokeyUser",
        "roles/iam.serviceAccountAdmin",
        "roles/iam.serviceAccountUser",
        "roles/monitoring.admin",
        "roles/pubsub.admin",
        "roles/run.admin",
      ]
    }
  }
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config = {
    bucket = "glitch-tfstate-lz"
    prefix = "1-org"
  }
}

data "google_project" "iac" {
  project_id = local.iac_project
}

resource "google_project" "shared" {
  #checkov:skip=CKV2_GCP_5:Data Access logs are enabled on logging/monitoring (audit.tf); key projects log admin activity only, because workload encrypt/decrypt calls would turn a traffic flood into a logging bill (ADR 021)
  for_each = local.shared_projects

  project_id      = "glitch-${each.key}"
  name            = "glitch-${each.key}"
  folder_id       = local.folder_id["shared"]
  billing_account = var.billing_account
  labels          = merge(local.labels, { app = each.key })

  auto_create_network = false
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "shared" {
  for_each = merge([
    for p, cfg in local.shared_projects : {
      for api in concat(local.project_apis, cfg.apis) : "${p}/${api}" => { project = p, api = api }
    }
  ]...)

  project            = google_project.shared[each.value.project].project_id
  service            = each.value.api
  disable_on_destroy = false
}

resource "google_project_iam_member" "lz_apply" {
  for_each = merge([
    for p, cfg in local.shared_projects : { for r in cfg.roles : "${p}/${r}" => { project = p, role = r } }
  ]...)

  project = google_project.shared[each.value.project].project_id
  role    = each.value.role
  member  = local.lz_apply
}
