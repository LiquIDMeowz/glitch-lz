# glitch-monitoring scopes metrics for the Shared projects; 3-projects adds workload projects.
resource "google_monitoring_notification_channel" "admin_email" {
  project      = google_project.shared["monitoring"].project_id
  display_name = "Admin email"
  type         = "email"
  labels = {
    email_address = var.admin_email
  }

  depends_on = [google_project_service.shared, google_project_iam_member.lz_apply]
}

resource "google_monitoring_monitored_project" "shared" {
  for_each = toset(concat([local.iac_project], [for k in keys(local.shared_projects) : "glitch-${k}" if k != "monitoring"]))

  metrics_scope = google_project.shared["monitoring"].project_id
  name          = each.value

  depends_on = [google_project.shared, google_project_iam_member.lz_apply]
}

# Budget alerts topic: every budget publishes here; the kill switch subscribes (ADR 017 / 023).
# CMEK via Autokey same-project keys (Shared folder).
resource "google_kms_key_handle" "budget_topic" {
  project                = google_project.shared["monitoring"].project_id
  name                   = "budget-alerts"
  location               = var.region
  resource_type_selector = "pubsub.googleapis.com/Topic"

  depends_on = [google_project_service.shared, google_project_iam_member.lz_apply]
}

resource "google_pubsub_topic" "budget_alerts" {
  project      = google_project.shared["monitoring"].project_id
  name         = "budget-alerts"
  kms_key_name = google_kms_key_handle.budget_topic.kms_key
  labels       = local.labels

  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

# Budgets publish as this Google system account (allowed in the DRS policy)
resource "google_pubsub_topic_iam_member" "budget_publisher" {
  project = google_pubsub_topic.budget_alerts.project
  topic   = google_pubsub_topic.budget_alerts.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:billing-budget-alert@system.gserviceaccount.com"
}
