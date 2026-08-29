mock_provider "google" {}
mock_provider "kubernetes" {}

run "workload_guardrails_contract" {
  command = plan

  variables {
    project_id             = "gke-lab-unit-test"
    cluster_dns_endpoint   = "example.gke.goog"
    cluster_ca_certificate = "Y2E="
    api_service_account    = "gke-lab-api@gke-lab-unit-test.iam.gserviceaccount.com"
    worker_service_account = "gke-lab-worker@gke-lab-unit-test.iam.gserviceaccount.com"
    echo_image             = "example.invalid/echo@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    hello_image            = "example.invalid/hello@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    hpa_image              = "example.invalid/hpa@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    recovery_image         = "example.invalid/recovery@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  }

  assert {
    condition     = length(kubernetes_namespace_v1.lab) == 4
    error_message = "Test, staging, production, and isolated recovery namespaces must all exist."
  }

  assert {
    condition     = kubernetes_horizontal_pod_autoscaler_v2.hpa_example.spec[0].max_replicas == 5
    error_message = "The HPA must remain explicitly bounded."
  }

  assert {
    condition     = kubernetes_namespace_v1.lab["test"].metadata[0].labels["pod-security.kubernetes.io/enforce"] == "baseline" && kubernetes_namespace_v1.lab["production"].metadata[0].labels["pod-security.kubernetes.io/enforce"] == "restricted"
    error_message = "Public diagnostics must stay isolated from Restricted application namespaces."
  }
}
