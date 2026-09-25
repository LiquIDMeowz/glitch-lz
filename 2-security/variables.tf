variable "org_id" {
  description = "Numeric organization ID."
  type        = string
}

variable "billing_account" {
  description = "Billing account ID for the Shared projects and budgets."
  type        = string
  sensitive   = true
}

variable "admin_email" {
  description = "Receives budget and monitoring alerts."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west3"
}

variable "budget_usd" {
  description = "Monthly budget: billing-account ceiling and per-project tripwire (ADR 035)."
  type        = number
  default     = 10
}
