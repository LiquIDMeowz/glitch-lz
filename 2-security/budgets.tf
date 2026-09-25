# Budgets alert; they never cap spend (ADR 035). Hard limits are max_instances, quotas and the
# dev kill switch.

# The ceiling: everything on the billing account
resource "google_billing_budget" "account" {
  billing_account = var.billing_account
  display_name    = "billing-account-total"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_usd)
    }
  }

  budget_filter {
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 1.0, 1.5, 2.0]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    monitoring_notification_channels = [google_monitoring_notification_channel.admin_email.id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_pubsub_topic_iam_member.budget_publisher]
}

# Per-project tripwires for the Shared projects (alert only, never killed: they run the LZ).
# Display name "project:<id>" is how the kill switch maps an alert to a project.
locals {
  shared_budget_projects = merge(
    { (local.iac_project) = data.google_project.iac.number },
    { for k, p in google_project.shared : p.project_id => p.number },
  )
}

resource "google_billing_budget" "shared_project" {
  for_each = local.shared_budget_projects

  billing_account = var.billing_account
  display_name    = "project:${each.key}"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_usd)
    }
  }

  budget_filter {
    projects               = ["projects/${each.value}"]
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    monitoring_notification_channels = [google_monitoring_notification_channel.admin_email.id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_pubsub_topic_iam_member.budget_publisher]
}
