locals {
  prefix = "gke-lab"
}

resource "google_artifact_registry_repository" "containers" {
  location      = var.region
  repository_id = "${local.prefix}-containers"
  description   = "Digest-pinned lab application and mirrored test images"
  format        = "DOCKER"

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "delete-old-versions"
    action = "DELETE"
    condition {
      older_than = "604800s"
    }
  }

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5
    }
  }
}

resource "google_storage_bucket" "results" {
  name                        = "${var.project_id}-job-results"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  lifecycle_rule {
    condition { age = 7 }
    action { type = "Delete" }
  }
}

resource "google_pubsub_topic" "jobs" {
  name                       = "${local.prefix}-jobs"
  message_retention_duration = "86400s"
}

resource "google_pubsub_topic" "dead_letter" {
  name                       = "${local.prefix}-jobs-dlq"
  message_retention_duration = "604800s"
}

resource "google_pubsub_subscription" "jobs" {
  name                       = "${local.prefix}-jobs-worker"
  topic                      = google_pubsub_topic.jobs.id
  ack_deadline_seconds       = 30
  message_retention_duration = "86400s"

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "60s"
  }
}

resource "google_secret_manager_secret" "lab_token" {
  secret_id = "${local.prefix}-api-token"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret" "worker_salt" {
  secret_id = "${local.prefix}-worker-salt"
  replication {
    auto {}
  }
}

resource "google_service_account" "api" {
  account_id   = "gke-lab-api"
  display_name = "GKE lab API workload"
}

resource "google_service_account" "worker" {
  account_id   = "gke-lab-worker"
  display_name = "GKE lab worker workload"
}

resource "google_service_account" "cloud_build" {
  account_id   = "gke-lab-cloud-build"
  display_name = "GKE lab Cloud Build"
}

resource "google_service_account" "telemetry" {
  account_id   = "gke-lab-telemetry"
  display_name = "GKE lab OpenTelemetry collector"
}

resource "google_service_account" "cloud_deploy" {
  account_id   = "gke-lab-cloud-deploy"
  display_name = "GKE lab Cloud Deploy execution"
}

resource "google_project_iam_member" "api_roles" {
  for_each = toset([
    "roles/logging.logWriter",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.api.member
}

resource "google_project_iam_member" "worker_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.worker.member
}

resource "google_pubsub_topic_iam_member" "api_publisher" {
  topic  = google_pubsub_topic.jobs.name
  role   = "roles/pubsub.publisher"
  member = google_service_account.api.member
}

resource "google_pubsub_subscription_iam_member" "worker_subscriber" {
  subscription = google_pubsub_subscription.jobs.name
  role         = "roles/pubsub.subscriber"
  member       = google_service_account.worker.member
}

resource "google_pubsub_topic_iam_member" "dead_letter_service_agent" {
  topic  = google_pubsub_topic.dead_letter.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription_iam_member" "forwarding_service_agent" {
  subscription = google_pubsub_subscription.jobs.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "api_results" {
  bucket = google_storage_bucket.results.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.api.member
}

resource "google_storage_bucket_iam_member" "api_bucket_metadata" {
  bucket = google_storage_bucket.results.name
  role   = "roles/storage.legacyBucketReader"
  member = google_service_account.api.member
}

resource "google_storage_bucket_iam_member" "worker_results" {
  bucket = google_storage_bucket.results.name
  role   = "roles/storage.objectCreator"
  member = google_service_account.worker.member
}

resource "google_secret_manager_secret_iam_member" "api_token" {
  secret_id = google_secret_manager_secret.lab_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.api.member
}

resource "google_secret_manager_secret_iam_member" "worker_salt" {
  secret_id = google_secret_manager_secret.worker_salt.id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_service_account.worker.member
}

resource "google_project_iam_member" "cloud_build_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/logging.logWriter",
    "roles/storage.objectViewer",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.cloud_build.member
}

resource "google_storage_bucket_iam_member" "cloud_build_evidence" {
  bucket = google_storage_bucket.results.name
  role   = "roles/storage.objectCreator"
  member = google_service_account.cloud_build.member
}

resource "google_project_iam_member" "telemetry_roles" {
  for_each = toset([
    "roles/cloudtrace.agent",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.telemetry.member
}

resource "google_project_iam_member" "cloud_deploy_roles" {
  for_each = toset([
    "roles/artifactregistry.reader",
    "roles/clouddeploy.jobRunner",
    "roles/container.developer",
    "roles/logging.logWriter",
  ])
  project = var.project_id
  role    = each.value
  member  = google_service_account.cloud_deploy.member
}

resource "google_service_account_iam_member" "cloud_deploy_service_agent" {
  service_account_id = google_service_account.cloud_deploy.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${var.project_number}@gcp-sa-clouddeploy.iam.gserviceaccount.com"
}

resource "google_storage_bucket_iam_member" "cloud_deploy_artifacts" {
  bucket = google_storage_bucket.results.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.cloud_deploy.member
}

resource "google_dns_managed_zone" "private" {
  name        = "gke-lab-private"
  dns_name    = "lab.internal."
  description = "Private DNS service-discovery exercise for the ephemeral GKE lab"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = var.network_id
    }
  }

  labels = {
    environment = "ephemeral-lab"
    managed-by  = "terraform"
  }
}

resource "google_compute_global_address" "private_services" {
  count         = var.enable_cloud_sql ? 1 : 0
  name          = "${local.prefix}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.network_id
}

resource "google_service_networking_connection" "private_services" {
  count                   = var.enable_cloud_sql ? 1 : 0
  network                 = var.network_id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services[0].name]
}

resource "google_sql_database_instance" "postgres" {
  count            = var.enable_cloud_sql ? 1 : 0
  name             = "${local.prefix}-postgres"
  region           = var.region
  database_version = "POSTGRES_18"

  settings {
    tier              = "db-f1-micro"
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = 10
    disk_autoresize   = false

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = var.network_id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "04:00"
      transaction_log_retention_days = 2
      backup_retention_settings {
        retained_backups = 2
        retention_unit   = "COUNT"
      }
    }

    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }

  deletion_protection = false
  depends_on          = [google_service_networking_connection.private_services]
}

resource "google_sql_database" "lab" {
  count    = var.enable_cloud_sql ? 1 : 0
  name     = "gke_lab"
  instance = google_sql_database_instance.postgres[0].name
}

resource "google_sql_user" "worker" {
  count    = var.enable_cloud_sql ? 1 : 0
  name     = trimsuffix(google_service_account.worker.email, ".gserviceaccount.com")
  instance = google_sql_database_instance.postgres[0].name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_project_iam_member" "worker_cloud_sql_roles" {
  for_each = var.enable_cloud_sql ? toset([
    "roles/cloudsql.client",
    "roles/cloudsql.instanceUser",
  ]) : toset([])

  project = var.project_id
  role    = each.value
  member  = google_service_account.worker.member
}

resource "google_monitoring_notification_channel" "email" {
  count        = var.notification_email == "" ? 0 : 1
  display_name = "GKE lab operator"
  type         = "email"
  labels = {
    email_address = var.notification_email
  }
}
