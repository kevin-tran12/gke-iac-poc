terraform {
  required_version = ">= 1.15.9, < 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

provider "google" {
  region = var.region
}

# Billing Budget API calls made with user ADC require an explicit quota
# project. Keep this provider isolated so the default provider can create the
# project before the project is used for quota and billing API requests.
provider "google" {
  alias                 = "billing"
  region                = var.region
  billing_project       = var.project_id
  user_project_override = true
}
