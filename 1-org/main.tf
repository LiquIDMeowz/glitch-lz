locals {
  org = "organizations/${var.org_id}"

  # Projects created before the LZ. Tagged legacy=true: exempt from the CMEK and DRS policies
  # until they're rebuilt as factory projects (ADR 031). Project IDs aren't secrets.
  legacy_projects = {
    glitchhub_dev = "vk-personal-dashboard"
    wedding       = "project-a60d576f-3d59-42e0-b1f"
  }

  # Public Cloud Run behind Firebase / direct (ADR 013)
  public_ingress_projects = {
    wedding = "project-a60d576f-3d59-42e0-b1f"
  }

  folders = { shared = "Shared", dev = "DEV", prod = "PROD" }
}

# Look up IDs instead of committing them (public repo, ADR 025)
data "google_folders" "top" {
  parent_id = local.org
}

data "google_project" "tagged" {
  for_each   = merge(local.legacy_projects, local.public_ingress_projects)
  project_id = each.value
}

locals {
  folder_ids = {
    for key, display_name in local.folders :
    key => one([for f in data.google_folders.top.folders : f.name if f.display_name == display_name])
  }
}
