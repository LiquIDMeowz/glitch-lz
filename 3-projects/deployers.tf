# One deployer per project, reachable only from the app's repo and GitHub environment.
# dev: any ref (PRs plan dev); prod: refs/heads/main only, enforced here as well as in GitHub
# (ADR 038).
resource "google_service_account" "deployer" {
  for_each = local.projects

  project      = google_project.app[each.key].project_id
  account_id   = "deployer"
  display_name = "Deployer (GitHub ${each.value.app} / ${each.value.env})"

  depends_on = [google_project_service.app]
}

resource "google_project_iam_member" "deployer" {
  for_each = merge([
    for key, p in local.projects : {
      for role in distinct(concat(local.base_roles, p.roles)) : "${key}/${role}" => { project = key, role = role }
    }
  ]...)

  project = google_project.app[each.value.project].project_id
  role    = each.value.role
  member  = google_service_account.deployer[each.value.project].member
}

resource "google_service_account_iam_member" "deployer_wif" {
  for_each = local.projects

  service_account_id = google_service_account.deployer[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member = (
    each.value.env == "prod"
    ? "${local.wif_prefix}/attribute.repo_env_ref/${each.value.repo_id}/prod/refs/heads/main"
    : "${local.wif_prefix}/attribute.repo_env/${each.value.repo_id}/${each.value.env}"
  )
}

# State: list names in the env bucket, read/write only the app's own prefix (ADR 039)
resource "google_storage_bucket_iam_member" "state_list" {
  for_each = local.projects

  bucket = local.bootstrap.state_buckets[each.value.env]
  # Fixed ID of the custom role from 0-bootstrap (referenced literally so plans work before it exists)
  role   = "projects/glitch-iac/roles/tfStateLister"
  member = google_service_account.deployer[each.key].member
}

resource "google_storage_bucket_iam_member" "state_prefix" {
  for_each = local.projects

  bucket = local.bootstrap.state_buckets[each.value.env]
  role   = "roles/storage.objectUser"
  member = google_service_account.deployer[each.key].member

  condition {
    title      = "own-prefix-${each.value.app}-${each.value.env}"
    expression = "resource.name.startsWith(\"projects/_/buckets/${local.bootstrap.state_buckets[each.value.env]}/objects/${each.value.app}/${each.value.env}/\")"
  }
}
