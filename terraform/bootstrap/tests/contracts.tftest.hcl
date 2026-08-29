mock_provider "google" {}

run "disposable_project_contract" {
  command = plan

  variables {
    project_id           = "gke-lab-unit-test"
    billing_account      = "000000-000000-000000"
    github_owner_id      = "123456"
    github_repository_id = "789012"
  }

  assert {
    condition     = google_project.lab.auto_create_network == false
    error_message = "The disposable project must not receive a default network."
  }

  assert {
    condition     = google_storage_bucket.terraform_state.uniform_bucket_level_access
    error_message = "Terraform state must use uniform bucket-level access."
  }
}
