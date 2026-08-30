variable "project_id" {
  description = "Globally unique ID for the disposable portfolio project."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must satisfy the Google Cloud project ID format."
  }
}

variable "project_name" {
  type    = string
  default = "GKE Cloud Engineering Lab"
}

variable "billing_account" {
  description = "Billing account ID used only for the dedicated lab project."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}$", var.billing_account))
    error_message = "billing_account must use the 000000-000000-000000 form."
  }
}

variable "organization_id" {
  description = "Optional Google Cloud organization that owns the lab project. Preserve the existing organization when importing a project."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.organization_id == null || can(regex("^[0-9]+$", var.organization_id))
    error_message = "organization_id must be null or a numeric organization ID."
  }
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "github_owner_id" {
  description = "Immutable numeric GitHub owner ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_owner_id))
    error_message = "github_owner_id must be numeric."
  }
}

variable "github_repository_id" {
  description = "Immutable numeric GitHub repository ID."
  type        = string

  validation {
    condition     = can(regex("^[0-9]+$", var.github_repository_id))
    error_message = "github_repository_id must be numeric."
  }
}

variable "github_repository" {
  description = "GitHub repository in owner/name form, used to allowlist reviewed apply workflows."
  type        = string
  default     = "kevin-tran12/gke-iac-poc"

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must use owner/repository form."
  }
}

variable "bootstrap_profile" {
  description = "API allowlist profile. Core omits paid optional service APIs; full enables the complete four-hour lab."
  type        = string
  default     = "core"

  validation {
    condition     = contains(["core", "full"], var.bootstrap_profile)
    error_message = "bootstrap_profile must be core or full."
  }
}

variable "budget_amount_usd" {
  type    = number
  default = 75

  validation {
    condition     = var.budget_amount_usd > 0
    error_message = "budget_amount_usd must be greater than zero."
  }
}

variable "labels" {
  type = map(string)
  default = {
    environment = "ephemeral-lab"
    managed-by  = "terraform"
    portfolio   = "gke-iac-poc"
  }
}
