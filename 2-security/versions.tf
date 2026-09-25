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

# No provider-level quota-project override: it sent every call (e.g. Pub/Sub) with glitch-iac as
# quota project (ERR-003b). Service accounts don't need it; local ADC uses glitch-iac already.
provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}
