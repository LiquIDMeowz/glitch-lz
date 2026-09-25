locals {
  envs = ["dev", "prod"]

  # Every factory project gets these on top of the app's own list
  base_apis = [
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "serviceusage.googleapis.com",
  ]

  # Deployer roles inside its own project only. No projectIamAdmin: a deployer can't grant
  # itself more than this list (add per app when truly needed).
  base_roles = [
    "roles/cloudkms.autokeyUser",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/logging.configWriter",
    "roles/serviceusage.serviceUsageConsumer",
  ]

  projects = merge([
    for app, cfg in local.apps : {
      for env in local.envs : "${app}-${env}" => merge(cfg, {
        app        = app
        env        = env
        project_id = "glitch-${app}-${env}"
      })
    }
  ]...)

  bootstrap  = data.terraform_remote_state.bootstrap.outputs
  org        = data.terraform_remote_state.org.outputs
  security   = data.terraform_remote_state.security.outputs
  wif_prefix = "principalSet://iam.googleapis.com/${local.bootstrap.wif_pool}"
}

data "terraform_remote_state" "bootstrap" {
  backend = "gcs"
  config  = { bucket = "glitch-tfstate-lz", prefix = "0-bootstrap" }
}

data "terraform_remote_state" "org" {
  backend = "gcs"
  config  = { bucket = "glitch-tfstate-lz", prefix = "1-org" }
}

data "terraform_remote_state" "security" {
  backend = "gcs"
  config  = { bucket = "glitch-tfstate-lz", prefix = "2-security" }
}

resource "google_project" "app" {
  #checkov:skip=CKV2_GCP_5:Workload Data Access logs (IAP authz, Storage reads) scale per request, so a flood would become a logging bill here and in the org security sink (ADR 021); admin activity is always logged
  for_each = local.projects

  project_id      = each.value.project_id
  name            = each.value.project_id
  folder_id       = trimprefix(local.org.folders[each.value.env], "folders/")
  billing_account = var.billing_account
  labels = {
    app        = each.value.app
    env        = each.value.env
    owner      = "glitch"
    managed_by = "terraform"
  }

  auto_create_network = false
  deletion_policy     = "PREVENT"
}

resource "google_project_service" "app" {
  for_each = merge([
    for key, p in local.projects : {
      for api in distinct(concat(local.base_apis, p.apis)) : "${key}/${api}" => { project = key, api = api }
    }
  ]...)

  project            = google_project.app[each.value.project].project_id
  service            = each.value.api
  disable_on_destroy = false
}

# env=dev/prod is inherited from the folder; ingress=public is per project
resource "google_tags_tag_binding" "public_ingress" {
  for_each = { for key, p in local.projects : key => p if p.public_ingress }

  parent    = "//cloudresourcemanager.googleapis.com/projects/${google_project.app[each.key].number}"
  tag_value = local.org.tag_values["ingress/public"]
}
