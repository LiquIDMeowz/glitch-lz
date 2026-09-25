# $10 tripwire per project (ADR 035) and the shared metrics scope, for factory and legacy
# projects alike. "project:<id>" is how the kill switch maps an alert to a project.
data "google_project" "legacy" {
  for_each   = local.legacy_projects
  project_id = each.value
}

locals {
  budget_projects = merge(
    { for key, p in google_project.app : p.project_id => p.number },
    { for key, p in data.google_project.legacy : p.project_id => p.number },
  )
}

resource "google_billing_budget" "project" {
  for_each = local.budget_projects

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
    pubsub_topic                     = local.security.budget_topic
    monitoring_notification_channels = [local.security.notification_channel]
    disable_default_iam_recipients   = false
  }
}

resource "google_monitoring_monitored_project" "project" {
  for_each = local.budget_projects

  metrics_scope = local.security.monitoring_project
  name          = each.key

  depends_on = [google_project_service.app]
}
