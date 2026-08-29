mock_provider "google" {}

run "signed_delivery_contract" {
  command = plan

  variables {
    project_id                   = "gke-lab-unit-test"
    cluster_id                   = "projects/gke-lab-unit-test/locations/us-central1-a/clusters/gke-lab"
    cloud_build_service_account  = "gke-lab-cloud-build@gke-lab-unit-test.iam.gserviceaccount.com"
    cloud_deploy_service_account = "gke-lab-cloud-deploy@gke-lab-unit-test.iam.gserviceaccount.com"
    artifact_bucket              = "gke-lab-unit-test-job-results"
  }

  assert {
    condition     = google_clouddeploy_target.production.require_approval
    error_message = "Production promotion must require approval."
  }

  assert {
    condition     = google_binary_authorization_policy.lab.default_admission_rule[0].evaluation_mode == "REQUIRE_ATTESTATION"
    error_message = "Binary Authorization must require the Cloud Build attestor."
  }
}
