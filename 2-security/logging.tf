# Security logs (all Cloud Audit Logs) from every project land in one 90-day bucket; app logs
# stay in each project's _Default bucket (ADR 015).
resource "google_logging_project_bucket_config" "security" {
  project        = google_project.shared["logging"].project_id
  location       = var.region
  bucket_id      = "security"
  retention_days = 90
  description    = "Org-wide Cloud Audit Logs (ADR 015)"

  depends_on = [google_project_service.shared, google_project_iam_member.lz_apply]
}

resource "google_logging_organization_sink" "security" {
  name             = "security-audit-logs"
  org_id           = var.org_id
  destination      = "logging.googleapis.com/${google_logging_project_bucket_config.security.id}"
  include_children = true
  filter           = "logName:\"/logs/cloudaudit.googleapis.com%2F\""
}

resource "google_project_iam_member" "sink_writer" {
  project = google_project.shared["logging"].project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.security.writer_identity
}
