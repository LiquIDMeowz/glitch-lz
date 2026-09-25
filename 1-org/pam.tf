# Just-in-time elevation with Privileged Access Manager (ADR 045), for Kalina. Vlad keeps
# standing access for now and is the approver.
#   DEV:  self-service, roles/writer (no IAM admin, so no permanent self-grants), up to 8h
#   PROD: approved by Vlad, roles/writer, up to 2h
#   ORG:  approved by Vlad, organizationAdmin (covers Shared), up to 2h
# PAM can't grant legacy basic roles (owner/editor/viewer) or billing-account roles.

# PAM only ever uses the org-level service agent, whatever the entitlement scope
resource "google_organization_iam_member" "pam_agent" {
  org_id = var.org_id
  role   = "roles/privilegedaccessmanager.serviceAgent"
  member = "serviceAccount:service-org-${var.org_id}@gcp-sa-pam.iam.gserviceaccount.com"
}

locals {
  vlad   = "user:${var.admin_email}"
  kalina = "user:${var.kalina_email}"

  entitlements = {
    dev-writer = {
      scope    = google_folder.top["dev"].name
      type     = "Folder"
      roles    = ["roles/writer"]
      approver = null
      max      = "28800s"
    }
    prod-writer = {
      scope    = google_folder.top["prod"].name
      type     = "Folder"
      roles    = ["roles/writer"]
      approver = local.vlad
      max      = "7200s"
    }
    org-admin = {
      scope    = local.org
      type     = "Organization"
      roles    = ["roles/resourcemanager.organizationAdmin"]
      approver = local.vlad
      max      = "7200s"
    }
  }
}

resource "google_privileged_access_manager_entitlement" "this" {
  for_each = local.entitlements

  entitlement_id       = each.key
  parent               = each.value.scope
  location             = "global"
  max_request_duration = each.value.max

  eligible_users {
    principals = [local.kalina]
  }

  privileged_access {
    gcp_iam_access {
      resource_type = "cloudresourcemanager.googleapis.com/${each.value.type}"
      resource      = "//cloudresourcemanager.googleapis.com/${each.value.scope}"

      dynamic "role_bindings" {
        for_each = each.value.roles
        content {
          role = role_bindings.value
        }
      }
    }
  }

  requester_justification_config {
    unstructured {}
  }

  dynamic "approval_workflow" {
    for_each = each.value.approver == null ? [] : [each.value.approver]
    content {
      manual_approvals {
        require_approver_justification = true
        steps {
          approvals_needed = 1
          approvers {
            principals = [approval_workflow.value]
          }
        }
      }
    }
  }

  depends_on = [google_organization_iam_member.pam_agent]
}
