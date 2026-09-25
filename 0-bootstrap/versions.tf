terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.4"
    }
  }
}

# 0-bootstrap runs with the admin's own credentials. Without an explicit quota project those
# calls fall back to the shared Cloud SDK project, whose billing-API quota is exhausted
# (429 retries until timeout, ERR-004). glitch-iac exists since the first apply.
provider "google" {
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}
