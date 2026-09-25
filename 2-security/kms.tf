# Autokey for DEV / PROD: keys live in dedicated key projects (ADR 011). The Shared folder uses
# same-project keys (0-bootstrap, ADR 026).
locals {
  key_envs = { dev = "kms-dev", prod = "kms-prod" }

  # Services the CMEK policy requires but Autokey can't key (ADR 033): one shared key per
  # service per environment, rotated yearly so version count (and cost) stays flat.
  manual_keys = ["firestore", "cloudtasks", "cloudfunctions"]
}

resource "google_project_service_identity" "kms_agent" {
  provider = google-beta
  for_each = local.key_envs

  project = google_project.shared[each.value].project_id
  service = "cloudkms.googleapis.com"

  depends_on = [google_project_service.shared]
}

# Autokey's service agent creates keys and binds them to workload service agents
resource "google_project_iam_member" "kms_agent_admin" {
  for_each = local.key_envs

  project = google_project.shared[each.value].project_id
  role    = "roles/cloudkms.admin"
  member  = google_project_service_identity.kms_agent[each.key].member
}

resource "google_kms_autokey_config" "env" {
  for_each = local.key_envs

  folder                      = local.folder_id[each.key]
  key_project                 = "projects/${google_project.shared[each.value].project_id}"
  key_project_resolution_mode = "DEDICATED_KEY_PROJECT"

  depends_on = [google_project_iam_member.kms_agent_admin]
}

resource "google_kms_key_ring" "manual" {
  for_each = local.key_envs

  project  = google_project.shared[each.value].project_id
  name     = "cmek-manual"
  location = var.region

  depends_on = [google_project_iam_member.lz_apply, google_project_service.shared]
}

resource "google_kms_crypto_key" "manual" {
  #checkov:skip=CKV_GCP_43:Yearly rotation like Autokey keys; each version costs $0.06/month and can't be destroyed while data uses it, so 90-day rotation grows cost ~4x per year (ADR 021)
  for_each = merge([
    for env in keys(local.key_envs) : { for svc in local.manual_keys : "${env}/${svc}" => { env = env, svc = svc } }
  ]...)

  name            = each.value.svc
  key_ring        = google_kms_key_ring.manual[each.value.env].id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "31536000s" # 365 days
  labels          = merge(local.labels, { env = each.value.env, service = each.value.svc })

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = true
  }
}
