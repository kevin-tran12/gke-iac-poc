variable "project_id" { type = string }
variable "project_number" { type = string }
variable "region" {
  type    = string
  default = "us-central1"
}
variable "network_id" { type = string }
variable "private_services_range_name" {
  description = "Private Service Access range created and overlap-checked by Layer 2."
  type        = string
  default     = ""

  validation {
    condition     = !var.enable_cloud_sql || trimspace(var.private_services_range_name) != ""
    error_message = "private_services_range_name is required when enable_cloud_sql is true."
  }
}
variable "enable_cloud_sql" {
  type    = bool
  default = false
}
variable "notification_email" {
  type    = string
  default = ""
}
