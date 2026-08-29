variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "cluster_id" {
  description = "Fully qualified GKE cluster resource ID."
  type        = string
}

variable "cloud_build_service_account" {
  description = "Cloud Build service account email created by the platform layer."
  type        = string
}

variable "cloud_deploy_service_account" {
  description = "Cloud Deploy execution service account email created by the platform layer."
  type        = string
}

variable "artifact_bucket" {
  description = "GCS bucket used for short-lived Cloud Deploy render and verification artifacts."
  type        = string
}
