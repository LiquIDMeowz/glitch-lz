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

variable "kalina_email" {
  description = "Second operator (Gmail): read-only standing access + PAM elevation (ADR 045)."
  type        = string
  sensitive   = true
}
