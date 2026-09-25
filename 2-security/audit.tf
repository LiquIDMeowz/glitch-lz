# Data Access audit logs where volume stays tiny. Not on the key projects: every workload
# encrypt/decrypt would be logged there (see the skip on google_project.shared).
resource "google_project_iam_audit_config" "shared" {
  for_each = toset(["logging", "monitoring"])

  project = google_project.shared[each.value].project_id
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
