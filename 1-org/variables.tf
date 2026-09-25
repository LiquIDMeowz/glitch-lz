variable "org_id" {
  description = "Numeric organization ID."
  type        = string
}

variable "admin_email" {
  description = "Admin (Gmail, no Workspace): essential contact and explicit DRS exception (ADR 012)."
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west3"
}
