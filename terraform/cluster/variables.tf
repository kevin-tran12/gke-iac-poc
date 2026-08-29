variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "us-central1"
}
variable "zone" {
  type    = string
  default = "us-central1-a"
}
variable "regional" {
  type    = bool
  default = false
}
variable "network_id" { type = string }
variable "subnet_id" { type = string }
variable "pods_range_name" { type = string }
variable "services_range_name" { type = string }
variable "api_service_account" { type = string }
variable "worker_service_account" { type = string }
variable "telemetry_service_account" { type = string }
variable "system_machine_type" {
  type    = string
  default = "e2-standard-2"
}
variable "enable_spot_pool" {
  type    = bool
  default = true
}
variable "enable_binary_authorization" {
  description = "Enabled only after a signed application image passes the delivery gate."
  type        = bool
  default     = false
}
variable "enable_backup_agent" {
  description = "Enabled only for the recovery profile before creating a Backup for GKE plan."
  type        = bool
  default     = false
}
variable "environment_ttl" {
  type    = string
  default = "8h"
}
