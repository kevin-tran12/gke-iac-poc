terraform {
  required_version = ">= 1.15.9, < 1.17.0"
  backend "gcs" {}
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
