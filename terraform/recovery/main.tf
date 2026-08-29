resource "google_gke_backup_backup_plan" "lab" {
  name        = "gke-lab-test"
  location    = var.region
  cluster     = var.cluster_id
  deactivated = false
  description = "Manually triggered, short-retention backup plan for the recovery lab"

  retention_policy {
    backup_retain_days = var.backup_retain_days
  }

  backup_config {
    include_volume_data = true
    include_secrets     = false

    selected_namespaces {
      namespaces = ["recovery"]
    }
  }

  labels = {
    environment = "ephemeral-lab"
    managed-by  = "terraform"
  }
}

resource "google_gke_backup_restore_plan" "lab" {
  name        = "gke-lab-test"
  location    = var.region
  backup_plan = google_gke_backup_backup_plan.lab.id
  cluster     = var.cluster_id
  description = "Restore the test namespace and its volume from a selected lab backup"

  restore_config {
    volume_data_restore_policy       = "RESTORE_VOLUME_DATA_FROM_BACKUP"
    namespaced_resource_restore_mode = "DELETE_AND_RESTORE"
    cluster_resource_conflict_policy = "USE_EXISTING_VERSION"

    selected_namespaces {
      namespaces = ["recovery"]
    }
  }

  labels = {
    environment = "ephemeral-lab"
    managed-by  = "terraform"
  }
}
