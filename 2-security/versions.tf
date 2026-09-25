terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.4"
    }
    # google_project_service_identity (KMS service agents) is beta-only
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.4"
    }
  }
}

# Budgets and some org-level APIs need an explicit quota project
provider "google" {
  region                = var.region
  billing_project       = local.iac_project
  user_project_override = true
}

provider "google-beta" {
  region                = var.region
  billing_project       = local.iac_project
  user_project_override = true
}
