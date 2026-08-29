locals {
  prefix = "gke-lab"
}

resource "google_kms_key_ring" "attestation" {
  name     = "${local.prefix}-attestation"
  location = var.region
}

resource "google_kms_crypto_key" "attestation" {
  name     = "cloud-build-attestation"
  key_ring = google_kms_key_ring.attestation.id
  purpose  = "ASYMMETRIC_SIGN"

  version_template {
    algorithm        = "RSA_SIGN_PSS_2048_SHA256"
    protection_level = "SOFTWARE"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key_version" "attestation" {
  crypto_key = google_kms_crypto_key.attestation.id
}

data "google_kms_crypto_key_version" "attestation" {
  crypto_key = google_kms_crypto_key.attestation.id
  version    = regex("[^/]+$", google_kms_crypto_key_version.attestation.name)
}

resource "google_kms_crypto_key_iam_member" "cloud_build_signer" {
  crypto_key_id = google_kms_crypto_key.attestation.id
  role          = "roles/cloudkms.signerVerifier"
  member        = "serviceAccount:${var.cloud_build_service_account}"
}

resource "google_container_analysis_note" "cloud_build" {
  name = "${local.prefix}-cloud-build-attestor"

  attestation_authority {
    hint {
      human_readable_name = "Cloud Build verified release for the GKE lab"
    }
  }
}

resource "google_binary_authorization_attestor" "cloud_build" {
  name = "${local.prefix}-cloud-build"

  attestation_authority_note {
    note_reference = google_container_analysis_note.cloud_build.name

    public_keys {
      id = data.google_kms_crypto_key_version.attestation.name

      pkix_public_key {
        public_key_pem      = data.google_kms_crypto_key_version.attestation.public_key[0].pem
        signature_algorithm = "RSA_PSS_2048_SHA256"
      }
    }
  }
}

resource "google_binary_authorization_policy" "lab" {
  global_policy_evaluation_mode = "ENABLE"

  default_admission_rule {
    evaluation_mode         = "REQUIRE_ATTESTATION"
    enforcement_mode        = "ENFORCED_BLOCK_AND_AUDIT_LOG"
    require_attestations_by = [google_binary_authorization_attestor.cloud_build.name]
  }
}

resource "google_clouddeploy_target" "staging" {
  name             = "${local.prefix}-staging"
  location         = var.region
  require_approval = false

  gke {
    cluster      = var.cluster_id
    dns_endpoint = true
  }

  execution_configs {
    usages           = ["RENDER", "DEPLOY", "VERIFY"]
    service_account  = var.cloud_deploy_service_account
    artifact_storage = "gs://${var.artifact_bucket}/cloud-deploy"
  }

  labels = {
    environment = "staging"
    managed-by  = "terraform"
  }
}

resource "google_clouddeploy_target" "production" {
  name             = "${local.prefix}-production"
  location         = var.region
  require_approval = true

  gke {
    cluster      = var.cluster_id
    dns_endpoint = true
  }


  execution_configs {
    usages           = ["RENDER", "DEPLOY", "VERIFY"]
    service_account  = var.cloud_deploy_service_account
    artifact_storage = "gs://${var.artifact_bucket}/cloud-deploy"
  }

  labels = {
    environment = "production"
    managed-by  = "terraform"
  }
}

resource "google_clouddeploy_delivery_pipeline" "lab" {
  name     = local.prefix
  location = var.region

  serial_pipeline {
    stages {
      target_id = google_clouddeploy_target.staging.name
      profiles  = []
    }

    stages {
      target_id = google_clouddeploy_target.production.name
      profiles  = ["production"]
    }
  }

  labels = {
    environment = "ephemeral-lab"
    managed-by  = "terraform"
  }
}
