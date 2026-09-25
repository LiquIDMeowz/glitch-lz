# The folders predate the LZ; adopt them instead of recreating
import {
  for_each = local.folders
  to       = google_folder.top[each.key]
  id       = local.folder_ids[each.key]
}

resource "google_folder" "top" {
  for_each = local.folders

  display_name        = each.value
  parent              = local.org
  deletion_protection = true
}
