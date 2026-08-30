locals {
  cidr_ranges = {
    nodes = {
      cidr   = var.subnet_cidr
      prefix = tonumber(split("/", var.subnet_cidr)[1])
    }
    pods = {
      cidr   = var.pods_cidr
      prefix = tonumber(split("/", var.pods_cidr)[1])
    }
    private_services = {
      cidr   = var.private_services_cidr
      prefix = tonumber(split("/", var.private_services_cidr)[1])
    }
    services = {
      cidr   = var.services_cidr
      prefix = tonumber(split("/", var.services_cidr)[1])
    }
  }

  cidr_range_names = sort(keys(local.cidr_ranges))
  cidr_pairs = flatten([
    for left_index, left_name in local.cidr_range_names : [
      for right_index, right_name in local.cidr_range_names : {
        left_name  = left_name
        left       = local.cidr_ranges[left_name]
        right_name = right_name
        right      = local.cidr_ranges[right_name]
      } if left_index < right_index
    ]
  ])
  overlapping_cidr_pairs = [
    for pair in local.cidr_pairs : "${pair.left_name}/${pair.right_name}"
    if cidrhost(
      format("%s/%d", cidrhost(pair.left.cidr, 0), min(pair.left.prefix, pair.right.prefix)),
      0
      ) == cidrhost(
      format("%s/%d", cidrhost(pair.right.cidr, 0), min(pair.left.prefix, pair.right.prefix)),
      0
    )
  ]

  rfc1918_ranges = {
    ten       = { cidr = "10.0.0.0/8", prefix = 8 }
    one_seven = { cidr = "172.16.0.0/12", prefix = 12 }
    one_nine  = { cidr = "192.168.0.0/16", prefix = 16 }
  }
  non_private_cidr_ranges = [
    for name, network_range in local.cidr_ranges : name
    if !anytrue([
      for private_range in values(local.rfc1918_ranges) :
      network_range.prefix >= private_range.prefix &&
      cidrhost(format("%s/%d", cidrhost(network_range.cidr, 0), private_range.prefix), 0) == cidrhost(private_range.cidr, 0)
    ])
  ]

  pod_allocation_prefix        = 31 - ceil(log(var.maximum_pods_per_node, 2))
  pod_node_capacity            = pow(2, local.pod_allocation_prefix - local.cidr_ranges.pods.prefix)
  primary_usable_addresses     = pow(2, 32 - local.cidr_ranges.nodes.prefix) - 4
  service_usable_addresses     = pow(2, 32 - local.cidr_ranges.services.prefix) - 4
  private_service_prefix       = local.cidr_ranges.private_services.prefix
  private_service_base_address = cidrhost(var.private_services_cidr, 0)
}

resource "google_compute_network" "lab" {
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "gke" {
  name                     = "${var.network_name}-gke"
  region                   = var.region
  network                  = google_compute_network.lab.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.1
    metadata             = "EXCLUDE_ALL_METADATA"
    filter_expr          = "true"
  }

  lifecycle {
    precondition {
      condition     = length(local.overlapping_cidr_pairs) == 0
      error_message = "Node, Pod, Service, and Private Service Access CIDRs overlap: ${join(", ", local.overlapping_cidr_pairs)}."
    }

    precondition {
      condition     = length(local.non_private_cidr_ranges) == 0
      error_message = "All Layer 2 address ranges must use RFC1918 space; invalid ranges: ${join(", ", local.non_private_cidr_ranges)}."
    }

    precondition {
      condition     = local.primary_usable_addresses >= var.maximum_cluster_nodes
      error_message = "The primary subnet cannot support maximum_cluster_nodes after Google Cloud reserved addresses."
    }

    precondition {
      condition     = local.pod_node_capacity >= var.maximum_cluster_nodes
      error_message = "The Pod secondary range cannot support maximum_cluster_nodes at maximum_pods_per_node."
    }

    precondition {
      condition     = local.service_usable_addresses >= var.minimum_service_addresses
      error_message = "The Service secondary range is smaller than minimum_service_addresses."
    }
  }
}

resource "google_compute_global_address" "private_services" {
  name          = "${var.network_name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = local.private_service_base_address
  prefix_length = local.private_service_prefix
  network       = google_compute_network.lab.id
}

resource "google_compute_router" "lab" {
  count   = var.enable_nat ? 1 : 0
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.lab.id
}

resource "google_compute_router_nat" "lab" {
  count                              = var.enable_nat ? 1 : 0
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.lab[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
