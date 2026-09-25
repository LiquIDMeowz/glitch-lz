# Dev kill switch (ADR 035 / 023): budget-alerts → push → Cloud Run → detach billing.
# Billing rights only on the DEV folder, so prod and Shared projects are out of reach by IAM.
# ENFORCE=false logs "would detach" only; flip after the end-to-end test.

variable "kill_switch_enforce" {
  description = "false: log what would be detached; true: detach billing."
  type        = bool
  default     = false
}

locals {
  monitoring = google_project.shared["monitoring"].project_id
  # python:3.13-slim, pinned by digest, pulled through the CMEK Docker Hub proxy
  kill_switch_image = "${var.region}-docker.pkg.dev/${local.monitoring}/dockerhub/library/python@sha256:8d9d0b8bcf6506481eae4907c18f5e3e7902e629f5f6d684f9e7c32e85e3ddf0"
}

resource "google_service_account" "kill_switch" {
  project      = local.monitoring
  account_id   = "kill-switch"
  display_name = "Budget kill switch (detaches billing in DEV)"
}

resource "google_folder_iam_member" "kill_switch" {
  for_each = toset(["roles/billing.projectManager", "roles/browser"])

  folder = local.folders["dev"]
  role   = each.value
  member = google_service_account.kill_switch.member
}

resource "google_service_account" "budget_push" {
  project      = local.monitoring
  account_id   = "budget-push"
  display_name = "Pub/Sub push identity for the kill switch"
}

resource "google_kms_key_handle" "kill_switch" {
  for_each = {
    registry = "artifactregistry.googleapis.com/Repository"
    run      = "run.googleapis.com/Service"
  }

  project                = local.monitoring
  name                   = "kill-switch-${each.key}"
  location               = var.region
  resource_type_selector = each.value

  depends_on = [google_project_service.shared, google_project_iam_member.lz_apply]
}

resource "google_artifact_registry_repository" "dockerhub" {
  project       = local.monitoring
  location      = var.region
  repository_id = "dockerhub"
  description   = "CMEK proxy for Docker Hub base images"
  format        = "DOCKER"
  mode          = "REMOTE_REPOSITORY"
  kms_key_name  = google_kms_key_handle.kill_switch["registry"].kms_key
  labels        = local.labels

  remote_repository_config {
    docker_repository {
      public_repository = "DOCKER_HUB"
    }
  }

  # Keep the cache small: only what's in use
  cleanup_policies {
    id     = "delete-old"
    action = "DELETE"
    condition {
      older_than = "2592000s" # 30 days
    }
  }
}

resource "google_cloud_run_v2_service" "kill_switch" {
  project             = local.monitoring
  name                = "kill-switch"
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_INTERNAL_ONLY" # Pub/Sub push from the same project counts as internal
  deletion_protection = false
  labels              = local.labels

  template {
    service_account                  = google_service_account.kill_switch.email
    encryption_key                   = google_kms_key_handle.kill_switch["run"].kms_key
    execution_environment            = "EXECUTION_ENVIRONMENT_GEN2"
    max_instance_request_concurrency = 10
    timeout                          = "60s"

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image   = local.kill_switch_image
      command = ["python", "-c"]
      args    = [file("${path.module}/killswitch/main.py")]

      env {
        name  = "ENFORCE"
        value = tostring(var.kill_switch_enforce)
      }

      resources {
        limits   = { cpu = "1", memory = "512Mi" }
        cpu_idle = true
      }
    }
  }

  depends_on = [google_artifact_registry_repository.dockerhub]
}

resource "google_cloud_run_v2_service_iam_member" "budget_push" {
  project  = local.monitoring
  location = google_cloud_run_v2_service.kill_switch.location
  name     = google_cloud_run_v2_service.kill_switch.name
  role     = "roles/run.invoker"
  member   = google_service_account.budget_push.member
}

resource "google_pubsub_subscription" "kill_switch" {
  project                    = local.monitoring
  name                       = "kill-switch"
  topic                      = google_pubsub_topic.budget_alerts.id
  ack_deadline_seconds       = 60
  message_retention_duration = "86400s"
  labels                     = local.labels

  expiration_policy {
    ttl = "" # never expire
  }

  push_config {
    push_endpoint = google_cloud_run_v2_service.kill_switch.uri
    oidc_token {
      service_account_email = google_service_account.budget_push.email
    }
  }

  depends_on = [google_cloud_run_v2_service_iam_member.budget_push]
}
