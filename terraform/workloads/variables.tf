variable "project_id" {
  type = string
}

variable "cluster_dns_endpoint" {
  type = string
}

variable "cluster_ca_certificate" {
  type      = string
  sensitive = true
}

variable "api_service_account" {
  type = string
}

variable "worker_service_account" {
  type = string
}

variable "echo_image" {
  description = "Digest-pinned mendhak/http-https-echo image mirrored into Artifact Registry."
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.echo_image))
    error_message = "echo_image must end in an immutable sha256 digest."
  }
}

variable "hello_image" {
  description = "Digest-pinned Google hello-app image mirrored into Artifact Registry."
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.hello_image))
    error_message = "hello_image must end in an immutable sha256 digest."
  }
}

variable "hpa_image" {
  description = "Digest-pinned HPA example image mirrored into Artifact Registry."
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.hpa_image))
    error_message = "hpa_image must end in an immutable sha256 digest."
  }
}

variable "recovery_image" {
  description = "Digest-pinned utility image used by the Persistent Disk recovery exercise."
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.recovery_image))
    error_message = "recovery_image must end in an immutable sha256 digest."
  }
}

variable "environment_ttl" {
  type    = string
  default = "8h"
}
