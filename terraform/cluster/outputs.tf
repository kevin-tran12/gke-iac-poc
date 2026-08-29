output "cluster_name" { value = google_container_cluster.lab.name }
output "cluster_location" { value = google_container_cluster.lab.location }
output "cluster_id" { value = google_container_cluster.lab.id }
output "cluster_ca_certificate" {
  value     = try(google_container_cluster.lab.master_auth[0].cluster_ca_certificate, null)
  sensitive = true
}
output "cluster_dns_endpoint" {
  value = try(google_container_cluster.lab.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint, null)
}
output "workload_pool" {
  value = try(google_container_cluster.lab.workload_identity_config[0].workload_pool, null)
}
output "backup_agent_enabled" { value = var.enable_backup_agent }
output "binary_authorization_enabled" { value = var.enable_binary_authorization }
output "regional" { value = var.regional }
