mock_provider "google" {}

run "short_lived_backup_contract" {
  command = plan

  variables {
    project_id = "gke-lab-unit-test"
    cluster_id = "projects/gke-lab-unit-test/locations/us-central1/clusters/gke-lab"
  }

  assert {
    condition     = google_gke_backup_backup_plan.lab.deactivated == false
    error_message = "The unscheduled plan must accept an explicitly triggered lab backup."
  }

  assert {
    condition     = google_gke_backup_backup_plan.lab.retention_policy[0].backup_retain_days == 1
    error_message = "The default backup retention must remain one day."
  }
}
