mock_provider "google" {}

run "private_network_contract" {
  command = plan

  variables {
    project_id = "gke-lab-unit-test"
  }

  assert {
    condition     = google_compute_subnetwork.gke.private_ip_google_access
    error_message = "Private Google Access must remain enabled."
  }

  assert {
    condition     = length(google_compute_router_nat.lab) == 0
    error_message = "Cloud NAT must remain opt-in."
  }
}
