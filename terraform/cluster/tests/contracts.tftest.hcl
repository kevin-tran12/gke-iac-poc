mock_provider "google" {}

run "private_gke_contract" {
  command = plan

  variables {
    project_id                = "gke-lab-unit-test"
    project_number            = "123456789012"
    network_id                = "projects/gke-lab-unit-test/global/networks/gke-lab"
    subnet_id                 = "projects/gke-lab-unit-test/regions/us-central1/subnetworks/gke-lab"
    pods_range_name           = "pods"
    services_range_name       = "services"
    api_service_account       = "gke-lab-api@gke-lab-unit-test.iam.gserviceaccount.com"
    worker_service_account    = "gke-lab-worker@gke-lab-unit-test.iam.gserviceaccount.com"
    telemetry_service_account = "gke-lab-telemetry@gke-lab-unit-test.iam.gserviceaccount.com"
  }

  assert {
    condition     = google_container_cluster.lab.private_cluster_config[0].enable_private_nodes
    error_message = "GKE nodes must remain private."
  }

  assert {
    condition     = google_container_cluster.lab.datapath_provider == "ADVANCED_DATAPATH"
    error_message = "Dataplane V2 must remain enabled."
  }

  assert {
    condition     = google_container_cluster.lab.binary_authorization[0].evaluation_mode == "DISABLED"
    error_message = "Enforcement must stay disabled until the signed-delivery gate."
  }
}
