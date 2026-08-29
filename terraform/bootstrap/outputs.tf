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

output "terraform_plan_service_account" {
  value = google_service_account.terraform_plan.email
}

output "terraform_apply_service_account" {
  value = google_service_account.terraform_apply.email
}
