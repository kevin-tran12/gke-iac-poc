terraform {
  required_version = ">= 1.15.9, < 1.17.0"
  backend "gcs" {}
  required_providers {
    google     = { source = "hashicorp/google", version = "~> 7.45" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 3.2" }
  }
}
data "google_client_config" "current" {}
provider "google" {
  project = var.project_id
  region  = var.region
}
provider "kubernetes" {
  host                   = "https://${var.cluster_dns_endpoint}"
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
}
