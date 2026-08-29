variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "cluster_id" {
  description = "Fully qualified GKE cluster resource ID with the Backup for GKE agent enabled."
  type        = string
}

variable "backup_retain_days" {
  type    = number
  default = 1

  validation {
    condition     = var.backup_retain_days >= 1 && var.backup_retain_days <= 7
    error_message = "Ephemeral lab backups must be retained for one to seven days."
  }
}
