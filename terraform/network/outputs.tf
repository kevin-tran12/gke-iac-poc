output "network_id" { value = google_compute_network.lab.id }
output "network_name" { value = google_compute_network.lab.name }
output "subnet_id" { value = google_compute_subnetwork.gke.id }
output "subnet_name" { value = google_compute_subnetwork.gke.name }
output "pods_range_name" { value = "pods" }
output "services_range_name" { value = "services" }
output "nat_enabled" { value = var.enable_nat }
