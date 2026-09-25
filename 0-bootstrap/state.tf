locals {
  # One bucket per trust boundary: reading state = reading secrets (ADR 005)
  state_buckets = toset(["lz", "dev", "prod"])
}

resource "google_storage_bucket" "state" {
  #checkov:skip=CKV_GCP_62:Access is recorded by Data Access audit logs on glitch-iac (main.tf); usage-log buckets add cost without more detail
  for_each = local.state_buckets

  project  = google_project.iac.project_id
  name     = "${var.state_bucket_prefix}-${each.key}"
  location = var.region
  labels   = merge(local.labels, { boundary = each.key })

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  encryption {
    default_kms_key_name = google_kms_key_handle.state[each.key].kms_key
  }

  # Keep enough history to roll back a bad apply without paying for every version forever
  lifecycle_rule {
    condition {
      num_newer_versions = 20
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 90
      with_state                 = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
