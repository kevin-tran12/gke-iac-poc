mock_provider "google" {}
mock_provider "helm" {}
mock_provider "kubernetes" {}

run "cluster_addons_contract" {
  command = plan

  variables {
    cluster_dns_endpoint      = "example.gke.goog"
    cluster_ca_certificate    = "Y2E="
    telemetry_service_account = "gke-lab-telemetry@gke-lab-unit-test.iam.gserviceaccount.com"
    otel_collector_image      = "example.invalid/otel@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    cert_manager_images = {
      controller      = "example.invalid/controller@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      webhook         = "example.invalid/webhook@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      cainjector      = "example.invalid/cainjector@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      acmesolver      = "example.invalid/acmesolver@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      startupapicheck = "example.invalid/startupapicheck@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    }
  }

  assert {
    condition     = helm_release.cert_manager.atomic
    error_message = "cert-manager installation must be atomic."
  }

  assert {
    condition     = kubernetes_deployment_v1.otel_collector.spec[0].template[0].spec[0].security_context[0].run_as_non_root
    error_message = "The collector must run as a non-root workload."
  }
}
