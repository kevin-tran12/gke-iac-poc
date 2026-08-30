mock_provider "google" {}

run "private_gke_contract" {
  command = plan

  variables {
    project_id                = "gke-lab-unit-test"
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
    condition = (
      google_container_cluster.lab.control_plane_endpoints_config[0].ip_endpoints_config[0].enabled == false &&
      google_container_cluster.lab.control_plane_endpoints_config[0].dns_endpoint_config[0].allow_external_traffic
    )
    error_message = "The control plane must use the IAM-protected DNS endpoint with IP endpoints disabled."
  }

  assert {
    condition = (
      google_container_cluster.lab.networking_mode == "VPC_NATIVE" &&
      google_container_cluster.lab.workload_identity_config[0].workload_pool == "gke-lab-unit-test.svc.id.goog" &&
      google_container_cluster.lab.dns_config[0].cluster_dns == "CLOUD_DNS" &&
      google_container_cluster.lab.gateway_api_config[0].channel == "CHANNEL_STANDARD"
    )
    error_message = "VPC-native networking, Workload Identity, Cloud DNS, and the standard Gateway API channel must remain enabled."
  }

  assert {
    condition = (
      google_container_node_pool.system.node_config[0].shielded_instance_config[0].enable_secure_boot &&
      google_container_node_pool.system.management[0].auto_repair &&
      google_container_node_pool.system.management[0].auto_upgrade
    )
    error_message = "System nodes must disable the insecure kubelet port and retain Shielded VM and managed-lifecycle controls."
  }

  assert {
    condition = (
      google_container_node_pool.spot[0].autoscaling[0].total_min_node_count == 0 &&
      google_container_node_pool.spot[0].autoscaling[0].total_max_node_count == 3 &&
      google_container_node_pool.spot[0].node_config[0].spot
    )
    error_message = "The application pool must remain Spot and scale from zero to three nodes."
  }

  assert {
    condition     = google_container_cluster.lab.binary_authorization[0].evaluation_mode == "DISABLED"
    error_message = "Enforcement must stay disabled until the signed-delivery gate."
  }
}
