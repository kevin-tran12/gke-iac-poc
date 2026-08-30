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
    condition = (
      google_compute_network.lab.auto_create_subnetworks == false &&
      google_compute_network.lab.routing_mode == "REGIONAL"
    )
    error_message = "The VPC must remain custom-mode with regional dynamic routing."
  }

  assert {
    condition = (
      google_compute_subnetwork.gke.log_config[0].aggregation_interval == "INTERVAL_10_MIN" &&
      google_compute_subnetwork.gke.log_config[0].flow_sampling == 0.1 &&
      google_compute_subnetwork.gke.log_config[0].metadata == "EXCLUDE_ALL_METADATA"
    )
    error_message = "Flow Logs must retain the bounded, metadata-minimized configuration."
  }

  assert {
    condition = (
      google_compute_global_address.private_services.address == "10.40.0.0" &&
      google_compute_global_address.private_services.prefix_length == 16 &&
      google_compute_global_address.private_services.purpose == "VPC_PEERING"
    )
    error_message = "Layer 2 must reserve the explicit Private Service Access CIDR."
  }

  assert {
    condition = (
      local.primary_usable_addresses == 4092 &&
      local.pod_node_capacity == 512 &&
      local.service_usable_addresses == 4092
    )
    error_message = "Default node, Pod, and Service capacity calculations changed unexpectedly."
  }

  assert {
    condition     = length(google_compute_router_nat.lab) == 0
    error_message = "Cloud NAT must remain opt-in."
  }
}

run "nat_is_bounded_to_the_gke_subnet" {
  command = plan

  variables {
    project_id = "gke-lab-unit-test"
    enable_nat = true
  }

  assert {
    condition = (
      length(google_compute_router_nat.lab) == 1 &&
      google_compute_router_nat.lab[0].nat_ip_allocate_option == "AUTO_ONLY" &&
      google_compute_router_nat.lab[0].source_subnetwork_ip_ranges_to_nat == "LIST_OF_SUBNETWORKS" &&
      google_compute_router_nat.lab[0].log_config[0].filter == "ERRORS_ONLY"
    )
    error_message = "The paid NAT profile must use automatic IPs, error-only logs, and an explicit subnet list."
  }
}

run "overlapping_ranges_are_rejected" {
  command = plan

  variables {
    project_id            = "gke-lab-unit-test"
    private_services_cidr = "10.10.0.0/20"
  }

  expect_failures = [google_compute_subnetwork.gke]
}

run "public_ranges_are_rejected" {
  command = plan

  variables {
    project_id  = "gke-lab-unit-test"
    subnet_cidr = "100.64.0.0/20"
  }

  expect_failures = [google_compute_subnetwork.gke]
}

run "insufficient_pod_capacity_is_rejected" {
  command = plan

  variables {
    project_id            = "gke-lab-unit-test"
    pods_cidr             = "10.20.0.0/25"
    maximum_cluster_nodes = 6
  }

  expect_failures = [google_compute_subnetwork.gke]
}
