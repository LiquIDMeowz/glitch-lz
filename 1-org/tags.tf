# Tags drive org-policy exceptions (ADR 018). Conditions use matchTagId, so no names are parsed.
locals {
  tags = {
    env      = ["shared", "dev", "prod"]
    ingress  = ["public"] # run.allowedIngress exception
    location = ["eu"]     # gcp.resourceLocations exception: any EU region
    legacy   = ["true"]   # pre-LZ projects: CMEK / DRS exemptions
  }

  tag_values = merge([
    for key, values in local.tags : { for value in values : "${key}/${value}" => { key = key, value = value } }
  ]...)
}

resource "google_tags_tag_key" "this" {
  for_each = local.tags

  parent     = local.org
  short_name = each.key
}

resource "google_tags_tag_value" "this" {
  for_each = local.tag_values

  parent     = google_tags_tag_key.this[each.value.key].id
  short_name = each.value.value
}

resource "google_tags_tag_binding" "folder_env" {
  for_each = local.folders

  parent    = "//cloudresourcemanager.googleapis.com/${google_folder.top[each.key].name}"
  tag_value = google_tags_tag_value.this["env/${each.key}"].id
}

resource "google_tags_tag_binding" "legacy" {
  for_each = local.legacy_projects

  parent    = "//cloudresourcemanager.googleapis.com/projects/${data.google_project.tagged[each.key].number}"
  tag_value = google_tags_tag_value.this["legacy/true"].id
}

resource "google_tags_tag_binding" "public_ingress" {
  for_each = local.public_ingress_projects

  parent    = "//cloudresourcemanager.googleapis.com/projects/${data.google_project.tagged[each.key].number}"
  tag_value = google_tags_tag_value.this["ingress/public"].id
}

locals {
  # CEL conditions for org-policy rules
  match_tag = {
    for k, v in google_tags_tag_value.this :
    k => "resource.matchTagId('${google_tags_tag_key.this[split("/", k)[0]].id}', '${v.id}')"
  }
}
