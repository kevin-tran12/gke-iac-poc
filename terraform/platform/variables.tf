variable "project_id" { type = string }
variable "project_number" { type = string }
variable "region" {
  type    = string
  default = "us-central1"
}
variable "network_id" { type = string }
variable "enable_cloud_sql" {
  type    = bool
  default = false
}
variable "notification_email" {
  type    = string
  default = ""
}
