variable "org_id" {
  description = "Numeric organization ID."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID linked to glitch-iac."
  type        = string
  sensitive   = true
}

variable "shared_folder_id" {
  description = "Numeric ID of the Shared folder that holds glitch-iac."
  type        = string
}

variable "admin_email" {
  description = "Break-glass human admin; may impersonate the LZ service accounts for local runs."
  type        = string
  sensitive   = true
}

variable "github_owner_id" {
  description = "Numeric GitHub account ID allowed to federate (IDs survive renames, unlike names)."
  type        = string
}

variable "lz_repo_id" {
  description = "Numeric GitHub repository ID of glitch-lz."
  type        = string
}

variable "project_id" {
  description = "Project ID for the IaC project."
  type        = string
  default     = "glitch-iac"
}

variable "region" {
  description = "Default region; the org location policy allows only this one."
  type        = string
  default     = "europe-west3"
}

variable "state_bucket_prefix" {
  description = "State buckets are named <prefix>-lz, <prefix>-dev, <prefix>-prod."
  type        = string
  default     = "glitch-tfstate"
}

variable "lz_apply_org_roles" {
  description = "Org-level roles for the LZ apply SA, used by stages 1-4."
  type        = set(string)
  default = [
    "roles/resourcemanager.organizationAdmin", # org / folder / project IAM
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/resourcemanager.tagAdmin",
    "roles/resourcemanager.tagUser",
    "roles/orgpolicy.policyAdmin",
    # No roles/iam.securityAdmin (CKV_GCP_45): the SA owns the projects it creates, and
    # 3-projects grants it roles/iam.serviceAccountAdmin only on adopted projects.
    "roles/logging.configWriter",
    "roles/essentialcontacts.admin",
    "roles/cloudkms.autokeyAdmin",
    "roles/serviceusage.serviceUsageAdmin", # adopted projects (not created by the SA)
    "roles/accesscontextmanager.policyAdmin",
    "roles/monitoring.metricsScopesAdmin", # link projects into glitch-monitoring's scope (ERR-003c)
  ]
}

variable "lz_plan_org_roles" {
  description = "Org-level read-only roles for the LZ plan SA (PR plans). Curated instead of roles/viewer (CKV_GCP_115); extend when a stage's plan hits a 403."
  type        = set(string)
  default = [
    "roles/browser",
    "roles/iam.securityReviewer",
    "roles/iam.serviceAccountViewer",
    "roles/iam.workloadIdentityPoolViewer",
    "roles/orgpolicy.policyViewer",
    "roles/resourcemanager.tagViewer",
    "roles/serviceusage.serviceUsageViewer",
    "roles/logging.viewer",
    "roles/monitoring.viewer",
    "roles/pubsub.viewer",
    "roles/run.viewer",
    "roles/artifactregistry.reader",
    "roles/cloudkms.viewer",
    "roles/storage.bucketViewer",
    "roles/essentialcontacts.viewer",
    "roles/accesscontextmanager.policyReader",
  ]
}
