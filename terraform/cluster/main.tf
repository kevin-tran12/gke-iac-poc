locals {
  name     = "gke-lab"
  location = var.regional ? var.region : var.zone
}

resource "google_service_account" "nodes" {
  account_id   = "gke-lab-nodes"
  display_name = "GKE lab nodes"
}

resource "google_project_iam_member" "node_roles" {
  for_each = toset([
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.nodes.member
}

resource "google_container_cluster" "lab" {
  name     = local.name
  location = local.location

  network    = var.network_id
  subnetwork = var.subnet_id

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  networking_mode   = "VPC_NATIVE"
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
  }

  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = true
    }
    ip_endpoints_config {
      enabled = false
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  gateway_api_config {
    channel = "CHANNEL_STANDARD"
  }

  addons_config {
    gke_backup_agent_config {
      enabled = var.enable_backup_agent
    }
  }

  dns_config {
    cluster_dns       = "CLOUD_DNS"
    cluster_dns_scope = "CLUSTER_SCOPE"
  }

  release_channel {
    channel = "REGULAR"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  monitoring_config {
    enable_components = ["APISERVER", "CONTROLLER_MANAGER", "DAEMONSET", "DEPLOYMENT", "HPA", "POD", "SCHEDULER", "STATEFULSET", "STORAGE"]
    managed_prometheus {
      enabled = true
    }
  }

  binary_authorization {
    evaluation_mode = var.enable_binary_authorization ? "PROJECT_SINGLETON_POLICY_ENFORCE" : "DISABLED"
  }

  maintenance_policy {
    recurring_window {
      start_time = "2026-01-04T05:00:00Z"
      end_time   = "2026-01-04T09:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  resource_labels = {
    environment = "ephemeral-lab"
    expires-in  = var.environment_ttl
    managed-by  = "terraform"
  }

  depends_on = [google_project_iam_member.node_roles]
}

resource "google_container_node_pool" "system" {
  name     = "system"
  cluster  = google_container_cluster.lab.id
  location = local.location

  node_count = 1

  node_config {
    machine_type    = var.system_machine_type
    disk_type       = "pd-balanced"
    disk_size_gb    = 50
    image_type      = "COS_CONTAINERD"
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      pool = "system"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    strategy        = "SURGE"
    max_surge       = 1
    max_unavailable = 0
  }
}

resource "google_container_node_pool" "spot" {
  count    = var.enable_spot_pool ? 1 : 0
  name     = "spot-apps"
  cluster  = google_container_cluster.lab.id
  location = local.location

  autoscaling {
    total_min_node_count = 0
    total_max_node_count = 3
    location_policy      = "ANY"
  }

  node_config {
    machine_type    = "e2-standard-2"
    disk_type       = "pd-balanced"
    disk_size_gb    = 30
    image_type      = "COS_CONTAINERD"
    spot            = true
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    labels = {
      pool      = "applications"
      lifecycle = "spot"
    }

    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

resource "google_service_account_iam_member" "api_workload_identity" {
  for_each = toset(["staging", "production"])

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.api_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value}/gke-lab-api]"
}

resource "google_service_account_iam_member" "worker_workload_identity" {
  for_each = toset(["staging", "production"])

  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.worker_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value}/gke-lab-worker]"
}

resource "google_service_account_iam_member" "telemetry_workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.telemetry_service_account}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[observability/otel-collector]"
}
