output "pipeline_name" { value = google_clouddeploy_delivery_pipeline.lab.name }
output "staging_target" { value = google_clouddeploy_target.staging.name }
output "production_target" { value = google_clouddeploy_target.production.name }
output "attestor_name" { value = google_binary_authorization_attestor.cloud_build.name }
output "attestation_key_version" { value = google_kms_crypto_key_version.attestation.name }
