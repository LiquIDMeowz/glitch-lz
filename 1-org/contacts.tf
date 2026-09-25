resource "google_essential_contacts_contact" "admin" {
  parent                              = local.org
  email                               = var.admin_email
  language_tag                        = "en"
  notification_category_subscriptions = ["ALL"]
}

# Data Access logs for identity only: who exchanged a GitHub token (sts) and who minted SA
# tokens (iamcredentials). Low volume; deliberately no KMS / storage data logs org-wide, which
# a request flood could turn into a logging bill (ADR 021).
resource "google_organization_iam_audit_config" "identity" {
  for_each = toset(["sts.googleapis.com", "iamcredentials.googleapis.com"])

  org_id  = var.org_id
  service = each.value

  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
}
