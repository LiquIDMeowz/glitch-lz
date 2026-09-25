output "projects" {
  description = "Shared project IDs by key."
  value       = { for k, p in google_project.shared : k => p.project_id }
}

output "manual_keys" {
  description = "Manual CMEK keys by env/service (Firestore, Cloud Tasks, Cloud Run functions)."
  value       = { for k, key in google_kms_crypto_key.manual : k => key.id }
}

output "budget_topic" {
  value = google_pubsub_topic.budget_alerts.id
}

output "notification_channel" {
  value = google_monitoring_notification_channel.admin_email.id
}

output "monitoring_project" {
  value = google_project.shared["monitoring"].project_id
}
