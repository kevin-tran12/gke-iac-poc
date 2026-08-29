variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "us-central1"
}
variable "network_name" {
  type    = string
  default = "gke-lab"
}
variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/20"
}
variable "pods_cidr" {
  type    = string
  default = "10.20.0.0/16"
}
variable "services_cidr" {
  type    = string
  default = "10.30.0.0/20"
}
variable "enable_nat" {
  description = "Billable public egress lab; disabled in the core profile."
  type        = bool
  default     = false
}
