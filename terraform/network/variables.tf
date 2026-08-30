variable "project_id" {
  description = "Google Cloud project that owns the lab network."
  type        = string

  validation {
    condition     = trimspace(var.project_id) != ""
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "Region for the GKE subnet and Cloud NAT."
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "Name of the custom-mode VPC."
  type        = string
  default     = "gke-lab"

  validation {
    condition     = can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.network_name))
    error_message = "network_name must be a valid Compute Engine resource name."
  }
}

variable "subnet_cidr" {
  description = "Primary node address range. The lab intentionally uses RFC1918 space."
  type        = string
  default     = "10.10.0.0/20"

  validation {
    condition = (
      can(cidrnetmask(var.subnet_cidr)) &&
      try(cidrhost(var.subnet_cidr, 0), "") == try(split("/", var.subnet_cidr)[0], "") &&
      can(regex("/(1[6-9]|2[0-8])$", var.subnet_cidr))
    )
    error_message = "subnet_cidr must be a canonical IPv4 CIDR with a /16 through /28 prefix."
  }
}

variable "pods_cidr" {
  description = "Secondary GKE Pod address range."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition = (
      can(cidrnetmask(var.pods_cidr)) &&
      try(cidrhost(var.pods_cidr, 0), "") == try(split("/", var.pods_cidr)[0], "") &&
      can(regex("/([89]|1[0-9]|2[0-5])$", var.pods_cidr))
    )
    error_message = "pods_cidr must be a canonical IPv4 CIDR with a /8 through /25 prefix."
  }
}

variable "services_cidr" {
  description = "Secondary GKE Service address range."
  type        = string
  default     = "10.30.0.0/20"

  validation {
    condition = (
      can(cidrnetmask(var.services_cidr)) &&
      try(cidrhost(var.services_cidr, 0), "") == try(split("/", var.services_cidr)[0], "") &&
      can(regex("/(1[6-9]|2[0-4])$", var.services_cidr))
    )
    error_message = "services_cidr must be a canonical IPv4 CIDR with a /16 through /24 prefix."
  }
}

variable "private_services_cidr" {
  description = "Private Service Access range reserved by Layer 2 and consumed by Layer 3 Cloud SQL."
  type        = string
  default     = "10.40.0.0/16"

  validation {
    condition = (
      can(cidrnetmask(var.private_services_cidr)) &&
      try(cidrhost(var.private_services_cidr, 0), "") == try(split("/", var.private_services_cidr)[0], "") &&
      can(regex("/(1[6-9]|2[0-4])$", var.private_services_cidr))
    )
    error_message = "private_services_cidr must be a canonical IPv4 CIDR with a /16 through /24 prefix."
  }
}

variable "maximum_cluster_nodes" {
  description = "Upper bound used to prove the primary and Pod ranges can support the planned regional cluster."
  type        = number
  default     = 6

  validation {
    condition     = var.maximum_cluster_nodes >= 3 && var.maximum_cluster_nodes <= 64 && floor(var.maximum_cluster_nodes) == var.maximum_cluster_nodes
    error_message = "maximum_cluster_nodes must be a whole number from 3 through 64."
  }
}

variable "maximum_pods_per_node" {
  description = "GKE Pod-density assumption used for secondary-range capacity calculations."
  type        = number
  default     = 64

  validation {
    condition     = var.maximum_pods_per_node >= 8 && var.maximum_pods_per_node <= 256 && floor(var.maximum_pods_per_node) == var.maximum_pods_per_node
    error_message = "maximum_pods_per_node must be a whole number from 8 through 256."
  }
}

variable "minimum_service_addresses" {
  description = "Minimum usable ClusterIP addresses required by the lab contract."
  type        = number
  default     = 256

  validation {
    condition     = var.minimum_service_addresses >= 1 && floor(var.minimum_service_addresses) == var.minimum_service_addresses
    error_message = "minimum_service_addresses must be a positive whole number."
  }
}

variable "enable_nat" {
  description = "Billable public egress lab; disabled in the core profile."
  type        = bool
  default     = false
}
