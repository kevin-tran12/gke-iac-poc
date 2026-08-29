mock_provider "google" {}
mock_provider "google-beta" {}

run "managed_services_contract" {
  command = plan

  variables {
    project_id     = "gke-lab-unit-test"
    project_number = "123456789012"
    network_id     = "projects/gke-lab-unit-test/global/networks/gke-lab"
  }

  assert {
    condition     = google_storage_bucket.results.public_access_prevention == "enforced"
    error_message = "The result bucket must prevent public access."
  }

  assert {
    condition     = google_pubsub_subscription.jobs.dead_letter_policy[0].max_delivery_attempts == 5
    error_message = "The worker subscription must have bounded dead-letter delivery."
  }

  assert {
    condition     = length(google_sql_database_instance.postgres) == 0
    error_message = "Cloud SQL must remain opt-in."
  }

  assert {
    condition     = google_project_service_identity.cloud_deploy.service == "clouddeploy.googleapis.com"
    error_message = "Cloud Deploy IAM must depend on an explicitly provisioned Google-managed service identity."
  }
}
