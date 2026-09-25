# Same-project Autokey for the Shared folder: glitch-iac (and later glitch-logging /
# glitch-monitoring) keep keys in their own project, so LZ state never depends on the key
# projects that 2-security creates for DEV / PROD, and Autokey keys fall in the KMS free tier
# (ADR 026). The provider only supports folder-level Autokey config.
resource "google_kms_autokey_config" "shared" {
  folder                      = var.shared_folder_id
  key_project_resolution_mode = "RESOURCE_PROJECT"
}

resource "google_kms_key_handle" "state" {
  for_each = local.state_buckets

  project                = google_project.iac.project_id
  name                   = "tfstate-${each.key}"
  location               = var.region
  resource_type_selector = "storage.googleapis.com/Bucket"

  depends_on = [google_kms_autokey_config.shared, google_project_service.iac]
}
