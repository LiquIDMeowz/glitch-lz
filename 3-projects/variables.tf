variable "billing_account" {
  description = "Billing account linked to factory projects."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west3"
}

variable "budget_usd" {
  description = "Monthly budget per project (ADR 035)."
  type        = number
  default     = 10
}
