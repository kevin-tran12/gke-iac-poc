variable "cluster_dns_endpoint" { type = string }
variable "cluster_ca_certificate" {
  type      = string
  sensitive = true
}
variable "telemetry_service_account" {
  type = string
}
variable "cert_manager_version" {
  type    = string
  default = "v1.21.0"
}
variable "cert_manager_images" {
  description = "Digest-pinned Artifact Registry mirrors for every cert-manager component."
  type        = map(string)

  validation {
    condition = length(var.cert_manager_images) == 5 && alltrue([
      for component in ["controller", "webhook", "cainjector", "acmesolver", "startupapicheck"] :
      contains(keys(var.cert_manager_images), component)
      ]) && alltrue([
      for image in values(var.cert_manager_images) :
      can(regex("@sha256:[0-9a-f]{64}$", image))
    ])
    error_message = "cert_manager_images must contain the five expected components at immutable sha256 digests."
  }
}
variable "otel_collector_image" {
  description = "Digest-pinned OpenTelemetry Collector image."
  type        = string
  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.otel_collector_image))
    error_message = "otel_collector_image must end in an immutable sha256 digest."
  }
}
