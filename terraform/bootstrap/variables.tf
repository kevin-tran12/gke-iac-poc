variable "project_id" {
  description = "Globally unique ID for the disposable portfolio project."
  type        = string
}

variable "project_name" {
  type    = string
  default = "GKE Cloud Engineering Lab"
}

variable "billing_account" {
  description = "Billing account ID used only for the dedicated lab project."
  type        = string
  sensitive   = true
}

variable "organization_id" {
  description = "Optional Google Cloud organization that owns the lab project. Preserve the existing organization when importing a project."
  type        = string
  default     = null
  nullable    = true
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID."
  type        = string
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name form, used to allowlist reviewed apply workflows."
  type        = string
  default     = "kevin-tran12/gke-iac-poc"
}

variable "budget_amount_usd" {
  type    = number
  default = 75
}

variable "labels" {
  type = map(string)
  default = {
    environment = "ephemeral-lab"
    managed-by  = "terraform"
    portfolio   = "gke-iac-poc"
  }
}
