output "project_id" {
  value = google_project.lab.project_id
}

output "project_number" {
  value = google_project.lab.number
}

output "region" {
  value = var.region
}

output "state_bucket" {
  value = google_storage_bucket.terraform_state.name
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "terraform_phase_service_accounts" {
  value = {
    for phase, service_account in google_service_account.terraform_phase : phase => service_account.email
  }
}

output "terraform_foundation_service_account" {
  value = google_service_account.terraform_phase["foundation"].email
}

output "terraform_cluster_service_account" {
  value = google_service_account.terraform_phase["cluster"].email
}

output "terraform_delivery_service_account" {
  value = google_service_account.terraform_phase["delivery"].email
}

output "terraform_recovery_service_account" {
  value = google_service_account.terraform_phase["recovery"].email
}

output "enabled_service_catalog" {
  value = local.enabled_services
}

output "budget_resource_name" {
  description = "Fully qualified Billing Budget resource name accepted by gcloud."
  value       = google_billing_budget.lab.id
}
