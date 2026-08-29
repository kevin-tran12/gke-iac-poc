output "ip_address" { value = google_compute_global_address.gateway.address }
output "hostname" { value = local.hostname }
output "https_url" { value = "https://${local.hostname}" }
output "cloud_armor_policy" { value = google_compute_security_policy.lab.name }
output "uptime_check_id" { value = google_monitoring_uptime_check_config.https.uptime_check_id }
