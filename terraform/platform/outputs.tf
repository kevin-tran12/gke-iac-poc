output "artifact_repository" { value = google_artifact_registry_repository.containers.repository_id }
output "artifact_registry_host" { value = "${var.region}-docker.pkg.dev" }
output "results_bucket" { value = google_storage_bucket.results.name }
output "jobs_topic" { value = google_pubsub_topic.jobs.name }
output "jobs_subscription" { value = google_pubsub_subscription.jobs.name }
output "dead_letter_topic" { value = google_pubsub_topic.dead_letter.name }
output "api_service_account" { value = google_service_account.api.email }
output "worker_service_account" { value = google_service_account.worker.email }
output "cloud_build_service_account" { value = google_service_account.cloud_build.email }
output "telemetry_service_account" { value = google_service_account.telemetry.email }
output "cloud_deploy_service_account" { value = google_service_account.cloud_deploy.email }
output "private_dns_zone" { value = google_dns_managed_zone.private.name }
output "lab_token_secret" { value = google_secret_manager_secret.lab_token.id }
output "worker_salt_secret" { value = google_secret_manager_secret.worker_salt.id }
output "cloud_sql_connection_name" {
  value = var.enable_cloud_sql ? google_sql_database_instance.postgres[0].connection_name : null
}
output "cloud_sql_private_ip" {
  value = var.enable_cloud_sql ? google_sql_database_instance.postgres[0].private_ip_address : null
}
output "cloud_sql_database" {
  value = var.enable_cloud_sql ? google_sql_database.lab[0].name : null
}
output "cloud_sql_user" {
  value = var.enable_cloud_sql ? google_sql_user.worker[0].name : null
}
