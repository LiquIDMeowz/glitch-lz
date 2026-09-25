output "project_id" {
  value = google_project.iac.project_id
}

output "project_number" {
  value = google_project.iac.number
}

output "state_buckets" {
  value = { for k, b in google_storage_bucket.state : k => b.name }
}

output "lz_plan_sa" {
  value = google_service_account.lz_plan.email
}

output "lz_apply_sa" {
  value = google_service_account.lz_apply.email
}

output "wif_provider" {
  description = "Value for google-github-actions/auth workload_identity_provider."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "wif_pool" {
  description = "Pool resource name; 3-projects binds workload deployer SAs to it."
  value       = google_iam_workload_identity_pool.github.name
}

output "tfstate_lister_role" {
  description = "Custom role ID for workload deployers on the dev/prod state buckets."
  value       = google_project_iam_custom_role.tfstate_lister.id
}
